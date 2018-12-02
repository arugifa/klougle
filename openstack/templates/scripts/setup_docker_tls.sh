set -e
set -x

# Generate Docker server certificate.
sudo ros tls gen --server -H localhost -H ${fqdn}
sudo system-docker restart docker

# Generate Docker client certificate.
sudo ros tls gen
