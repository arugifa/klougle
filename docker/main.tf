# =================
# Terraform Backend
# =================

# terraform {
#   backend "swift" {
#     container         = "klougle-terraform"
#     archive_container = "klougle-terraform-backup"
#     state_name        = "docker.tfstate.tf"
#   }
# }

# ====================
# Docker Configuration
# ====================

provider "docker" {
  host      = var.host == "localhost" ? local.docker_unix_socket : local.docker_tcp_socket
  cert_path = var.host == "localhost" ? "" : pathexpand(local.docker_certs)
}

# ==========
# Networking
# ==========

resource "docker_network" "internal_network" {
  name = "internal_network"
}

# Reverse Proxy
# =============

resource "docker_image" "traefik" {
  name          = data.docker_registry_image.traefik.name
  pull_triggers = [data.docker_registry_image.traefik.sha256_digest]
}

resource "docker_container" "traefik_http" {
  count = var.host == "localhost" ? 1 : 0

  image = docker_image.traefik.latest
  name  = "traefik"
  start = true

  # Configuration

  command = [
    # Use Docker.
    "--providers.docker=true",

    # Disable dashboard.
    #
    # TODO: Enable dashboard, once MFA is set up with Authelia (05/2020)
    #
    # Otherwise, the only way to secure dashboard access is with Basic Auth,
    # and a password encrypted with Bcrypt. However, doing so would make Terraform
    # detecting new changes everytime running `terraform apply`.
    # For more info: https://www.terraform.io/docs/configuration/functions/bcrypt.html
    "--api.dashboard=false",

    # Configure HTTP.
    #
    # TODO: Enable HTTPs also in CI pipeline, with Let's Encrypt staging endpoint? (05/2020)
    "--entrypoints.http=true",
    "--entrypoints.http.address=:80",

    # Enable logging.
    "--log=true",
    "--log.level=INFO",
  ]

  volumes {
    # Give access to Docker's socket, to discover service containers.
    host_path      = "/var/run/docker.sock"
    container_path = "/var/run/docker.sock"
    read_only      = true
  }

  # Networking

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
    name = docker_network.internal_network.name
  }
}

resource "docker_container" "traefik_https" {
  count = var.host == "localhost" ? 0 : 1

  image = docker_image.traefik.latest
  name  = "traefik"
  start = true

  # Configuration

  command = [
    # Use Docker.
    "--providers.docker=true",

    # Disable dashboard.
    "--api.dashboard=false",

    # Configure HTTP.
    "--entrypoints.http=true",
    "--entrypoints.http.address=:80",
    "--entrypoints.http.http.redirections.entrypoint.to=https",

    # Configure HTTPs.
    "--entrypoints.https=true",
    "--entrypoints.https.address=:443",

    # Configure Let's Encrypt.
    "--certificatesResolvers.letsencrypt.acme.email=${var.letsencrypt_email}",
    "--certificatesResolvers.letsencrypt.acme.httpChallenge.entryPoint=http",

    # Enable logging.
    "--log=true",
    "--log.level=INFO",
  ]

  volumes {
    # Give access to Docker's socket, to discover service containers.
    host_path      = "/var/run/docker.sock"
    container_path = "/var/run/docker.sock"
    read_only      = true
  }

  volumes {
    volume_name    = docker_volume.traefik_certificates.name
    container_path = "/etc/traefik/acme"
  }

  # Networking

  ports {
    internal = 80
    external = 80
  }

  ports {
    internal = 443
    external = 443
  }

  networks_advanced {
    # To be reachable from Internet, using the default Docker network.
    name = "bridge"
  }

  networks_advanced {
    # To connect with other containers.
    name = docker_network.internal_network.name
  }
}

resource "docker_volume" "traefik_certificates" {
  name = "traefik_certificates"
}

# ========
# Services
# ========

# Kanboard
# ========

resource "docker_image" "kanboard" {
  name = "kanboard/kanboard:${local.version_kanboard}"
}

