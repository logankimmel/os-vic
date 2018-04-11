#
# Authenticate
curl --request POST \
  --url http://192.168.85.148:8282/core/authn/basic \
  --header 'authorization: Basic YWRtaW5AdnNwaGVyZS5sb2NhbDpWTXdhcmUxIQ==' \
  --header 'content-type: application/json' \
  --data '{
	"requestType":"LOGIN"
}'

# Get clusters
curl --request GET \
  --url 'http://192.168.85.148:8282/resources/clusters?%24count=true&documentType=true&expand=true&%24limit=50' \
  --header ' : ' \
  --header 'content-type: application/json' \
  --header 'x-project: /projects/default-project' \
  --header 'x-xenon-auth-token: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJ4biIsInN1YiI6Ii9jb3JlL2F1dGh6L3VzZXJzL1lXUnRhVzVBZG5Od2FHVnlaUzVzYjJOaGJBXHUwMDNkXHUwMDNkIiwiZXhwIjoxNTIzNDYxMzgxfQ.HaF0c9bW04eDmVoL1lGNtFjH2yz5rH2Rn3SghCpf6yk'

# Create new cluster with hostname
curl --request POST \
  --url http://192.168.85.148:8282/ \
  --header 'authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJ4biIsInN1YiI6Ii9jb3JlL2F1dGh6L3VzZXJzL1lXUnRhVzVBZG5Od2FHVnlaUzVzYjJOaGJBXHUwMDNkXHUwMDNkIiwiZXhwIjoxNTIzNDYxMzgxfQ.HaF0c9bW04eDmVoL1lGNtFjH2yz5rH2Rn3SghCpf6yk' \
  --header 'content-type: application/json' \
  --header 'x-project: /projects/default-project' \
  --header 'x-xenon-auth-token: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJ4biIsInN1YiI6Ii9jb3JlL2F1dGh6L3VzZXJzL1lXUnRhVzVBZG5Od2FHVnlaUzVzYjJOaGJBXHUwMDNkXHUwMDNkIiwiZXhwIjoxNTIzNDYxMzgxfQ.HaF0c9bW04eDmVoL1lGNtFjH2yz5rH2Rn3SghCpf6yk' \
  --data '{
  "hostState": {
    "address": "http://192.168.85.142:2375",
    "customProperties": {
      "__containerHostType": "DOCKER",
      "__adapterDockerType": "API",
      "__clusterName": "testChrome2"
    }
  },
  "acceptCertificate": false
}'

curl --request POST \
  --url http://192.168.85.148:8282/resources/clusters/8028af74d0bf2a7556993dfa2e950/hosts \
  --header 'content-type: application/json' \
  --header 'x-project: /projects/default-project' \
  --header 'x-xenon-auth-token: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJ4biIsInN1YiI6Ii9jb3JlL2F1dGh6L3VzZXJzL1lXUnRhVzVBZG5Od2FHVnlaUzVzYjJOaGJBXHUwMDNkXHUwMDNkIiwiZXhwIjoxNTIzNDYxMzgxfQ.HaF0c9bW04eDmVoL1lGNtFjH2yz5rH2Rn3SghCpf6yk' \
  --data '{
  "hostState": {
    "address": "http://192.168.85.150:2375",
    "customProperties": {
      "__containerHostType": "DOCKER",
      "__adapterDockerType": "API",
      "__hostAlias": "photon3"
    }
  },
  "acceptCertificate": false
}'
