# ====================
# Server Configuration
# ====================

variable "flavor" {
  description = "Virtual machine flavor to use for the server."
}

variable "key_pairs" {
  description = "Authorized key pairs for remote access to the server."
  type        = "list"
}


# ==========
# Networking
# ==========

# DNS
# ===

variable "fqdn" {
  description = "Server's FQDN. Used to generate Docker TLS certificates."
  default     = ""
}

# OpenStack
# =========

# When the provider allows to directly connect to its external network:

variable "external_network" {
  description = "Network used to get a public IP and connect to the Internet. Mutually exclusive with internal_network and floating_ip_pool."
  default     = ""
}

# When the provider prefers instead to allocate floating IPs:

variable "floating_ip_pool" {
  description = "Network used to get a floating IP and connect to the Internet. Must be used with internal_network."
  default = ""
}

variable "internal_network" {
  description = "Network used to connect to the provider's external network through a gateway. Must be used with floating_ip_pool."
  default     = ""
}
