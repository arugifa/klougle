#!/usr/bin/env bash

set -e

terraform destroy -auto-approve docker/
