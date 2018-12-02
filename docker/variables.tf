# ====================
# Docker Configuration
# ====================

# Docker Host

variable "host" {
  default     = "localhost"
  description = "FQDN of the host running Docker (e.g., cloud.example.com). Also used to determine service domains."
}
