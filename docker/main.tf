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

resource "docker_image" "nginx" {
  name          = data.docker_registry_image.nginx.name
  pull_triggers = [data.docker_registry_image.nginx.sha256_digest]
}

resource "docker_container" "nginx" {
  image = docker_image.nginx.latest
  name  = "nginx"
  start = true

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

  volumes {
    # Give access to Docker's socket, to discover service containers.
    host_path      = "/var/run/docker.sock"
    container_path = "/tmp/docker.sock"
    read_only      = true
  }

  volumes {
    # Used by Nginx Let's Encrypt,
    # to store the certificates, private keys, and ACME account keys.
    container_path = "/etc/nginx/certs"
  }

  volumes {
    # Used by Nginx Let's Encrypt,
    # to let Nginx serving the http-01 challenge files to Let's Encrypt.
    container_path = "/etc/nginx/vhost.d"
  }

  volumes {
    # Used by Nginx Let's Encrypt,
    # to store the http-01 challenge files.
    container_path = "/usr/share/nginx/html"
  }
}

# Let's Encrypt
# =============

resource "docker_image" "nginx_letsencrypt" {
  count = var.host == "localhost" ? 0 : 1
  name  = "jrcs/letsencrypt-nginx-proxy-companion:${local.version_nginx_letsencrypt}"
}

resource "docker_container" "nginx_letsencrypt" {
  count = var.host == "localhost" ? 0 : 1

  image = docker_image.nginx_letsencrypt[0].latest
  name  = "nginx_letsencrypt"
  start = true

  env = [
    "DEFAULT_EMAIL=${var.letsencrypt_email}",
  ]

  volumes {
    # Give access to Docker's socket, to discover service containers.
    host_path      = "/var/run/docker.sock"
    container_path = "/var/run/docker.sock"
    read_only      = true
  }

  volumes {
    # Store certificates, keys and challenge files inside the Nginx container.
    from_container = docker_container.nginx.name
  }
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

  env = [
    # Reverse Proxy
    "VIRTUAL_HOST=${local.domain_tasks}",
    "LETSENCRYPT_HOST=${local.domain_tasks}",

    # Kanboard Database
    "DATABASE_URL=${local.db_url_kanboard}",
  ]

  networks_advanced {
    name = docker_network.internal_network.name
  }

  volumes {
    volume_name    = docker_volume.kanboard_data.name
    container_path = "/var/www/app/data"
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

  env = [
    # Reverse Proxy
    "VIRTUAL_HOST=${local.domain_news}",
    "LETSENCRYPT_HOST=${local.domain_news}",

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
    name = docker_network.internal_network.name
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

  env = [
    # Reverse Proxy
    "VIRTUAL_HOST=${local.domain_notes_webui}",
    "LETSENCRYPT_HOST=${local.domain_notes_webui}",

    # Standard Notes Server
    "SF_DEFAULT_SERVER=${var.host == "localhost" ? "http" : "https"}://rtfm.${local.domain_notes_webui}",
  ]

  networks_advanced {
    name = docker_network.internal_network.name
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

    "LETSENCRYPT_HOST=${local.domain_notes_server}",

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
    name = docker_network.internal_network.name
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

  env = [
    # Reverse Proxy
    "VIRTUAL_HOST=${local.domain_library}",
    "LETSENCRYPT_HOST=${local.domain_library}",

    # Wallabag Configuration
    # Base domain for asset URLs.
    "SYMFONY__ENV__DOMAIN_NAME=${var.host == "localhost" ? "http" : "https"}://${local.domain_library}",
    # Disable user registration.
    "SYMFONY__ENV__FOSUSER_REGISTRATION=false",
    # Don't use the default Wallabag secret.
    "SYMFONY__ENV__SECRET=${random_string.wallabag_secret_key.result}",

    # Wallabag Databases
    "SYMFONY__ENV__REDIS_HOST=${local.redis_host_wallabag}",

    "SYMFONY__ENV__DATABASE_DRIVER=pdo_pgsql",
    "SYMFONY__ENV__DATABASE_HOST=${local.db_host_wallabag}",
    "SYMFONY__ENV__DATABASE_NAME=${local.db_name_wallabag}",
    "SYMFONY__ENV__DATABASE_USER=${local.db_user_wallabag}",
    "SYMFONY__ENV__DATABASE_PASSWORD=${local.db_password_wallabag}",

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
    "POSTGRES_USER=${local.db_user_wallabag}",
    "POSTGRES_PASSWORD=${local.db_password_wallabag}",
  ]

  networks_advanced {
    name = docker_network.internal_network.name
  }

  volumes {
    volume_name    = docker_volume.wallabag_images.name
    container_path = "/var/www/wallabag/web/assets/images"
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
  name  = local.db_host_kanboard
  start = true

  env = [
    "POSTGRES_DB=${local.db_name_kanboard}",
    "POSTGRES_USER=${local.db_user_kanboard}",
    "POSTGRES_PASSWORD=${local.db_password_kanboard}",
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
  name  = local.db_host_miniflux
  start = true

  env = [
    "POSTGRES_DB=${local.db_name_miniflux}",
    "POSTGRES_USER=${local.db_user_miniflux}",
    "POSTGRES_PASSWORD=${local.db_password_miniflux}",
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
  name  = local.db_host_standardnotes
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
  name  = local.redis_host_wallabag
  start = true

  networks_advanced {
    name = docker_network.internal_network.name
  }
}

resource "docker_container" "wallabag_db" {
  image = docker_image.postgresql.latest
  name  = local.db_host_wallabag
  start = true

  env = [
    # XXX: Don't define POSTGRES_DB! (11/2019)
    #
    # Otherwise, an error appears in the logs when connecting
    # for the first time to the Wallabag's web interface:
    #
    #   relation "wallabag_craue_config_setting" does not exist
    #
    "POSTGRES_USER=${local.db_user_wallabag}",
    "POSTGRES_PASSWORD=${local.db_password_wallabag}",
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
