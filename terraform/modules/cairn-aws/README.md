# cairn-aws — Terraform module

Cairn on AWS Fargate behind an ALB. Single-region, single-cluster,
auto-scales on CPU.

## What you get

- ECS Fargate cluster + Service + Task Definition
- Init container fetches the bundle tar.gz and (optionally) verifies
  SHA-256 before `cairn-serve` starts
- ALB with `/healthz` health check, port 80 listener (TLS is your job
  via `aws_lb_listener` + ACM out-of-band)
- App Auto Scaling: CPU target 70%, configurable min/max
- CloudWatch log group with separate streams for fetch + serve
- IAM exec + task roles, security groups locked down (ALB → tasks
  only)

## Usage

```hcl
module "cairn" {
  source = "github.com/cairn-geocoder/cairn-cloud//terraform/modules/cairn-aws?ref=main"

  name                = "cairn-prod"
  vpc_id              = aws_vpc.this.id
  public_subnet_ids   = aws_subnet.public[*].id
  private_subnet_ids  = aws_subnet.private[*].id

  bundle_url    = "https://bundles.example.com/cairn/switzerland-v0.0.2-alpha.tar.gz"
  bundle_sha256 = "<sha256-of-the-tarball>"

  desired_count = 2
  max_capacity  = 8
}

output "cairn_alb" {
  value = module.cairn.alb_dns_name
}
```

Add HTTPS by composing your own `aws_lb_listener` on port 443 against
`module.cairn.alb_dns_name`'s underlying ALB, plus an ACM cert. We
deliberately don't bake TLS into the module so you can pick your cert
issuance flow (ACM with DNS validation, imported, etc.).

## Inputs

See [`variables.tf`](./variables.tf).

## Outputs

See [`outputs.tf`](./outputs.tf).
