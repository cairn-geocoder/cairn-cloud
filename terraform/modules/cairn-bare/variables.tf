variable "name" {
  description = "Nomad job name + Consul service name."
  type        = string
  default     = "cairn"
}

variable "datacenters" {
  description = "Nomad datacenters the job runs in."
  type        = list(string)
  default     = ["dc1"]
}

variable "namespace" {
  description = "Nomad namespace."
  type        = string
  default     = "default"
}

variable "image" {
  description = "Container image for cairn-serve."
  type        = string
  default     = "ghcr.io/cairn-geocoder/cairn:0.0.2-alpha"
}

variable "bundle_url" {
  description = "HTTPS URL of the bundle tar.gz."
  type        = string
}

variable "bundle_sha256" {
  description = "Optional SHA-256. Init step fails closed on mismatch."
  type        = string
  default     = ""
}

variable "instance_count" {
  description = "Number of cairn-serve allocations. (Named `instance_count` because Terraform reserves `count` inside module blocks.)"
  type        = number
  default     = 1
}

variable "cpu_mhz" {
  description = "Nomad CPU resource in MHz. 500 ≈ 0.5 vCPU on a typical 2 GHz host."
  type        = number
  default     = 500
}

variable "memory_mb" {
  description = "Nomad memory resource in MB. Country bundles run hot RSS ~100 MB."
  type        = number
  default     = 512
}

variable "register_consul_service" {
  description = "Register a `<name>` Consul service with /healthz check. Pulls Consul DNS into the picture for service discovery."
  type        = bool
  default     = true
}
