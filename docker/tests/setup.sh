#!/usr/bin/env bash

set -e

terraform init docker/
terraform apply -auto-approve docker/
