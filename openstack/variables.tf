# ==========
# Networking
# ==========

# Server FQDN
# ===========

variable "fqdn" {
  description = "Server's FQDN. Used to generate Docker TLS certificates."
}


# OpenStack Key Pairs (SSH Authorized Keys)
# =========================================

variable "key_pairs" {
  description = "Authorized key pairs for remote access to the server."
  type        = "list"
}


# OpenStack Network
# =================

variable "private_network" {
  description = "Network to connect to the server."
}


# OpenStack Floating IP Pool
# ==========================

variable "public_network" {
  description = "Network pool to use to get a public IP address."
}