resource "docker_container" "kanboard" {
  image = docker_image.kanboard.latest
  name  = "kanboard"
  start = true

  # Configuration

  env = [
    "DATABASE_URL=${local.db_kanboard_url}",
  ]

  volumes {
    volume_name    = docker_volume.kanboard_data.name
    container_path = "/var/www/app/data"
  }

  # Reverse Proxy

  networks_advanced {
    name = docker_network.internal_network.name
  }

  labels {
    label = "traefik.enable"
    value = "true"
  }

  labels {
    label = "traefik.http.routers.tasks.rule"
    value = "Host(`${local.domain_tasks}`)"
  }

  labels {
    label = "traefik.http.routers.tasks.entrypoints"
    value = "https"
  }

  labels {
    label = "traefik.http.routers.tasks.tls"
    value = "true"
  }

  labels {
    label = "traefik.http.routers.tasks.tls.certresolver"
    value = "letsencrypt"
  }
}

resource "docker_volume" "kanboard_data" {
  name = "kanboard_data"
}

# Miniflux
# ========

resource "docker_image" "miniflux" {
  name = "miniflux/miniflux:${local.version_miniflux}"
}

resource "docker_container" "miniflux" {
  image = docker_image.miniflux.latest
  name  = "miniflux"
  start = true

  # Wait for database's container to start (dumb implementation™).
  restart = "on-failure"

  # Configuration

  env = [
    # Database:
    "DATABASE_URL=${local.db_miniflux_url}",
    "RUN_MIGRATIONS=1",

    # Setup:
    # Create admin user if it doesn't already exist.
    "CREATE_ADMIN=1",
    "ADMIN_USERNAME=${local.user_miniflux}",
    "ADMIN_PASSWORD=${local.password_miniflux}",
  ]

  # Reverse Proxy

  networks_advanced {
    name = docker_network.internal_network.name
  }

  labels {
    label = "traefik.enable"
    value = "true"
  }

  labels {
    label = "traefik.http.routers.news.rule"
    value = "Host(`${local.domain_news}`)"
  }

  labels {
    label = "traefik.http.routers.news.entrypoints"
    value = "https"
  }

  labels {
    label = "traefik.http.routers.news.tls"
    value = "true"
  }

  labels {
    label = "traefik.http.routers.news.tls.certresolver"
    value = "letsencrypt"
  }
}

# Standard Notes
# ==============

resource "docker_image" "standardnotes_web" {
  name = "arugifa/standardnotes-web:${local.version_standardnotes_web}"
}

resource "docker_container" "standardnotes_web" {
  image = docker_image.standardnotes_web.latest
  name  = "standardnotes_web"
  start = true

  # Configuration

  env = [
    "SF_DEFAULT_SERVER=${var.host == "localhost" ? "http" : "https"}://rtfm.${local.domain_notes_webui}",
  ]

  # Reverse Proxy

  networks_advanced {
    name = docker_network.internal_network.name
  }

  labels {
    label = "traefik.enable"
    value = "true"
  }

  labels {
    label = "traefik.http.routers.notes_webui.rule"
    value = "Host(`${local.domain_notes_webui}`)"
  }

  labels {
    label = "traefik.http.routers.notes_webui.entrypoints"
    value = "https"
  }

  labels {
    label = "traefik.http.routers.notes_webui.tls"
    value = "true"
  }

  labels {
    label = "traefik.http.routers.notes_webui.tls.certresolver"
    value = "letsencrypt"
  }
}

resource "docker_image" "standardnotes_server" {
  name = "arugifa/standardnotes-server:${local.version_standardnotes_server}"
}

resource "docker_container" "standardnotes_server" {
  image = docker_image.standardnotes_server.latest
  name  = "standardnotes_server"
  start = true

  # Wait for database's container to start (dumb implementation™).
  restart = "on-failure"

  # Configuration

  command = [
    "/bin/sh", "-c",
    # Create database if not already exists.
    # Then, migrate database and start the server.
    "bundle exec rails db:create; bundle exec rails db:migrate && bundle exec rails s -b 0.0.0.0",
  ]

  env = [
    # Setup:
    "RAILS_ENV=production",
    "RAILS_SERVE_STATIC_FILES=true",
    "SECRET_KEY_BASE=${random_string.standardnotes_secret_key.result}",

    # Database:
    "DB_HOST=${local.db_standardnotes_host}",
    "DB_DATABASE=${local.db_standardnotes_name}",
    "DB_USERNAME=${local.db_standardnotes_user}",
    "DB_PASSWORD=${local.db_standardnotes_password}",
  ]

  # Reverse Proxy

  networks_advanced {
    name = docker_network.internal_network.name
  }

  labels {
    label = "traefik.enable"
    value = "true"
  }

  labels {
    label = "traefik.http.routers.notes_server.rule"
    value = "Host(`${local.domain_notes_server}`)"
  }

  labels {
    label = "traefik.http.routers.notes_server.entrypoints"
    value = "https"
  }

  labels {
    label = "traefik.http.routers.notes_server.tls"
    value = "true"
  }

  labels {
    label = "traefik.http.routers.notes_server.tls.certresolver"
    value = "letsencrypt"
  }

  labels {
    label = "traefik.http.services.notes_server.loadbalancer.server.port"
    value = "3000"
  }
}

