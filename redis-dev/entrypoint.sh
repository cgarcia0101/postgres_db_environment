#!/bin/sh
set -e

# Copy SSH key from build arg and set permissions
cp /root/ssh_key /tmp/id_rsa
chmod 600 /tmp/id_rsa

exec ssh -o StrictHostKeyChecking=no -i /tmp/id_rsa -N \
  -L 0.0.0.0:6378:${BASTION_URL} \
  ${REDIS_DEV_USER}@${REDIS_DEV_URL}
