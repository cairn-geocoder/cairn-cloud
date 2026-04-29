# Cairn on Nomad + Consul.
#
# Operators with a Nomad+Consul cluster (HashiCorp's "BYO Kubernetes
# alternative") get the same airgap-friendly story as the Helm chart:
# init task fetches the bundle, main task runs cairn-serve, Consul
# service registration provides DNS + health checks.
#
# This module assumes you already have:
#   - a reachable Nomad cluster (provider configured outside the module)
#   - a reachable Consul cluster wired to Nomad's `consul` integration
#   - a Docker driver enabled on Nomad clients (we use `docker` driver
#     so the cairn image works the same as on Kubernetes)

resource "nomad_job" "cairn" {
  jobspec = templatefile("${path.module}/cairn.nomad.tpl", {
    name                    = var.name
    datacenters             = var.datacenters
    namespace               = var.namespace
    image                   = var.image
    bundle_url              = var.bundle_url
    bundle_sha256           = var.bundle_sha256
    count                   = var.instance_count
    cpu_mhz                 = var.cpu_mhz
    memory_mb               = var.memory_mb
    register_consul_service = var.register_consul_service
  })
}
