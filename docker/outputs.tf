# =========
# Passwords
# =========

output "kanboard_db_password" {
  value = "${local.db_password_kanboard}"
}

output "miniflux_db_password" {
  value = "${local.db_password_miniflux}"
}

output "standardnotes_db_password" {
  value = "${local.db_password_standardnotes}"
}
