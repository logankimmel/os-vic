#!/bin/bash -e
#VIC Build
if [ -z $VICADMIN ]
  then
    echo "No Admiral admin creds supplied, using the default"
    VICADMIN="administrator@vsphere.local"
    VICPASS="VMware1!"
  else
    VICADMIN=$VICADMIN
    VICPASS=$VICPASS
    VICDOMAIN=$VICDOMAIN
fi
if [ -z $VICDOMAIN ]
  then
    echo "Using the default example.com domain"
    VICDOMAIN="example.com"
fi
export TERM=xterm
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/root/bin

hostname=$(hostname)
HNAME="$hostname.$VICDOMAIN"

# Set the HOSTNAME
hostnamectl set-hostname $HNAME

# Data directory for the docker volumes
mkdir -p /data

# Install DOCKER
yum remove docker \
                  docker-client \
                  docker-client-latest \
                  docker-common \
                  docker-latest \
                  docker-latest-logrotate \
                  docker-logrotate \
                  docker-selinux \
                  docker-engine-selinux \
                  docker-engine
yum install -y yum-utils \
                  device-mapper-persistent-data \
                  lvm2
yum-config-manager \
                  --add-repo \
                  https://download.docker.com/linux/centos/docker-ce.repo
yum install -y docker-ce

systemctl start docker
systemctl enable docker

# Install docker-compose (required to run Harbor)
curl -L https://github.com/docker/compose/releases/download/1.20.1/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose && chmod +x /usr/local/bin/docker-compose

#Download the Harbor release
pushd /opt
curl -O https://storage.googleapis.com/harbor-releases/release-1.4.0/harbor-online-installer-v1.4.0.tgz
# Python2 required for harbor configuration
yum install -y tar python2 python-setuptools bc net-tools
tar xvf harbor-online-installer-v1.4.0.tgz
rm harbor-online-installer-v1.4.0.tgz
cd harbor

ADDR=$(/sbin/ifconfig eno16780032 | grep 'inet' | cut -d: -f2 | awk '{print $2}')

echo "[ req ]
prompt = no
default_bits       = 2048
distinguished_name = req_distinguished_name
[ req_distinguished_name ]
C = US
ST = Texas
L = SanAntonio
O = AO
OU = Courts
CN = ${HNAME}
[ v3_req ]
subjectAltName = @alt_names
[ alt_names ]
DNS = ${HNAME}
IP   = ${ADDR}" > san.cnf

# Create new certificates and keys for harbor https (required)
openssl req -newkey rsa:4096 -nodes -sha256 -keyout ca.key -x509 -days 365 -out ca.crt \
  -config san.cnf -extensions v3_req
openssl req -newkey rsa:4096 -nodes -sha256 -keyout ${HNAME}.key -out ${HNAME}.csr \
  -config san.cnf -extensions v3_req
openssl x509 -req -days 3650 -in ${HNAME}.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out ${HNAME}.crt -extensions v3_req -extfile san.cnf

mkdir -p /data/cert
cp ${HNAME}.crt /data/cert/
cp ${HNAME}.key /data/cert/

# Set Harbor configuration options
sed -i "/hostname =/c\hostname = ${HNAME}" harbor.cfg
sed -i '/ui_url_protocol =/c\ui_url_protocol = https' harbor.cfg
sed -i "/ssl_cert =/c\ssl_cert = ${HNAME}.crt" harbor.cfg
sed -i "/ssl_cert_key =/c\ssl_cert_key = ${HNAME}.key" harbor.cfg
sed -i '/registry_storage_provider_config =/c\registry_storage_provider_config = rootdirectory:  /storage' harbor.cfg
sed -i "/harbor_admin_password =/c\harbor_admin_password = ${VICPASS}" harbor.cfg

# Change the name for the frontend harbor container
sed -i "/container_name: nginx/c\    container_name: ${HNAME}" docker-compose.yml

# Upgrade the docker-compose version
sed -i "/version: '2'/c\version: '2.2'" docker-compose.*

# Set the limit on the clairr container to 50% of current number of PROCESSORS
processors=$(cat /proc/cpuinfo | grep processor | wc -l)
value=$(echo "scale=3 ; $processors / 2" | bc)
sed -i "/cpu_quota: 150000/c\    cpus: $value" docker-compose.clair.yml
# Install harbor (this runs a python script to fill out templates and the docker-compose up on all of the container components)
unset host
./install.sh --with-notary --with-clair

popd

# Admiral persistent store
docker volume create admiral
mkdir -p /data/admiral

echo "{
  \"users\": [{
    \"email\": \"${VICADMIN}\",
    \"password\": \"${VICPASS}\",
    \"roles\": \"administrator\"
  }
  ]
}" > /data/admiral/local-users.json

chmod 0644 /data/admiral/local-users.json

# Run admiral (set the restart to always so this comes up on restart)
docker run -d -p 8282:8282 --name admiral \
  -v admiral:/var/admiral --network bridge \
  --restart always --log-driver=json-file --log-opt max-size=1g --log-opt max-file=2 \
  -v /data/admiral/local-users.json:/data/local-users.json \
  -e XENON_OPTS="--localUsers=/data/local-users.json" \
  vmware/admiral:v1.4.0

docker network connect harbor_harbor admiral

docker run -d -p 8080:8080 --name admiral-idm --restart always --network harbor_harbor \
  logankimmel/admiral-idm:latest

#Set up harbor as service
echo '#!/bin/bash
cd /opt/harbor/ && /usr/local/bin/docker-compose -f docker-compose.yml -f docker-compose.notary.yml -f docker-compose.clair.yml up -d' > /usr/local/bin/harbor.sh
chmod +x /usr/local/bin/harbor.sh
echo '[Unit]
Description=Harbor Service
After=docker.service

[Service]
ExecStart=/usr/local/bin/harbor.sh

[Install]
WantedBy=multi-user.target' > /etc/systemd/system/harbor.service
systemctl enable harbor.service

# Install requests for python REST calls
easy_install -U requests

# Create python file to automate the automation of adding harbor registry to admiral
sleep 20
echo "#!/usr/bin/python
import requests
data = '{\"requestType\":\"LOGIN\"}'
print 'Authenticating to the Admiral endpoint'
response = requests.post('http://127.0.0.1:8282/core/authn/basic', auth=('${VICADMIN}', '${VICPASS}'), data=data)
response.raise_for_status()
auth = response.headers['x-xenon-auth-token']
headers = {'x-xenon-auth-token': auth}
cert = open('/data/cert/${HNAME}.crt', 'r').read()
c = {'certificate': cert}
print 'Adding Harbor certificate'
response = requests.post('http://127.0.0.1:8282/config/trust-certs', json=c, headers=headers)
response.raise_for_status()
c = {
  'type': 'Password',
  'userEmail': 'admin',
  'privateKey': '${VICPASS}',
  'customProperties': {
    '__authCredentialsName': 'HarborAdmin'
  }
}
print 'Adding Harbor login credentials'
response = requests.post('http://127.0.0.1:8282/core/auth/credentials', json=c, headers=headers)
response.raise_for_status()
o = response.json()['documentSelfLink']
c = {
  'hostState': {
    'address': 'https://${HNAME}:443',
    'name': 'Harbor',
    'endpointType': 'container.docker.registry',
    'authCredentialsLink': o
  }
}
print 'Adding Harbor registry to Admiral'
response = requests.put('http://127.0.0.1:8282/config/registry-spec', json=c, headers=headers)
response.raise_for_status()
print 'Successfully added Harbor registry to Admiral'" >> /tmp/add_registry
chmod +x /tmp/add_registry
/tmp/add_registry
