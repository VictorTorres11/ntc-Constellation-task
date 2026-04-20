#!/usr/bin/env bash
# Verifies that the ALB listener routes 100% of traffic to the blue target group after terraform apply.
# This check runs as part of the CI/CD pipeline after Stage 3 infrastructure is provisioned.
#
# Usage:
#   ./scripts/verify-alb-traffic-distribution.sh
#
# Environment variables:
#   AWS_REGION        — AWS region (default: eu-west-1)
#   TF_WORKING_DIR    — ECS module directory (default: infra/ecs)
#
# References:
#   AWS CLI - elbv2 describe-listeners
#     https://docs.aws.amazon.com/cli/latest/reference/elbv2/describe-listeners.html
#   AWS CLI - elbv2 describe-rules
#     https://docs.aws.amazon.com/cli/latest/reference/elbv2/describe-rules.html
#   ALB listener default actions and forward actions
#     https://docs.aws.amazon.com/elasticloadbalancing/latest/application/listener-update-rules.html
#   ALB weighted target groups (blue/green traffic splitting)
#     https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-target-groups.html

set -euo pipefail

AWS_REGION="${AWS_REGION:-eu-west-1}"
TF_WORKING_DIR="${TF_WORKING_DIR:-infra/ecs}"

LISTENER_ARN=$(terraform -chdir="${TF_WORKING_DIR}" output -raw alb_listener_arn 2>/dev/null)
TG_BLUE_ARN=$(terraform -chdir="${TF_WORKING_DIR}" output -raw target_group_blue_arn 2>/dev/null)

if [[ -z "${LISTENER_ARN}" || -z "${TG_BLUE_ARN}" ]]; then
  echo "could not read terraform outputs from '${TF_WORKING_DIR}'"
  exit 1
fi

LISTENER_JSON=$(aws elbv2 describe-listeners \
  --listener-arns "${LISTENER_ARN}" \
  --region "${AWS_REGION}" \
  --output json)

BLUE_WEIGHT=$(echo "${LISTENER_JSON}" | \
  python3 -c "
import json, sys
tgs = json.load(sys.stdin)['Listeners'][0]['DefaultActions'][0]['ForwardConfig']['TargetGroups']
for tg in tgs:
    if tg['TargetGroupArn'] == '${TG_BLUE_ARN}':
        print(tg['Weight'])
        sys.exit(0)
print(0)
")

GREEN_WEIGHT=$(echo "${LISTENER_JSON}" | \
  python3 -c "
import json, sys
tgs = json.load(sys.stdin)['Listeners'][0]['DefaultActions'][0]['ForwardConfig']['TargetGroups']
green_weight = sum(tg['Weight'] for tg in tgs if tg['TargetGroupArn'] != '${TG_BLUE_ARN}')
print(green_weight)
")

TOTAL_WEIGHT=$(( BLUE_WEIGHT + GREEN_WEIGHT ))

if [[ "${TOTAL_WEIGHT}" -ne 100 || "${BLUE_WEIGHT}" -ne 100 || "${GREEN_WEIGHT}" -ne 0 ]]; then
  echo "FAILED: unexpected traffic distribution (blue=${BLUE_WEIGHT}, green=${GREEN_WEIGHT}, total=${TOTAL_WEIGHT})"
  exit 1
fi

echo "blue=${BLUE_WEIGHT}% green=${GREEN_WEIGHT}% total=${TOTAL_WEIGHT}%"
