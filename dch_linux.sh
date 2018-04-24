#DCH Build
if [ -z ${VICHOSTNAME+x} ]
  then
    echo "No Admiral enpoint supplied. Will function as standalone Docker Host"
  else
    VICHOSTNAME=$VICHOSTNAME
    VICADMIN=$VICADMIN
    VICPASS=$VICPASS
fi

# Listen on external port
sed -i '/ExecStart=/c\ExecStart=/usr/bin/dockerd -H tcp://0.0.0.0:2375 -H unix:///var/run/docker.sock' /lib/systemd/system/docker.service

# Add Harbor registry (insecure due to self-signed cert)
if [ ${VICHOSTNAME+x} ]; then
  mkdir /etc/docker
  echo "{
    \"insecure-registries\" : [ \"${VICHOSTNAME}:443\", \"${VICHOSTNAME}\" ]
}" > /etc/docker/daemon.json && chmod 0644 /etc/docker/daemon.json
fi
# Start docker service and enable on startup
systemctl start docker
systemctl enable docker

#Open firewall for API access and save firewall rule
iptables -A INPUT -p tcp --dport 2375 -j ACCEPT
iptables-save > /etc/systemd/scripts/ip4save

if [ -z ${VICHOSTNAME+x} ]
  then
    echo "No admiral VICHOSTNAME, all finished"
    exit 0
fi

echo "Adding DCH host to Admiral VICHOSTNAME: $VICHOSTNAME"

# Install python and tooling for python script with REST calls
tdnf install -y python2 python-setuptools
easy_install -U requests

# Get IP address of eth0 (needed for python script)
ADDR=$(/sbin/ifconfig eth0 | grep 'inet addr' | cut -d: -f2 | awk '{print $1}')

echo "#!/usr/bin/python
import requests
data = '{\"requestType\":\"LOGIN\"}'
print 'Authenticating to the Admiral VICHOSTNAME'
response = requests.post('http://${VICHOSTNAME}:8282/core/authn/basic', auth=('${VICADMIN}', '${VICPASS}'), data=data)
response.raise_for_status()
auth = response.headers['x-xenon-auth-token']
headers = {'x-xenon-auth-token': auth, 'x-project' : '/projects/default-project'}
response = requests.get('http://${VICHOSTNAME}:8282/resources/clusters?%24limit=50&expand=true&documentType=true&%24count=true', headers=headers)
clusterLinux = ''
documents = response.json()['documents']
for doc in documents:
    if documents[doc]['name'] == 'Default-Linux':
        clusterLinux = doc
        break
if clusterLinux == '':
    print 'No current clusters adding host to Default new cluster'
    data = {
        \"hostState\": {
            \"address\": \"http://${ADDR}:2375\",
            \"customProperties\": {
            \"__containerHostType\": \"DOCKER\",
            \"__adapterDockerType\": \"API\",
            \"__clusterName\": \"Default-Linux\"
            }
        },
        \"acceptCertificate\": \"false\"
    }
    response = requests.post('http://${VICHOSTNAME}:8282/resources/clusters', json=data, headers=headers)
    response.raise_for_status()
    print 'Successfully added Host to new Cluster for default project'
else:
    print 'Adding host to existing default cluster'
    data = {
        \"hostState\": {
            \"address\": \"http://${ADDR}:2375\",
            \"customProperties\": {
                \"__containerHostType\": \"DOCKER\",
                \"__adapterDockerType\": \"API\",
                \"__hostAlias\": \"`hostname`\"
            }
        },
        \"acceptCertificate\": \"false\"
    }
    response = requests.post('http://${VICHOSTNAME}:8282' + clusterLinux + '/hosts', json=data, headers=headers)
    response.raise_for_status()
    print 'Successfully added Host to existing default cluster in default project'
exit()" > /tmp/add_host_to_admiral
chmod +x /tmp/add_host_to_admiral
/tmp/add_host_to_admiral
