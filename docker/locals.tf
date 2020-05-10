# ====================
# Docker Configuration
# ====================

locals {
  docker_certs       = "~/.docker/klougle"
  docker_tcp_socket  = "tcp://${var.host}:2376/"
  docker_unix_socket = "unix:///var/run/docker.sock"
}

# ======================
# Service Configurations
# ======================

locals {
  domain = replace(var.host, "/(\\w+\\.)(\\w+\\.)(\\w+)/", "$2$3")
}

# Kanboard
# ========

locals {
  domain_tasks = "tasks.${local.domain}"

  version_kanboard = "v1.2.7"
}

# Miniflux
# ========

locals {
  domain_news = "news.${local.domain}"

  version_miniflux  = "2.0.13"
  user_miniflux     = "admin"
  password_miniflux = "password"
}

# Standard Notes
# ==============

locals {
  domain_notes_webui  = "notes.${local.domain}"
  domain_notes_server = "sync.${local.domain_notes_webui}"

  version_standardnotes_web    = "3.0.14"
  version_standardnotes_server = "0.0.0-rc.2019.08.02"
}

# Traefik
# =======

locals {
  domain_dashboard = "dashboard.${local.domain}"
}

# Wallabag
# ========

locals {
  domain_library = "library.${local.domain}"

  version_wallabag = "2.3.8"
}

# =======================
# Database Configurations
# =======================

# Kanboard
# ========

locals {
  db_kanboard_name     = "kanboard"
  db_kanboard_user     = "klougle"
  db_kanboard_password = random_string.kanboard_db_password.result
  db_kanboard_host     = "kanboard_db"
  db_kanboard_url      = "postgres://${local.db_kanboard_user}:${local.db_kanboard_password}@${local.db_kanboard_host}/${local.db_kanboard_name}"
}

# Miniflux
# ========

locals {
  db_miniflux_name     = "miniflux"
  db_miniflux_user     = "klougle"
  db_miniflux_password = random_string.miniflux_db_password.result
  db_miniflux_host     = "miniflux_db"
  db_miniflux_url      = "postgres://${local.db_miniflux_user}:${local.db_miniflux_password}@${local.db_miniflux_host}/${local.db_miniflux_name}?sslmode=disable"
}

# Standard Notes
# ==============

locals {
  db_standardnotes_name     = "standardnotes"
  db_standardnotes_user     = "klougle"
  db_standardnotes_password = random_string.standardnotes_db_password.result
  db_standardnotes_host     = "standardnotes_db"
}

# Wallabag
# ========

locals {
  # XXX: Use different values for DB's name and user's name! (11/2019)
  #
  # Otherwise, an error appears in the logs when connecting
  # for the first time to the web interface:
  #
  #   relation "wallabag_craue_config_setting" does not exist
  #
  db_wallabag_name     = "wallabag"
  db_wallabag_user     = "klougle"
  db_wallabag_password = random_string.wallabag_db_password.result
  db_wallabag_host     = "wallabag_db"

  redis_wallabag_host = "wallabag_redis"
}
