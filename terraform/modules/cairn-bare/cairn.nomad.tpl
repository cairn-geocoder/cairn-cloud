job "${name}" {
  datacenters = ${jsonencode(datacenters)}
  namespace   = "${namespace}"
  type        = "service"

  group "cairn" {
    count = ${count}

    update {
      max_parallel      = 1
      health_check      = "checks"
      min_healthy_time  = "10s"
      healthy_deadline  = "5m"
      auto_revert       = true
      canary            = 1
    }

    network {
      port "http" {
        to = 8080
      }
    }

%{ if register_consul_service }
    service {
      name = "${name}"
      port = "http"
      tags = ["cairn", "geocoder", "v0.0.2-alpha"]

      check {
        name     = "healthz"
        type     = "http"
        path     = "/healthz"
        interval = "10s"
        timeout  = "3s"
      }

      check {
        name     = "readyz"
        type     = "http"
        path     = "/readyz"
        interval = "15s"
        timeout  = "3s"
      }
    }
%{ endif }

    # Init task: fetch + verify the bundle into the alloc shared
    # dir so the main task can mount it read-only.
    task "bundle-fetch" {
      lifecycle {
        hook    = "prestart"
        sidecar = false
      }
      driver = "docker"
      config {
        image   = "alpine/curl:8"
        command = "/bin/sh"
        args    = ["-c", <<-EOT
          set -eu
          cd /alloc/data
          curl -fSL --retry 3 -o bundle.tar.gz "${bundle_url}"
%{ if bundle_sha256 != "" }
          echo "${bundle_sha256}  bundle.tar.gz" | sha256sum -c -
%{ endif }
          mkdir -p bundle
          tar -C bundle --strip-components=1 -xzf bundle.tar.gz
          rm -f bundle.tar.gz
        EOT
        ]
        readonly_rootfs = true
      }
      resources {
        cpu    = 200
        memory = 256
      }
    }

    task "cairn" {
      driver = "docker"
      config {
        image = "${image}"
        ports = ["http"]
        args  = [
          "--bundle", "$${NOMAD_ALLOC_DIR}/data/bundle",
          "--bind",   "0.0.0.0:8080",
        ]
        readonly_rootfs = true
      }
      resources {
        cpu    = ${cpu_mhz}
        memory = ${memory_mb}
      }
    }
  }
}
