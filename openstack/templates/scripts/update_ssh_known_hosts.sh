set -e
set -x

# Remove server's FQDN and public IP from SSH known hosts,
# in case we get a new public IP when re-deploying the server instance.
#
# Don't use the `-i` option from sed to overwrite the `known_hosts' file,
# as it is implemented differently on Linux and macOS.
sed -n '/${fqdn}/!p' ~/.ssh/known_hosts > tmp && mv tmp ~/.ssh/known_hosts
sed -n '/${public_ip}/!p' ~/.ssh/known_hosts > tmp && mv tmp ~/.ssh/known_hosts
