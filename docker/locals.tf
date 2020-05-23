# ====================
# Docker Configuration
# ====================

locals {
  docker_certs       = "~/.docker/klougle"
  docker_tcp_socket  = "tcp://${var.host}:2376/"
  docker_unix_socket = "unix:///var/run/docker.sock"
}

# ===============
# Service Domains
# ===============

locals {
  domain = replace(var.host, "/(\\w+\\.)(\\w+\\.)(\\w+)/", "$2$3")

  domain_alias        = "alias.${local.domain}"
  domain_dashboard    = "dashboard.${local.domain}"
  domain_finance      = "finance.${local.domain}"
  domain_library      = "library.${local.domain}"
  domain_news         = "news.${local.domain}"
  domain_notes_webui  = "notes.${local.domain}"
  domain_notes_server = "sync.${local.domain_notes_webui}"
  domain_tasks        = "tasks.${local.domain}"
}

# ======================
# Service Configurations
# ======================

# Firefly (Finance)
# =================

locals {
  version_firefly = "5.2.5"

  db_firefly_database = "firefly"
  db_firefly_user     = "firefly"
  db_firefly_password = random_string.firefly_db_password.result
  db_firefly_host     = "firefly_db"
  db_firefly_port     = "5432"
}

# Kanboard (Tasks)
# ================

locals {
  version_kanboard = "1.2.7"

  db_kanboard_database = "kanboard"
  db_kanboard_user     = "klougle"
  db_kanboard_password = random_string.kanboard_db_password.result
  db_kanboard_host     = "kanboard_db"
  db_kanboard_url      = "postgres://${local.db_kanboard_user}:${local.db_kanboard_password}@${local.db_kanboard_host}/${local.db_kanboard_database}"
}

# Miniflux (News)
# ===============

locals {
  version_miniflux  = "2.0.13"

  user_miniflux     = "admin"
  password_miniflux = "password"

  db_miniflux_database = "miniflux"
  db_miniflux_user     = "klougle"
  db_miniflux_password = random_string.miniflux_db_password.result
  db_miniflux_host     = "miniflux_db"
  db_miniflux_url      = "postgres://${local.db_miniflux_user}:${local.db_miniflux_password}@${local.db_miniflux_host}/${local.db_miniflux_database}?sslmode=disable"
}

# SimpleLogin (Email Aliases)
# ===========================

locals {
  version_simplelogin  = "3.1.0"

  mx_server = "mail.${local.domain}"

  db_simplelogin_database = "simplelogin"
  db_simplelogin_user     = "simplelogin"
  db_simplelogin_password = random_string.simplelogin_db_password.result
  db_simplelogin_host     = "simplelogin_db"
  db_simplelogin_url      = "postgres://${local.db_simplelogin_user}:${local.db_simplelogin_password}@${local.db_simplelogin_host}/${local.db_simplelogin_database}"

  sl_forwarder_host = "simplelogin_forwarder"
  sl_postfix_host   = "simplelogin_postfix"

  sl_dkim_dir         = "/sl/dkim"
  sl_dkim_private_key = "${local.sl_dkim_dir}/dkim.key"
  sl_dkim_public_key  = "${local.sl_dkim_dir}/dkim.pub.key"
  sl_dkim_key_length  = 2048
  sl_pgp_dir          = "/sl/pgp"
}

# Standard Notes (Notes)
# ======================

locals {
  version_standardnotes_web    = "3.0.14"
  version_standardnotes_server = "0.0.0-rc.2019.08.02"

  db_standardnotes_database = "standardnotes"
  db_standardnotes_user     = "klougle"
  db_standardnotes_password = random_string.standardnotes_db_password.result
  db_standardnotes_host     = "standardnotes_db"
}

# Wallabag (Library)
# ==================

locals {
  version_wallabag = "2.3.8"

  # XXX: Use different values for DB's name and user's name! (11/2019)
  #
  # Otherwise, an error appears in the logs when connecting
  # for the first time to the web interface:
  #
  #   relation "wallabag_craue_config_setting" does not exist
  #
  db_wallabag_database = "wallabag"
  db_wallabag_user     = "klougle"
  db_wallabag_password = random_string.wallabag_db_password.result
  db_wallabag_host     = "wallabag_db"
  db_wallabag_port     = "5432"

  redis_wallabag_host = "wallabag_redis"
}
