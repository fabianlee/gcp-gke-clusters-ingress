#!/bin/bash
#

caStr="--cacert /tmp/myCA.{{cluster_name}}.local.crt"

publicIP=$(kubectl get ingress -n default ap-my-ingress -o=jsonpath="{.status.loadBalancer.ingress[0].ip}")
[ -n "$publicIP" ] || { echo "ERROR could not find public IP for ingress object"; exit 3; }

echo "========== PUBLIC ===================="
domain=my-primary.{{cluster_name}}.local
resolveStr="--resolve $domain:443:$publicIP"

# Host header not required, HTTPS LB uses SNI
#curl --header "Host: $domain" $caStr $resolveStr https://$domain/myhello/

set -x
curl $caStr $resolveStr https://$domain/myhello/
set +x


