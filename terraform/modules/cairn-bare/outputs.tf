output "job_id" {
  description = "Nomad job ID. `nomad job status <id>` to inspect."
  value       = nomad_job.cairn.id
}

output "consul_service_name" {
  description = "Consul service name (only meaningful when register_consul_service = true)."
  value       = var.register_consul_service ? var.name : null
}
