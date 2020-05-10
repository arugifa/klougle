# =========
# Passwords
# =========

output "kanboard_db_password" {
  value = local.db_kanboard_password
}

output "miniflux_db_password" {
  value = local.db_miniflux_password
}

output "standardnotes_db_password" {
  value = local.db_standardnotes_password
}

output "wallabag_db_password" {
  value = local.db_wallabag_password
}
