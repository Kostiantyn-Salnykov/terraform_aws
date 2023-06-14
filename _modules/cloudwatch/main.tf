# ==Variables==
variable "name_suffix" {
  default = "Project with environment name."
  type    = string
}
# =====


# ==Locals==
locals {
  cluster_name           = "${var.name_suffix}-cluster"
  service_name           = "${var.name_suffix}-service"
  task_definition_family = "${var.name_suffix}-TaskDefinition"
}
# =====


# ==Resources==
resource "aws_cloudwatch_metric_alarm" "example" {
  alarm_name          = "MyECSTaskHealth"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "SampleCount"
  threshold           = 0

  dimensions = {
    ClusterName = local.cluster_name
    ServiceName = local.service_name
    #    TargetDiscoveryName = local.task_definition_family
  }

  alarm_description = "This metric monitors the health status of an ECS Task Definition."

  alarm_actions = [
    data.aws_sns_topic.MySNSChatBotTopic.arn
  ]
  ok_actions = [
    data.aws_sns_topic.MySNSChatBotTopic.arn
  ]
}
# =====


data "aws_sns_topic" "MySNSChatBotTopic" {
  name = "SNSNotificationTopic"
}