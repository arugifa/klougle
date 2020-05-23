# =========================
# Unversioned Docker Images
# =========================

data "docker_registry_image" "mysql" {
  name = "mysql:5"
}

# TODO: Upgrade all containers to v12 (05/2020)
data "docker_registry_image" "postgresql" {
  name = "postgres:11-alpine"
}

data "docker_registry_image" "postgresql_12" {
  name = "postgres:12-alpine"
}

data "docker_registry_image" "redis" {
  name = "redis:5-alpine"
}

data "docker_registry_image" "traefik" {
  name = "traefik:2.2"
}