resource "random_string" "standardnotes_secret_key" {
  length = 16

  # Special characters make Rails to break down.
  special = false
}

# Wallabag
# ========

resource "docker_image" "wallabag" {
  name = "wallabag/wallabag:${local.version_wallabag}"
}

resource "docker_container" "wallabag" {
  # See https://github.com/wallabag/docker/blob/master/root/etc/ansible/entrypoint.yml
  # to understand how Wallabag provisioning works.

  image = docker_image.wallabag.latest
  name  = "wallabag"
  start = true

  # Wait for database's container to start (dumb implementation™).
  restart = "on-failure"

  # Configuration

  env = [
    # Base domain for asset URLs.
    "SYMFONY__ENV__DOMAIN_NAME=${var.host == "localhost" ? "http" : "https"}://${local.domain_library}",
    # Disable user registration.
    "SYMFONY__ENV__FOSUSER_REGISTRATION=false",
    # Don't use the default Wallabag secret.
    "SYMFONY__ENV__SECRET=${random_string.wallabag_secret_key.result}",

    # Wallabag Databases:
    "SYMFONY__ENV__REDIS_HOST=${local.redis_wallabag_host}",

    "SYMFONY__ENV__DATABASE_DRIVER=pdo_pgsql",
    "SYMFONY__ENV__DATABASE_HOST=${local.db_wallabag_host}",
    "SYMFONY__ENV__DATABASE_NAME=${local.db_wallabag_name}",
    "SYMFONY__ENV__DATABASE_USER=${local.db_wallabag_user}",
    "SYMFONY__ENV__DATABASE_PASSWORD=${local.db_wallabag_password}",

    # XXX: Set absolutely the DB's default port! (11/2019)
    #
    # Otherwise, an error appears in the logs
    # during container creation/provisioning:
    #
    #   port is of type <type 'str'> and we were unable to convert to int:
    #   invalid literal for int() with base 10: '~'
    #
    "SYMFONY__ENV__DATABASE_PORT=5432",

    # XXX: Set absolutely the DB driver class! (11/2019)
    #
    # Otherwise, database provisioning fails
    # when the container starts for the first time.
    #
    # Also, another error appears in the logs
    # if trying then to connect to the web interface:
    #
    #   The stream or file "/var/www/wallabag/var/logs/prod.log" could not be opened:
    #   failed to open stream: Permission denied in /var/www/wallabag/vendor/monolog/monolog/src/Monolog/Handler/StreamHandler.php:107
    #
    "SYMFONY__ENV__DATABASE_DRIVER_CLASS=Wallabag\\CoreBundle\\Doctrine\\DBAL\\Driver\\CustomPostgreSQLDriver",

    # Only used to provision database
    # when starting the container for the first time.
    "POSTGRES_USER=${local.db_wallabag_user}",
    "POSTGRES_PASSWORD=${local.db_wallabag_password}",
  ]

  volumes {
    volume_name    = docker_volume.wallabag_images.name
    container_path = "/var/www/wallabag/web/assets/images"
  }

  # Reverse Proxy

  networks_advanced {
    name = docker_network.internal_network.name
  }

  labels {
    label = "traefik.enable"
    value = "true"
  }

  labels {
    label = "traefik.http.routers.library.rule"
    value = "Host(`${local.domain_library}`)"
  }

  labels {
    label = "traefik.http.routers.library.entrypoints"
    value = "https"
  }

  labels {
    label = "traefik.http.routers.library.tls"
    value = "true"
  }

  labels {
    label = "traefik.http.routers.library.tls.certresolver"
    value = "letsencrypt"
  }
}

resource "docker_volume" "wallabag_images" {
  name = "wallabag_images"
}

resource "random_string" "wallabag_secret_key" {
  length = 16

  # Special characters make Wallabag provisioning to break down.
  special = false
}

