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
  domain_news           = "news.${local.domain}"

  user_news             = "admin"
  default_password_news = "password"
}

# Task Management (Kanboard)
# ==========================

locals {
  domain_tasks           = "tasks.${local.domain}"
}


# =======================
# Database Configurations
# =======================

# Miniflux
# ========

locals {
  miniflux_db_name     = "miniflux"
  miniflux_db_user     = "klougle"
  miniflux_db_password = "${random_string.miniflux_db_password.result}"
  miniflux_db_host     = "miniflux_db"
  miniflux_db_url      = "postgres://${local.miniflux_db_user}:${local.miniflux_db_password}@${local.miniflux_db_host}/${local.miniflux_db_name}?sslmode=disable"
}
