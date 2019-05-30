#!/usr/bin/env bash

set -e


# Infrastructure Deployment
# =========================

terraform init docker/
terraform apply -auto-approve docker/


# Test Suite
# ==========

assert_service_is_online () {
    service=$1
    domain=$2

    # The whole Docker infrastructure (containers + reverse proxy)
    # needs some time to start. In order to avoid getting 502 HTTP
    # status code when starting the tests, we wait a bit before for
    # the reverse proxy to be ready.

    echo "Test ${service}:"

    for i in {1..10}; do
        wget -O /dev/null $domain && break || if [[ "$i" != 10 ]]; then sleep 1 ; else exit 1 ; fi
    done
}

assert_service_is_online "News Reader"           "news.localhost"
assert_service_is_online "Task Management Board" "tasks.localhost"


# Infrastructure Destruction
# ==========================

terraform destroy -auto-approve docker/
