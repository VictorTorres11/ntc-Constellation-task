#!/usr/bin/env bash
set -euo pipefail

AWS_REGION="${AWS_REGION:-eu-west-1}"
PROJECT="${PROJECT_NAME:-ntc-constellation}"
CLUSTER="${ECS_CLUSTER:-${PROJECT}-cluster}"
IMAGE_TAG="${IMAGE_TAG:-}"

[[ -z "$IMAGE_TAG" ]] && { echo "IMAGE_TAG is required"; exit 1; }

SVC_BLUE="${PROJECT}-service-blue"
SVC_GREEN="${PROJECT}-service-green"
TASK_FAMILY="${PROJECT}-task"

# resolve ARNs
_tg_arn() {
  aws elbv2 describe-target-groups --names "$1" --region "$AWS_REGION" \
    --query "TargetGroups[0].TargetGroupArn" --output text
}

_listener_arn() {
local alb
alb=$(aws elbv2 describe-load-balancers --names "${PROJECT}-alb" --region "$AWS_REGION" \
  --query "LoadBalancers[0].LoadBalancerArn" --output text)
aws elbv2 describe-listeners --load-balancer-arn "$alb" --region "$AWS_REGION" \
  --query "Listeners[?Port==\`80\`].ListenerArn | [0]" --output text
}

TG_BLUE="${TG_BLUE_ARN:-$(_tg_arn "${PROJECT}-tg-blue")}"
TG_GREEN="${TG_GREEN_ARN:-$(_tg_arn "${PROJECT}-tg-green")}"
LISTENER="${ALB_LISTENER_ARN:-$(_listener_arn)}"

echo "listener: $LISTENER"
echo "tg-blue:  $TG_BLUE"
echo "tg-green: $TG_GREEN"

BLUE_WEIGHT=$(aws elbv2 describe-listeners --listener-arns "$LISTENER" --region "$AWS_REGION" \
  --query "Listeners[0].DefaultActions[0].ForwardConfig.TargetGroups[?TargetGroupArn==\`${TG_BLUE}\`].Weight | [0]" \
  --output text)
BLUE_WEIGHT="${BLUE_WEIGHT:-0}"
[[ "$BLUE_WEIGHT" == "None" ]] && BLUE_WEIGHT=0

if [[ "$BLUE_WEIGHT" -gt 0 ]]; then
ACTIVE_SVC="$SVC_BLUE"; INACTIVE_SVC="$SVC_GREEN"
ACTIVE_TG="$TG_BLUE";   INACTIVE_TG="$TG_GREEN"
ACTIVE="blue";           INACTIVE="green"
else
  ACTIVE_SVC="$SVC_GREEN"; INACTIVE_SVC="$SVC_BLUE"
  ACTIVE_TG="$TG_GREEN";   INACTIVE_TG="$TG_BLUE"
  ACTIVE="green";           INACTIVE="blue"
fi

echo "active=$ACTIVE  deploying to=$INACTIVE"

TASK_DEF=$(aws ecs describe-task-definition --task-definition "$TASK_FAMILY" \
  --region "$AWS_REGION" --query "taskDefinition" --output json)

CURRENT_IMAGE=$(echo "$TASK_DEF" | \
  python3 -c "import sys,json; print(json.load(sys.stdin)['containerDefinitions'][0]['image'].rsplit(':',1)[0])")

