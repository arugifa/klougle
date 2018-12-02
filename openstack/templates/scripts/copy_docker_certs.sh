set -e
set -x

# Create a directory to store Docker client key and CA/server certificates.
# Also delete them manually if they already exist. We cannot rely on `scp`
# later on to ovewrite them, as some of them are in read-only mode.
rm -rf ${docker_certs}
mkdir -p ${docker_certs}

# Retrieve keys and certificates from Docker server.
# Also, don't ask for the user to confirm new host identity on the prompt, to not block the deployment.
scp -o StrictHostKeyChecking=no ${ssh_user}@${public_ip}:~/.docker/ca.pem ${docker_certs}
scp -o StrictHostKeyChecking=no ${ssh_user}@${public_ip}:~/.docker/cert.pem ${docker_certs}
scp -o StrictHostKeyChecking=no ${ssh_user}@${public_ip}:~/.docker/key.pem ${docker_certs}
