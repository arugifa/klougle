#!/usr/bin/env bash

openstack server list -c ID -f value | xargs -r openstack server delete
openstack image list --private -c ID -f value | xargs -r openstack image delete
openstack volume list -c ID -f value | xargs -r openstack volume delete
openstack security group list -c ID -f value | xargs -r openstack security group delete
openstack keypair list -c Name -f value | xargs -r openstack keypair delete
