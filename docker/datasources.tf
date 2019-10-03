# =========================
# Unversioned Docker Images
# =========================

data "docker_registry_image" "mysql" {
  name = "mysql:5"
}

data "docker_registry_image" "nginx" {
  name = "jwilder/nginx-proxy:latest"
}

data "docker_registry_image" "postgresql" {
  name = "postgres:11-alpine"
}
