#!/bin/bash -e
#VIC Build

# Data directory for the docker volumes
mkdir /data
systemctl start docker
systemctl enable docker

# Admiral persistent store
docker volume create admiral
mkdir /data/admiral

# Install docker-compose (required to run Harbor)
curl -L https://github.com/docker/compose/releases/download/1.20.1/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose && chmod +x /usr/local/bin/docker-compose

#Download the Harbor release
curl -O https://storage.googleapis.com/harbor-releases/release-1.4.0/harbor-online-installer-v1.4.0.tgz
# Python2 required for harbor configuration
tdnf install -y tar python2
tar xvf harbor-online-installer-v1.4.0.tgz
cd harbor

# Create new certificates and keys for harbor https (required)
openssl req -newkey rsa:4096 -nodes -sha256 -keyout ca.key -x509 -days 365 -out ca.crt \
  -subj "/C=US/ST=Texas/L=SanAntonio/O=AO/CN=harbor-`hostname`"
openssl req -newkey rsa:4096 -nodes -sha256 -keyout harbor-`hostname`.key -out harbor-`hostname`.csr \
   -subj "/C=US/ST=Texas/L=SanAntonio/O=AO/CN=harbor-`hostname`"
openssl x509 -req -days 365 -in harbor-`hostname`.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out harbor-`hostname`.crt
mkdir /data/cert
cp harbor-`hostname`.crt /data/cert/
cp harbor-`hostname`.key /data/cert/

# Set Harbor configuration options
sed -i "/hostname =/c\hostname = harbor-`hostname`" harbor.cfg
sed -i '/ui_url_protocol =/c\ui_url_protocol = https' harbor.cfg
sed -i "/ssl_cert =/c\ssl_cert = harbor-`hostname`.crt" harbor.cfg
sed -i "/ssl_cert_key =/c\ssl_cert_key = harbor-`hostname`.key" harbor.cfg
sed -i '/registry_storage_provider_config =/c\registry_storage_provider_config = rootdirectory:  /storage' harbor.cfg

# Change the name for the frontend harbor container
sed -i "/container_name: nginx/c\container_name: harbor-`hostname`" docker-compose.yml

# Install harbor (this runs a python script to fill out templates and the docker-compose up on all of the container components)
./install.sh --with-notary --with-clair

echo '{
  "users": [{
    "email": "administrator@vsphere.local",
    "password": "VMware1!",
    "roles": "administrator"
  }
  ]
}' > /data/admiral/local-users.json

chmod 0644 /data/admiral/local-users.json

# Run admiral (set the restart to always so this comes up on restart)
docker run -d -p 8282:8282 --name admiral \
  -v admiral:/var/admiral --network bridge \
  --restart always --log-driver=json-file --log-opt max-size=1g --log-opt max-file=2 \
  -v /data/admiral/local-users.json:/data/local-users.json \
  -e XENON_OPTS="--localUsers=/data/local-users.json" \
  vmware/admiral:v1.3.0

docker network connect harbor_harbor admiral

#Set up harbor as service
echo '#!/bin/bash
cd /root/harbor/ && /usr/local/bin/docker-compose -f docker-compose.yml -f docker-compose.notary.yml -f docker-compose.clair.yml up -d' > /usr/local/bin/harbor.sh
chmod +x /usr/local/bin/harbor.sh
echo '[Unit]
Description=Harbor Service
After=docker.service

[Service]
ExecStart=/usr/local/bin/harbor.sh

[Install]
WantedBy=multi-user.target' > /etc/systemd/system/harbor.service
systemctl enable harbor.service
