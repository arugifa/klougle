# ==========
# Networking
# ==========

# External Interface (Option 1)
# =============================

data "openstack_networking_network_v2" "external_network" {
  count = var.external_network != "" ? 1 : 0
  name  = var.external_network
}

# Floating IP + Internal Interface (Option 2)
# ===========================================

data "openstack_networking_network_v2" "floating_ip_pool" {
  count = var.floating_ip_pool != "" ? 1 : 0
  name  = var.floating_ip_pool
}

data "openstack_networking_network_v2" "internal_network" {
  count = var.internal_network != "" ? 1 : 0
  name  = var.internal_network
}

# ====================
# Server Configuration
# ====================

# Virtual Machine Flavor
# ======================

data "openstack_compute_flavor_v2" "flavor" {
  name = var.flavor
}

# OpenStack Key Pairs (SSH Authorized Keys)
# =========================================

data "openstack_compute_keypair_v2" "key_pairs" {
  count = length(var.key_pairs)
  name  = element(var.key_pairs, count.index)
}

# =====================
# Server Initialization
# =====================

# Cloud-Init File
# ===============

data "template_file" "cloud_init" {
  template = file("${path.module}/templates/cloud_init.yml")

  vars = {
    data_device = local.data_device
    docker_dir  = local.docker_dir
    ssh_keys    = jsonencode(data.openstack_compute_keypair_v2.key_pairs.*.public_key)
  }
}

# Docker TLS Setup
# ================

data "template_file" "setup_docker_tls" {
  template = file("${path.module}/templates/scripts/setup_docker_tls.sh")

  vars = {
    fqdn = var.fqdn
  }
}

data "template_file" "copy_docker_certificates" {
  template = file("${path.module}/templates/scripts/copy_docker_certs.sh")

  vars = {
    docker_certs = local.docker_certs
    public_ip    = local.public_ip
    ssh_user     = local.ssh_user
  }
}

# SSH Known Hosts
# ===============

data "template_file" "update_ssh_known_hosts" {
  template = file("${path.module}/templates/scripts/update_ssh_known_hosts.sh")

  vars = {
    fqdn      = var.fqdn
    public_ip = local.public_ip
  }
}
