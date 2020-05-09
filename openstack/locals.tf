# ==========
# Networking
# ==========

locals {
  # Depending on the network configuration, the public IP is either a floating
  # IP, or the IP address of an interface directly attached to the external
  # network.
  public_ip = element(
    concat(
      openstack_networking_floatingip_v2.public_ip.*.address,
      openstack_compute_instance_v2.server.*.access_ip_v4,
    ),
    0,
  )
  # Thanks to https://blog.gruntwork.io/terraform-tips-tricks-loops-if-statements-and-gotchas-f739bbae55f9
}

locals {
  ssh_user = "rancher"
}

# ==========
# Filesystem
# ==========

# Local Files and Directories
# ===========================

locals {
  docker_certs = "~/.docker/klougle"
}

# Remote Files and Directories
# ============================

locals {
  data_device = "/dev/vdb"
  docker_dir  = "/mnt/docker"
}
