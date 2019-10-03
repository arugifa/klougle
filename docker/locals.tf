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
  domain = "${replace(var.host, "/(\\w+\\.)(\\w+\\.)(\\w+)/", "$2$3")}"
}

# News Reader (Miniflux)
# ======================

locals {
  domain_news               = "news.${local.domain}"

  version_miniflux          = "2.0.13"
  default_user_miniflux     = "admin"
  default_password_miniflux = "password"
}

# Notes Application (Standard Notes)
# ==================================

locals {
  domain_notes_webui           = "notes.${local.domain}"
  domain_notes_server          = "sync.${local.domain_notes_webui}"

  version_standardnotes_web    = "3.0.14"
  version_standardnotes_server = "0.0.0-rc.2019.08.02"
}

# Task Management (Kanboard)
# ==========================

locals {
  domain_tasks     = "tasks.${local.domain}"

  version_kanboard = "v1.2.7"
}


# =======================
# Database Configurations
# =======================

# Standard Notes
# ==============

locals {
  db_name_standardnotes     = "standardnotes"
  db_user_standardnotes     = "klougle"
  db_password_standardnotes = "${random_string.standardnotes_db_password.result}"
  db_host_standardnotes     = "standardnotes_db"
}

# Miniflux
# ========

locals {
  db_name_miniflux     = "miniflux"
  db_user_miniflux     = "klougle"
  db_password_miniflux = "${random_string.miniflux_db_password.result}"
  db_host_miniflux     = "miniflux_db"
  db_url_miniflux      = "postgres://${local.db_user_miniflux}:${local.db_password_miniflux}@${local.db_host_miniflux}/${local.db_name_miniflux}?sslmode=disable"
}
