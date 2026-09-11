#!/usr/bin/env bash
#
# CloudWatch alarms for dental-os-service.
#
# WHY THIS IS A SCRIPT AND NOT A TEMPLATE
# dental-os-service, its task definition and dental-os-tg are in no
# CloudFormation stack (CONTEXT.md, "Infrastructure Ownership"). The ALB
# itself belongs to the dental-api stack, but this target group does not,
# so there is nothing to add an AWS::CloudWatch::Alarm to without first
# adopting the resources. Until that happens this file IS the record of
# what was created - run it, and check it in.
#
# WHAT IT WATCHES
# On 2026-09-02 the RDS instance became unreachable, the task crash-looped
# every ~13 minutes, dental-os-tg had no healthy target, and the ALB
# answered every /api/* path with a 503. Nobody noticed for nine days.
# See "Runbook - RDS unreachable" in CONTEXT.md.
#
#   dental-os-no-healthy-host   HealthyHostCount < 1
#       The one that matters. Fires whether targets are unhealthy OR
#       absent entirely - during the incident both happened, alternating.
#       treat-missing-data=breaching is deliberate: when ECS deregisters
#       the last target the metric stops reporting rather than going to
#       zero, and "missing" is exactly the state worth paging on.
#
#   dental-os-5xx               HTTPCode_ELB_5XX_Count >= 5 in 5 min
#       Catches the visitor-facing symptom directly, including failures
#       that never show up as an unhealthy host.
#
# NOTIFICATIONS
# Without an SNS topic these alarms change state in the console and tell
# nobody. Pass SNS_TOPIC_ARN to wire them up. To create one:
#
#   aws sns create-topic --name dental-os-alerts --profile dental --region us-east-1
#   aws sns subscribe --topic-arn TOPIC_ARN --protocol email \
#     --notification-endpoint you@example.com --profile dental --region us-east-1
#   # then confirm the email before the subscription is live
#
# USAGE
#   ./scripts/create_alarms.sh
#   SNS_TOPIC_ARN=arn:aws:sns:us-east-1:740104998309:dental-os-alerts \
#     ./scripts/create_alarms.sh
#
set -euo pipefail

PROFILE="${AWS_PROFILE_NAME:-dental}"
REGION="${AWS_REGION:-us-east-1}"
TG_ARN="${TG_ARN:-arn:aws:elasticloadbalancing:us-east-1:740104998309:targetgroup/dental-os-tg/9bc6ee921ccd4c9b}"

aws() { command aws "$@" --profile "$PROFILE" --region "$REGION"; }

# CloudWatch identifies a target group by the tail of its ARN, not the ARN
# itself, and a Healthy/UnHealthyHostCount metric is only unique when the
# LoadBalancer dimension is given too. Both are derived rather than pasted
# so this keeps working if the target group is ever rebuilt.
TG_DIM="${TG_ARN#*:targetgroup/}"
TG_DIM="targetgroup/${TG_DIM}"

LB_ARN="$(aws elbv2 describe-target-groups \
  --target-group-arns "$TG_ARN" \
  --query 'TargetGroups[0].LoadBalancerArns[0]' --output text)"

if [ -z "$LB_ARN" ] || [ "$LB_ARN" = "None" ]; then
  echo "error: target group $TG_DIM is not attached to a load balancer" >&2
  exit 1
fi
LB_DIM="${LB_ARN#*:loadbalancer/}"

echo "target group : $TG_DIM"
echo "load balancer: $LB_DIM"

ACTIONS=()
if [ -n "${SNS_TOPIC_ARN:-}" ]; then
  ACTIONS=(--alarm-actions "$SNS_TOPIC_ARN" --ok-actions "$SNS_TOPIC_ARN")
  echo "notify       : $SNS_TOPIC_ARN"
else
  echo "notify       : NONE - alarms will be silent. Set SNS_TOPIC_ARN." >&2
fi

# -- no healthy target ------------------------------------------------
# 2 periods of 60s before firing: a rolling deploy drains the old task
# before the new one passes its health check, so a single minute at zero
# is normal. Two consecutive is not.
aws cloudwatch put-metric-alarm \
  --alarm-name dental-os-no-healthy-host \
  --alarm-description "dental-os has no healthy target behind the ALB. Every /api/* path is answering 503. See Runbook in CONTEXT.md." \
  --namespace AWS/ApplicationELB \
  --metric-name HealthyHostCount \
  --dimensions "Name=TargetGroup,Value=$TG_DIM" "Name=LoadBalancer,Value=$LB_DIM" \
  --statistic Minimum \
  --period 60 \
  --evaluation-periods 2 \
  --datapoints-to-alarm 2 \
  --threshold 1 \
  --comparison-operator LessThanThreshold \
  --treat-missing-data breaching \
  "${ACTIONS[@]}"

# -- visitor-facing 5xx -----------------------------------------------
aws cloudwatch put-metric-alarm \
  --alarm-name dental-os-5xx \
  --alarm-description "The ALB is returning 5xx for dental-os. May be the API erroring rather than absent." \
  --namespace AWS/ApplicationELB \
  --metric-name HTTPCode_ELB_5XX_Count \
  --dimensions "Name=LoadBalancer,Value=$LB_DIM" \
  --statistic Sum \
  --period 300 \
  --evaluation-periods 1 \
  --threshold 5 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --treat-missing-data notBreaching \
  "${ACTIONS[@]}"

echo
aws cloudwatch describe-alarms \
  --alarm-names dental-os-no-healthy-host dental-os-5xx \
  --query 'MetricAlarms[].{name:AlarmName,state:StateValue,actions:AlarmActions}' \
  --output table
