#!/bin/bash
# refs:
# https://docs.aws.amazon.com/cli/latest/reference/ec2/describe-nat-gateways.html
# https://docs.aws.amazon.com/cli/latest/reference/ec2/delete-nat-gateway.html
# https://docs.aws.amazon.com/cli/latest/reference/ec2/describe-addresses.html
# https://docs.aws.amazon.com/cli/latest/reference/ec2/disassociate-address.html
# https://docs.aws.amazon.com/cli/latest/reference/ec2/release-address.html
# https://docs.aws.amazon.com/cli/latest/reference/ec2/describe-network-interfaces.html
# https://docs.aws.amazon.com/cli/latest/reference/ec2/detach-network-interface.html
# https://docs.aws.amazon.com/cli/latest/reference/ecs/update-service.html
set -e

REGION="${AWS_REGION:-eu-west-1}"
VPC_NAME="ntc-constellation-vpc"

VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=$VPC_NAME" --region "$REGION" --query "Vpcs[0].VpcId" --output text 2>/dev/null || echo "")

if [ -z "$VPC_ID" ] || [ "$VPC_ID" = "None" ]; then
  echo "vpc not found"
  exit 0
fi

echo "found vpc $VPC_ID"

# stop ecs service
CLUSTER="ntc-constellation"
SERVICE="ntc-constellation-service"
STATUS=$(aws ecs describe-services --cluster "$CLUSTER" --services "$SERVICE" --region "$REGION" --query "services[0].status" --output text 2>/dev/null || echo "MISSING")

if [ "$STATUS" = "ACTIVE" ]; then
  aws ecs update-service --cluster "$CLUSTER" --service "$SERVICE" --desired-count 0 --region "$REGION"
  aws ecs wait services-stable --cluster "$CLUSTER" --services "$SERVICE" --region "$REGION"
fi

# delete nat gateways
NAT_IDS=$(aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$VPC_ID" "Name=state,Values=available,pending" --region "$REGION" --query "NatGateways[].NatGatewayId" --output text)

for NAT_ID in $NAT_IDS; do
  echo "deleting nat $NAT_ID"
  aws ec2 delete-nat-gateway --nat-gateway-id "$NAT_ID" --region "$REGION"
done

for NAT_ID in $NAT_IDS; do
  aws ec2 wait nat-gateway-deleted --nat-gateway-ids "$NAT_ID" --region "$REGION"
done

# give aws a moment to fully release the eips after nat deletion
sleep 10

# disassociate eips not linked to nat gateways
ASSOC_IDS=$(aws ec2 describe-addresses --filters "Name=domain,Values=vpc" --region "$REGION" --query "Addresses[?AssociationId!=null && !contains(AssociationId, 'eipassoc')].AssociationId" --output text 2>/dev/null || echo "")

for ASSOC_ID in $ASSOC_IDS; do
  aws ec2 disassociate-address --association-id "$ASSOC_ID" --region "$REGION" || true
done

# release eips - retry a few times since nat gateway release can lag
for i in 1 2 3; do
  ALLOC_IDS=$(aws ec2 describe-addresses --filters "Name=domain,Values=vpc" --region "$REGION" --query "Addresses[?AssociationId==null].AllocationId" --output text)
  for ALLOC_ID in $ALLOC_IDS; do
    aws ec2 release-address --allocation-id "$ALLOC_ID" --region "$REGION" || true
  done
  REMAINING=$(aws ec2 describe-addresses --filters "Name=domain,Values=vpc" --region "$REGION" --query "length(Addresses)" --output text)
  [ "$REMAINING" = "0" ] && break
  echo "eips still present, waiting 15s..."
  sleep 15
done

# cleanup enis
ENI_IDS=$(aws ec2 describe-network-interfaces --filters "Name=vpc-id,Values=$VPC_ID" --region "$REGION" --query "NetworkInterfaces[?Status!='available'].NetworkInterfaceId" --output text)

for ENI_ID in $ENI_IDS; do
  ATTACHMENT_ID=$(aws ec2 describe-network-interfaces --network-interface-ids "$ENI_ID" --region "$REGION" --query "NetworkInterfaces[0].Attachment.AttachmentId" --output text 2>/dev/null || echo "")
  
  if [ -n "$ATTACHMENT_ID" ] && [ "$ATTACHMENT_ID" != "None" ]; then
    aws ec2 detach-network-interface --attachment-id "$ATTACHMENT_ID" --force --region "$REGION" || true
    sleep 3
  fi
  
  aws ec2 delete-network-interface --network-interface-id "$ENI_ID" --region "$REGION" || true
done

echo "cleanup done"
