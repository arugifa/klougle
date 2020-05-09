# ====================
# Docker Configuration
# ====================

locals {
  docker_certs       = "~/.docker/klougle"
  docker_tcp_socket  = "tcp://${var.host}:2376/"
  docker_unix_socket = "unix:///var/run/docker.sock"
}

# ========================
# Networking Configuration
# ========================

locals {
  version_nginx_letsencrypt = "v1.12"
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

  version_miniflux          = "2.0.13"
  default_user_miniflux     = "admin"
  default_password_miniflux = "password"
}

# Standard Notes
# ==============

locals {
  domain_notes_webui  = "notes.${local.domain}"
  domain_notes_server = "sync.${local.domain_notes_webui}"

  version_standardnotes_web    = "3.0.14"
  version_standardnotes_server = "0.0.0-rc.2019.08.02"
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
  db_name_kanboard     = "kanboard"
  db_user_kanboard     = "klougle"
  db_password_kanboard = random_string.kanboard_db_password.result
  db_host_kanboard     = "kanboard_db"
  db_url_kanboard      = "postgres://${local.db_user_kanboard}:${local.db_password_kanboard}@${local.db_host_kanboard}/${local.db_name_kanboard}"
}

# Miniflux
# ========

locals {
  db_name_miniflux     = "miniflux"
  db_user_miniflux     = "klougle"
  db_password_miniflux = random_string.miniflux_db_password.result
  db_host_miniflux     = "miniflux_db"
  db_url_miniflux      = "postgres://${local.db_user_miniflux}:${local.db_password_miniflux}@${local.db_host_miniflux}/${local.db_name_miniflux}?sslmode=disable"
}

# Standard Notes
# ==============

locals {
  db_name_standardnotes     = "standardnotes"
  db_user_standardnotes     = "klougle"
  db_password_standardnotes = random_string.standardnotes_db_password.result
  db_host_standardnotes     = "standardnotes_db"
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
  db_name_wallabag     = "wallabag"
  db_user_wallabag     = "klougle"
  db_password_wallabag = random_string.wallabag_db_password.result
  db_host_wallabag     = "wallabag_db"

  redis_host_wallabag = "wallabag_redis"
}
