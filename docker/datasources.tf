# =========================
# Unversioned Docker Images
# =========================

data "docker_registry_image" "mysql" {
  name = "mysql:5"
}

data "docker_registry_image" "postgresql" {
  name = "postgres:11-alpine"
}

data "docker_registry_image" "redis" {
  name = "redis:5-alpine"
}

data "docker_registry_image" "traefik" {
  name = "traefik:2.2"
}
