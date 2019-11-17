# ====================
# Docker Configuration
# ====================

# Docker Host

variable "host" {
  default     = "localhost"
  description = "FQDN of the host running Docker (e.g., cloud.example.com). Also used to determine service domains."
}

variable "letsencrypt_email" {
  default     = ""
  description = "Email address used by Let's Encrypt for account recovery, and to warn about expiring certificates."
}
