variable "name" {
  description = "Resource name prefix. Applied to every resource so multi-env stacks (dev/staging/prod) can co-exist in one account."
  type        = string
  default     = "cairn"
}

variable "vpc_id" {
  description = "Existing VPC the ALB + ECS tasks live in. Cairn doesn't need outbound internet at runtime; the bundle is fetched once at task start."
  type        = string
}

variable "public_subnet_ids" {
  description = "Subnets for the ALB. Must be public if `internal_alb = false`."
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "Subnets for the ECS tasks. Private subnets recommended; tasks need outbound only for the bundle download."
  type        = list(string)
}

variable "internal_alb" {
  description = "Make the ALB internal (no public IP). Useful for VPC-only consumers."
  type        = bool
  default     = false
}

variable "image" {
  description = "Container image for cairn-serve. Pin a digest in production."
  type        = string
  default     = "ghcr.io/cairn-geocoder/cairn:0.0.2-alpha"
}

variable "bundle_url" {
  description = "HTTPS URL of the bundle tar.gz. Pulled by an init step on every task start."
  type        = string
}

variable "bundle_sha256" {
  description = "Optional SHA-256 of the bundle. Init step fails closed on mismatch."
  type        = string
  default     = ""
}

variable "desired_count" {
  description = "Initial replica count. Autoscaling overrides this once it kicks in."
  type        = number
  default     = 1
}

variable "min_capacity" {
  description = "Lower bound for App Auto Scaling."
  type        = number
  default     = 1
}

variable "max_capacity" {
  description = "Upper bound for App Auto Scaling."
  type        = number
  default     = 6
}

variable "cpu" {
  description = "Fargate task CPU (1024 = 1 vCPU). Cairn-serve idles around 100m so 256 is plenty for most country bundles."
  type        = number
  default     = 512
}

variable "memory" {
  description = "Fargate task memory in MB. Country bundles run hot RSS ~100 MB; 1024 is generous."
  type        = number
  default     = 1024
}

variable "log_retention_days" {
  description = "CloudWatch log retention for the cairn-serve task."
  type        = number
  default     = 14
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default = {
    "app"        = "cairn"
    "managed-by" = "terraform"
  }
}
