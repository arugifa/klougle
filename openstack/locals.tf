# ==========
# Networking
# ==========

locals {
  public_ip = "${openstack_networking_floatingip_v2.public_ip.address}"
  ssh_user  = "rancher"
}


# ==========
# Filesystem
# ==========

# Local Files and Directories
# ===========================

locals {
  docker_certs    = "~/.docker/klougle"
}


# Remote Files and Directories
# ============================

locals {
  data_device = "/dev/vdb"
  docker_dir  = "/mnt/docker"
}
