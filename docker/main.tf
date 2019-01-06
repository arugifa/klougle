# ====================
# Docker Configuration
# ====================

provider "docker" {
  host      = "${var.host == "localhost" ? "${local.docker_unix_socket}" : "${local.docker_tcp_socket}"}"
  cert_path = "${var.host == "localhost" ? "" : pathexpand("${local.docker_certs}")}"
}


# ==========
# Networking
# ==========

resource "docker_network" "internal_network" {
  name     = "internal_network"
}


# Reverse Proxy
# =============

resource "docker_image" "nginx" {
  name          = "${data.docker_registry_image.nginx.name}"
  pull_triggers = ["${data.docker_registry_image.nginx.sha256_digest}"]
}

resource "docker_container" "nginx" {
  image    = "${docker_image.nginx.latest}"
  name     = "nginx"
  start    = true

  ports {
    internal = 80
    external = 80
  }

  networks_advanced {
    # To be reachable from Internet, using the default Docker network.
    name = "bridge"
  }

  networks_advanced {
    # To connect with other containers.
    name = "${docker_network.internal_network.name}"
  }

  volumes {
    # Give access to Docker's socket, to discover other containers.
    host_path      = "/var/run/docker.sock"
    container_path = "/tmp/docker.sock"
    read_only      = true
  }
}


# ========
# Services
# ========

# News Reader (Miniflux)
# ======================

resource "docker_image" "miniflux" {
  name          = "${data.docker_registry_image.miniflux.name}"
  pull_triggers = ["${data.docker_registry_image.miniflux.sha256_digest}"]
}

resource "docker_container" "miniflux" {
  image   = "${docker_image.miniflux.latest}"
  name    = "miniflux"
  start   = true

  # Wait for database's container to start (dumb implementation™).
  restart = "on-failure"

  env     = [
    # Reverse Proxy
    "VIRTUAL_HOST=${local.domain_news}",

    # Miniflux Database
    "DATABASE_URL=${local.miniflux_db_url}",
    "RUN_MIGRATIONS=1",

    # Miniflux Setup
    # Create admin user if it doesn't already exist.
    "CREATE_ADMIN=1",
    "ADMIN_USERNAME=${local.user_news}",
    "ADMIN_PASSWORD=${local.default_password_news}",
  ]

  networks_advanced {
    name = "${docker_network.internal_network.name}"
  }
}

resource "docker_volume" "miniflux_data" {
  name = "miniflux_data"
}


# Task Management (Kanboard)
# ==========================

resource "docker_image" "kanboard" {
  name          = "${data.docker_registry_image.kanboard.name}"
  pull_triggers = ["${data.docker_registry_image.kanboard.sha256_digest}"]
}

resource "docker_container" "kanboard" {
  image   = "${docker_image.kanboard.latest}"
  name    = "kanboard"
  start   = true

  env     = [
    # Reverse Proxy
    "VIRTUAL_HOST=${local.domain_tasks}",
  ]

  networks_advanced {
    name = "${docker_network.internal_network.name}"
  }

  volumes {
    volume_name    = "${docker_volume.kanboard_data.name}"
    container_path = "/var/www/app/data"
  }
}

resource "docker_volume" "kanboard_data" {
  name = "kanboard_data"
}


# =========
# Databases
# =========

resource "docker_image" "postgresql" {
  name          = "${data.docker_registry_image.postgresql.name}"
  pull_triggers = ["${data.docker_registry_image.postgresql.sha256_digest}"]
}


# Miniflux
# ========

resource "docker_container" "miniflux_db" {
  image = "${docker_image.postgresql.latest}"
  name  = "${local.miniflux_db_host}"
  start = true

  env   = [
    "POSTGRES_DB=${local.miniflux_db_name}",
    "POSTGRES_USER=${local.miniflux_db_user}",
    "POSTGRES_PASSWORD=${local.miniflux_db_password}",
  ]

  networks_advanced {
    name = "${docker_network.internal_network.name}"
  }

  volumes {
    volume_name    = "${docker_volume.miniflux_data.name}"
    container_path = "/var/lib/postgresql/data"
  }
}

resource "random_string" "miniflux_db_password" {
  length = 8
  special = false
}
