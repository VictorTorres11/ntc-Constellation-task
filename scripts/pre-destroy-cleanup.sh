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
# https://docs.aws.amazon.com/cli/latest/reference/elbv2/delete-load-balancer.html
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

# delete alb first
ALB_ARNS=$(aws elbv2 describe-load-balancers --region "$REGION" --query "LoadBalancers[?contains(LoadBalancerName, 'ntc-constellation')].LoadBalancerArn" --output text)

for ALB_ARN in $ALB_ARNS; do
  echo "deleting alb $ALB_ARN"
  aws elbv2 delete-load-balancer --load-balancer-arn "$ALB_ARN" --region "$REGION"
done

if [ -n "$ALB_ARNS" ]; then
  echo "waiting for alb to delete..."
  aws elbv2 wait load-balancers-deleted --load-balancer-arns $ALB_ARNS --region "$REGION"
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

sleep 10

# release eips - retry since alb or nat release
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

# cleanup loose enis
ENI_IDS=$(aws ec2 describe-network-interfaces \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=status,Values=available" \
  --region "$REGION" \
  --query "NetworkInterfaces[?RequesterManaged==\`false\`].NetworkInterfaceId" --output text)

for ENI_ID in $ENI_IDS; do
  echo "deleting eni $ENI_ID"
  aws ec2 delete-network-interface --network-interface-id "$ENI_ID" --region "$REGION" || true
done

# delete non-main route tables
RT_IDS=$(aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --region "$REGION" \
  --query "RouteTables[?Associations[?Main==\`false\`] || length(Associations)==\`0\`].RouteTableId" --output text)

for RT_ID in $RT_IDS; do
  echo "deleting route table $RT_ID"
  aws ec2 delete-route-table --route-table-id "$RT_ID" --region "$REGION" || true
done

echo "cleanup done"
