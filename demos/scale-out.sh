#!/usr/bin/env bash
# Burns CPU on all asg-web instances for 10 minutes (via SSM) so average CPU goes above 70%.
set -euo pipefail
aws ssm send-command --document-name AWS-RunShellScript \
  --targets "Key=tag:Name,Values=asg-web" \
  --parameters 'commands=["for i in 1 2; do (timeout 600 yes > /dev/null &); done"]' \
  --query 'Command.CommandId' --output text
echo
echo "Now watch (scale-out usually shows up after ~5-10 min):"
echo "  watch -n 20 'aws autoscaling describe-scaling-activities --auto-scaling-group-name web-asg --max-items 5 --query \"Activities[].[StartTime,StatusCode,Description]\" --output table'"
echo "  aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names web-asg --query 'AutoScalingGroups[0].DesiredCapacity'"
