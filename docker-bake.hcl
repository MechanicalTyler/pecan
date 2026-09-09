// Build-time configuration for the pecan image. Each variable below
// defaults from an identically-named environment variable exported from
// pecan.env (Buildx Bake overrides a variable's default automatically when
// an environment variable of the same name is set) — see pecan.env.example.

variable "PECAN_BASE_IMAGE" {
  default = "node:24-bookworm-slim"
}

variable "PECAN_EXTRA_PACKAGES" {
  default = ""
}

variable "PECAN_USER" {
  default = "pecan"
}

variable "PECAN_HOME" {
  default = "/home/pecan"
}

target "pecan" {
  dockerfile = "Dockerfile"
  tags       = ["pecan:latest"]
  args = {
    BASE_IMAGE     = PECAN_BASE_IMAGE
    EXTRA_PACKAGES = PECAN_EXTRA_PACKAGES
    PECAN_USER     = PECAN_USER
    PECAN_HOME     = PECAN_HOME
  }
}
