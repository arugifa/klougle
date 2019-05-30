#!/usr/bin/env bash

set -e


# Infrastructure Deployment
# =========================

terraform init openstack/
terraform apply -auto-approve openstack/


# Infrastructure Destruction
# ==========================

terraform destroy -auto-approve openstack/
