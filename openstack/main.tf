# ====================
# Server Configuration
# ====================

# Operating System
# ================

resource "openstack_images_image_v2" "rancheros" {
  name             = "RancherOS 1.4.2"
  image_source_url = "https://github.com/rancher/os/releases/download/v1.4.2/rancheros-openstack.img"
  container_format = "bare"
  disk_format      = "qcow2"
}

# Virtual Machine Instance
# ========================

resource "openstack_compute_instance_v2" "server" {
  name            = "Kloügle Server"
  image_id        = "${openstack_images_image_v2.rancheros.id}"
  flavor_id       = "${data.openstack_compute_flavor_v2.flavor.id}"
  security_groups = ["${openstack_networking_secgroup_v2.firewall.name}"]

  config_drive    = true
  user_data       = "${data.template_file.cloud_init.rendered}"

  network {
    # If the provider doesn't allow to directly connect to the external
    # network, then we have to connect to an internal network instead, and use
    # a floating IP.
    uuid = "${var.floating_ip_pool != "" ? "${element(concat(data.openstack_networking_network_v2.internal_network.*.id, list("")), 0)}" : "${element(concat(data.openstack_networking_network_v2.external_network.*.id, list("")), 0)}"}"

    # Thanks to https://github.com/hashicorp/terraform/issues/11210

    # For an unknown reason, attaching the server to an internal network with
    # openstack_compute_interface_attach_v2 creates a virtual machine with two
    # private addresses. Hence, it has to be done here instead.
  }
}

# Persistent Data Volume
# ======================

resource "openstack_blockstorage_volume_v2" "data" {
  name = "Kloügle Data"
  size = 10
}

resource "openstack_compute_volume_attach_v2" "data" {
  instance_id = "${openstack_compute_instance_v2.server.id}"
  volume_id   = "${openstack_blockstorage_volume_v2.data.id}"
  device      = "${local.data_device}"
}


# ==========
# Networking
# ==========

# Floating IP
# ===========

# We only need a floating IP if the provider doesn't allow to connect directly
# to the external network.

resource "openstack_networking_floatingip_v2" "public_ip" {
  count   = "${var.floating_ip_pool != "" ? 1 : 0}"
  pool    = "${data.openstack_networking_network_v2.floating_ip_pool.name}"
}

resource "openstack_compute_floatingip_associate_v2" "public_ip" {
  count       = "${var.floating_ip_pool != "" ? 1 : 0}"

  floating_ip = "${openstack_networking_floatingip_v2.public_ip.address}"
  instance_id = "${openstack_compute_instance_v2.server.id}"
}

# Firewall
# ========

resource "openstack_networking_secgroup_v2" "firewall" {
  name        = "Kloügle Firewall"
}

resource "openstack_networking_secgroup_rule_v2" "docker" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 2376
  port_range_max    = 2376
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = "${openstack_networking_secgroup_v2.firewall.id}"
}

resource "openstack_networking_secgroup_rule_v2" "http" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = "${openstack_networking_secgroup_v2.firewall.id}"
}

resource "openstack_networking_secgroup_rule_v2" "https" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = "${openstack_networking_secgroup_v2.firewall.id}"
}

resource "openstack_networking_secgroup_rule_v2" "ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = "${openstack_networking_secgroup_v2.firewall.id}"
}

# SSH and Docker TLS Configuration
# ================================

resource "null_resource" "ssh_config" {
  triggers {
    server_id = "${openstack_compute_instance_v2.server.id}"
    public_ip = "${local.public_ip}"
  }

  provisioner "local-exec" {
    command = "${data.template_file.update_ssh_known_hosts.rendered}"
  }
}

resource "null_resource" "docker_tls" {
  triggers {
    server_id = "${openstack_compute_instance_v2.server.id}"
  }

  provisioner "remote-exec" {
    inline = ["${data.template_file.setup_docker_tls.rendered}"]

    connection {
      host    = "${local.public_ip}"
      user    = "${local.ssh_user}"
      # FIXME(arugifa): Why wait-for-docker, in cloud_init.yml, hangs for 6 minutes? (12/2018)
      # timeout = "10m"
    }
  }

  provisioner "local-exec" {
    command = "${data.template_file.copy_docker_certificates.rendered}"
  }
}
