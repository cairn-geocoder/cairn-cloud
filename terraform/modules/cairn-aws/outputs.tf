output "alb_dns_name" {
  description = "Hostname of the ALB. Point your CNAME at this."
  value       = aws_lb.this.dns_name
}

output "alb_zone_id" {
  description = "Route53 zone id of the ALB. Use with `aws_route53_record` aliases."
  value       = aws_lb.this.zone_id
}

output "service_name" {
  description = "ECS service name. Useful for CLI ops + custom scaling alarms."
  value       = aws_ecs_service.this.name
}

output "cluster_name" {
  description = "ECS cluster name."
  value       = aws_ecs_cluster.this.name
}

output "log_group_name" {
  description = "CloudWatch log group for both bundle-fetch + cairn-serve streams."
  value       = aws_cloudwatch_log_group.this.name
}

output "task_security_group_id" {
  description = "Tasks SG. Add ingress rules here if a peer service needs to reach Cairn directly."
  value       = aws_security_group.tasks.id
}