NEW_TASK_DEF=$(echo "$TASK_DEF" | python3 -c "
import sys, json
td = json.load(sys.stdin)
td['containerDefinitions'][0]['image'] = '${CURRENT_IMAGE}:${IMAGE_TAG}'
for k in ('taskDefinitionArn','revision','status','requiresAttributes',
          'compatibilities','registeredAt','registeredBy','deregisteredAt'):
    td.pop(k, None)
print(json.dumps(td))
")

NEW_ARN=$(aws ecs register-task-definition --region "$AWS_REGION" \
  --cli-input-json "$NEW_TASK_DEF" \
  --query "taskDefinition.taskDefinitionArn" --output text)

echo "new task def: $NEW_ARN"

aws ecs update-service --cluster "$CLUSTER" --service "$INACTIVE_SVC" \
--task-definition "$NEW_ARN" --region "$AWS_REGION" --output json > /dev/null

echo "waiting for $INACTIVE_SVC..."
aws ecs wait services-stable --cluster "$CLUSTER" --services "$INACTIVE_SVC" --region "$AWS_REGION"

# wait healthy targets
ELAPSED=0
while [[ $ELAPSED -lt 300 ]]; do
  COUNT=$(aws elbv2 describe-target-health --target-group-arn "$INACTIVE_TG" \
    --region "$AWS_REGION" \
    --query "TargetHealthDescriptions[?TargetHealth.State=='healthy'] | length(@)" \
    --output text)
  [[ "$COUNT" -gt 0 ]] && { echo "$COUNT healthy"; break; }
  echo "no healthy targets yet (${ELAPSED}s)..."
  sleep 10; ELAPSED=$((ELAPSED + 10))
done
[[ $ELAPSED -ge 300 ]] && { echo "timed out waiting for healthy targets"; exit 1; }

_check_weights() {
aws elbv2 describe-listeners --listener-arns "$LISTENER" --region "$AWS_REGION" \
  --query "Listeners[0].DefaultActions[0].ForwardConfig.TargetGroups" \
  --output json | python3 -c "
import sys, json
tgs = json.load(sys.stdin)
total = sum(int(t.get('Weight',0)) for t in tgs)
print('weight total:', total)
assert total == 100, f'weights dont sum to 100: {total}'
"
}

_check_weights

rollback() {
local start; start=$(date +%s)
echo "ROLLBACK: reverting to $ACTIVE"
aws elbv2 modify-listener --listener-arn "$LISTENER" --region "$AWS_REGION" \
  --default-actions "[{\"Type\":\"forward\",\"ForwardConfig\":{\"TargetGroups\":[{\"TargetGroupArn\":\"${ACTIVE_TG}\",\"Weight\":100},{\"TargetGroupArn\":\"${INACTIVE_TG}\",\"Weight\":0}]}}]" \
  --output json > /dev/null
echo "rollback done in $(( $(date +%s) - start ))s"
}

echo "switching traffic to $INACTIVE"
aws elbv2 modify-listener --listener-arn "$LISTENER" --region "$AWS_REGION" \
  --default-actions "[{\"Type\":\"forward\",\"ForwardConfig\":{\"TargetGroups\":[{\"TargetGroupArn\":\"${INACTIVE_TG}\",\"Weight\":100},{\"TargetGroupArn\":\"${ACTIVE_TG}\",\"Weight\":0}]}}]" \
  --output json > /dev/null

_check_weights

trap 'rollback' ERR

# monitor 5 min — bail out if healthy targets drop to zero
ELAPSED=0
while [[ $ELAPSED -lt 300 ]]; do
COUNT=$(aws elbv2 describe-target-health --target-group-arn "$INACTIVE_TG" \
  --region "$AWS_REGION" \
  --query "TargetHealthDescriptions[?TargetHealth.State=='healthy'] | length(@)" \
  --output text)
[[ "$COUNT" -eq 0 ]] && { echo "no healthy targets — triggering rollback"; rollback; exit 1; }
echo "[${ELAPSED}s] $COUNT healthy"
sleep 15; ELAPSED=$((ELAPSED + 15))
done

# watch the 5xx alarm for 2 minutes — rollback if it fires
ALARM_NAME="${PROJECT}-alb-5xx-rate"
ELAPSED=0
while [[ $ELAPSED -lt 120 ]]; do
  ALARM_STATE=$(aws cloudwatch describe-alarms \
    --alarm-names "$ALARM_NAME" \
    --region "$AWS_REGION" \
    --query "MetricAlarms[0].StateValue" \
    --output text 2>/dev/null || echo "INSUFFICIENT_DATA")
  echo "[${ELAPSED}s] alarm=$ALARM_STATE"
  [[ "$ALARM_STATE" == "ALARM" ]] && { rollback; exit 1; }
  sleep 15; ELAPSED=$((ELAPSED + 15))
done

trap - ERR
echo "done — active=$INACTIVE standby=$ACTIVE"
