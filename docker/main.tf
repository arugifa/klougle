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
  name          = "miniflux/miniflux:${local.version_miniflux}"
}

resource "docker_container" "miniflux" {
  image   = "${docker_image.miniflux.latest}"
  name    = "miniflux"
  start   = true

  # Wait for database's container to start (dumb implementation™).
  restart = "on-failure"

  env = [
    # Reverse Proxy
    "VIRTUAL_HOST=${local.domain_news}",

    # Miniflux Database
    "DATABASE_URL=${local.db_url_miniflux}",
    "RUN_MIGRATIONS=1",

    # Miniflux Setup
    # Create admin user if it doesn't already exist.
    "CREATE_ADMIN=1",
    "ADMIN_USERNAME=${local.default_user_miniflux}",
    "ADMIN_PASSWORD=${local.default_password_miniflux}",
  ]

  networks_advanced {
    name = "${docker_network.internal_network.name}"
  }
}

resource "docker_volume" "miniflux_data" {
  name = "miniflux_data"
}

# Notes Application (Standard Notes)
# ==================================

resource "docker_image" "standardnotes_web" {
  name          = "arugifa/standardnotes-web:${local.version_standardnotes_web}"
}

resource "docker_container" "standardnotes_web" {
  image   = "${docker_image.standardnotes_web.latest}"
  name    = "standardnotes_web"
  start   = true

  env = [
    # Reverse Proxy
    "VIRTUAL_HOST=${local.domain_notes_webui}",

    # Standard Notes Server
    "SF_DEFAULT_SERVER=http://rtfm.${local.domain_notes_webui}",
  ]

  networks_advanced {
    name = "${docker_network.internal_network.name}"
  }
}

resource "docker_image" "standardnotes_server" {
  name          = "arugifa/standardnotes-server:${local.version_standardnotes_server}"
}

resource "docker_container" "standardnotes_server" {
  image   = "${docker_image.standardnotes_server.latest}"
  name  = "standardnotes_server"
  start   = true

  # Wait for database's container to start (dumb implementation™).
  restart = "on-failure"

  command = [
    "/bin/sh", "-c",
    # Create the database if not already exists.
    # Then, migrate the database and start the server.
    "bundle exec rails db:create; bundle exec rails db:migrate && bundle exec rails s -b 0.0.0.0",
  ]

  env = [
    # Reverse Proxy
    "VIRTUAL_HOST=${local.domain_notes_server}",
    "VIRTUAL_PORT=3000",

    # Standard Notes Server Setup
    "RAILS_ENV=production",
    "RAILS_SERVE_STATIC_FILES=true",
    "SECRET_KEY_BASE=${random_string.standardnotes_secret_key.result}",

    # Standard Notes Database
    "DB_HOST=${local.db_host_standardnotes}",
    "DB_DATABASE=${local.db_name_standardnotes}",
    "DB_USERNAME=${local.db_user_standardnotes}",
    "DB_PASSWORD=${local.db_password_standardnotes}",
  ]

  networks_advanced {
    name = "${docker_network.internal_network.name}"
  }
}

resource "docker_volume" "standardnotes_data" {
  name = "standardnotes_data"
}

resource "random_string" "standardnotes_secret_key" {
  length  = 16

  # Special characters make Rails to break down.
  special = false
}

# Task Management (Kanboard)
# ==========================

resource "docker_image" "kanboard" {
  name          = "kanboard/kanboard:${local.version_kanboard}"
}

resource "docker_container" "kanboard" {
  image   = "${docker_image.kanboard.latest}"
  name    = "kanboard"
  start   = true

  env = [
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

resource "docker_image" "mysql" {
  name          = "${data.docker_registry_image.mysql.name}"
  pull_triggers = ["${data.docker_registry_image.mysql.sha256_digest}"]
}

resource "docker_image" "postgresql" {
  name          = "${data.docker_registry_image.postgresql.name}"
  pull_triggers = ["${data.docker_registry_image.postgresql.sha256_digest}"]
}

# Miniflux
# ========

resource "docker_container" "miniflux_db" {
  image = "${docker_image.postgresql.latest}"
  name  = "${local.db_host_miniflux}"
  start = true

  env = [
    "POSTGRES_DB=${local.db_name_miniflux}",
    "POSTGRES_USER=${local.db_user_miniflux}",
    "POSTGRES_PASSWORD=${local.db_password_miniflux}",
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

# Standard Notes
# ==============

resource "docker_container" "standardnotes_db" {
  image = "${docker_image.mysql.latest}"
  name  = "${local.db_host_standardnotes}"
  start = true

  env = [
    "MYSQL_DATABASE=${local.db_name_standardnotes}",
    "MYSQL_USER=${local.db_user_standardnotes}",
    "MYSQL_PASSWORD=${local.db_password_standardnotes}",

    # The MySQL image requires the root's password to be set manually.
    # We use the same password than the default user, because there is
    # no reason to use a different one...
    "MYSQL_ROOT_PASSWORD=${local.db_password_standardnotes}",
  ]

  networks_advanced {
    name = "${docker_network.internal_network.name}"
  }

  volumes {
    volume_name    = "${docker_volume.standardnotes_data.name}"
    container_path = "/var/lib/mysql"
  }
}

resource "random_string" "standardnotes_db_password" {
  length = 8
  special = false
}
