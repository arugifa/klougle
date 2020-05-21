#!/usr/bin/env bash

set -e

assert_service_is_online () {
    service=$1
    domain=$2

    # The whole Docker infrastructure (containers + reverse proxy)
    # needs some time to start. In order to avoid getting 502 HTTP
    # status code when starting the tests, we wait a bit before for
    # the reverse proxy to be ready.

    echo "Test ${service}:"

    for i in {1..10}; do
        curl -o /dev/null -L -# $domain && break || if [[ "$i" != 10 ]]; then sleep 1 ; else exit 1 ; fi
    done
}

assert_service_is_online "Drive"                 "drive.localhost"
assert_service_is_online "Finance"               "finance.localhost"

# TODO: Test assets are correctly loaded (HTTP status code 200) (11/2019)
#
# When creating Wallabag container, if SYMFONY__ENV__DOMAIN_NAME
# environment variable is not set, then Wallabag uses a default
# and incorrect base domain to generate asset URLs.
#
assert_service_is_online "Library"               "library.localhost"

assert_service_is_online "News Reader"           "news.localhost"

# TODO: Test communication between web UI and default server (10/2019)
assert_service_is_online "Notes Web UI"          "notes.localhost"
assert_service_is_online "Notes Server"          "sync.notes.localhost"

assert_service_is_online "Task Management Board" "tasks.localhost"
