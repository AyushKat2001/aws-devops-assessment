#!/usr/bin/env bash
# Stops nginx on ONE instance -> ALB health check fails -> ASG replaces the instance.
set -euo pipefail
TG_ARN=$(terraform -chdir="$(dirname "$0")/../terraform" output -raw target_group_arn)

VICTIM=$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names web-asg \
  --query 'AutoScalingGroups[0].Instances[?LifecycleState==`InService`]|[0].InstanceId' --output text)
echo "Victim instance: $VICTIM"

aws ssm send-command --document-name AWS-RunShellScript --instance-ids "$VICTIM" \
  --parameters 'commands=["systemctl stop nginx"]' --query 'Command.CommandId' --output text

echo
echo "1) Watch the target go unhealthy (~30-60 s):"
echo "  watch -n 10 'aws elbv2 describe-target-health --target-group-arn $TG_ARN --query \"TargetHealthDescriptions[].[Target.Id,TargetHealth.State]\" --output table'"
echo "2) Watch the ASG replace it (~2-5 min):"
echo "  aws autoscaling describe-scaling-activities --auto-scaling-group-name web-asg --max-items 5 --query 'Activities[].[StartTime,StatusCode,Description]' --output table"
echo
echo "Faster alternative (no SSM): aws autoscaling set-instance-health --instance-id $VICTIM --health-status Unhealthy"