# =========
# Databases
# =========

resource "docker_image" "mysql" {
  name          = data.docker_registry_image.mysql.name
  pull_triggers = [data.docker_registry_image.mysql.sha256_digest]
}

resource "docker_image" "postgresql" {
  name          = data.docker_registry_image.postgresql.name
  pull_triggers = [data.docker_registry_image.postgresql.sha256_digest]
}

resource "docker_image" "redis" {
  name          = data.docker_registry_image.redis.name
  pull_triggers = [data.docker_registry_image.redis.sha256_digest]
}

# Kanboard
# ========

resource "docker_container" "kanboard_db" {
  image = docker_image.postgresql.latest
  name  = local.db_kanboard_host
  start = true

  env = [
    "POSTGRES_DB=${local.db_kanboard_name}",
    "POSTGRES_USER=${local.db_kanboard_user}",
    "POSTGRES_PASSWORD=${local.db_kanboard_password}",
  ]

  networks_advanced {
    name = docker_network.internal_network.name
  }

  volumes {
    volume_name    = docker_volume.kanboard_db.name
    container_path = "/var/lib/postgresql/data"
  }
}

resource "docker_volume" "kanboard_db" {
  name = "kanboard_db"
}

resource "random_string" "kanboard_db_password" {
  length  = 8
  special = false
}

# Miniflux
# ========

resource "docker_container" "miniflux_db" {
  image = docker_image.postgresql.latest
  name  = local.db_miniflux_host
  start = true

  env = [
    "POSTGRES_DB=${local.db_miniflux_name}",
    "POSTGRES_USER=${local.db_miniflux_user}",
    "POSTGRES_PASSWORD=${local.db_miniflux_password}",
  ]

  networks_advanced {
    name = docker_network.internal_network.name
  }

  volumes {
    volume_name    = docker_volume.miniflux_db.name
    container_path = "/var/lib/postgresql/data"
  }
}

resource "docker_volume" "miniflux_db" {
  name = "miniflux_db"
}

resource "random_string" "miniflux_db_password" {
  length  = 8
  special = false
}

# Standard Notes
# ==============

resource "docker_container" "standardnotes_db" {
  image = docker_image.mysql.latest
  name  = local.db_standardnotes_host
  start = true

  env = [
    "MYSQL_DATABASE=${local.db_standardnotes_name}",
    "MYSQL_USER=${local.db_standardnotes_user}",
    "MYSQL_PASSWORD=${local.db_standardnotes_password}",

    # The MySQL image requires the root's password to be set manually.
    # We use the same password than the default user, because there is
    # no reason to use a different one...
    "MYSQL_ROOT_PASSWORD=${local.db_standardnotes_password}",
  ]

  networks_advanced {
    name = docker_network.internal_network.name
  }

  volumes {
    volume_name    = docker_volume.standardnotes_db.name
    container_path = "/var/lib/mysql"
  }
}

resource "docker_volume" "standardnotes_db" {
  name = "standardnotes_db"
}

resource "random_string" "standardnotes_db_password" {
  length  = 8
  special = false
}

# Wallabag
# ========

resource "docker_container" "wallabag_redis" {
  # Redis is only used for data imports:
  # https://doc.wallabag.org/en/user/import/

  image = docker_image.redis.latest
  name  = local.redis_wallabag_host
  start = true

  networks_advanced {
    name = docker_network.internal_network.name
  }
}

resource "docker_container" "wallabag_db" {
  image = docker_image.postgresql.latest
  name  = local.db_wallabag_host
  start = true

  env = [
    # XXX: Don't define POSTGRES_DB! (11/2019)
    #
    # Otherwise, an error appears in the logs when connecting
    # for the first time to the Wallabag's web interface:
    #
    #   relation "wallabag_craue_config_setting" does not exist
    #
    "POSTGRES_USER=${local.db_wallabag_user}",
    "POSTGRES_PASSWORD=${local.db_wallabag_password}",
  ]

  networks_advanced {
    name = docker_network.internal_network.name
  }

  volumes {
    volume_name    = docker_volume.wallabag_db.name
    container_path = "/var/lib/postgresql/data"
  }
}

resource "docker_volume" "wallabag_db" {
  name = "wallabag_db"
}

resource "random_string" "wallabag_db_password" {
  length  = 8
  special = false
}
