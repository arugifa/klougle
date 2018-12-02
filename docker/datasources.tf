# =============
# Docker Images
# =============

data "docker_registry_image" "miniflux" {
  name = "miniflux/miniflux:2.0.13"
}

data "docker_registry_image" "nginx" {
  # No proper version scheme available yet.
  name = "jwilder/nginx-proxy:latest"
}

data "docker_registry_image" "postgresql" {
  name = "postgres:11-alpine"
}
