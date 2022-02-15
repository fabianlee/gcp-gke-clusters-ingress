#!/bin/bash

caStr="--cacert /tmp/myCA.{{cluster_name}}.local.crt"

publicIP=$(kubectl get ingress -n asm-gateways my-ingress -o=jsonpath="{.status.loadBalancer.ingress[0].ip}")
[ -n "$publicIP" ] || { echo "ERROR could not find public IP for my-ingress"; exit 3; }

echo "========== PUBLIC ===================="
domain=my-primary.{{cluster_name}}.local
resolveStr="--resolve $domain:443:$publicIP"

# Host header not required, using SNI
#curl --header "Host: $domain" $caStr $resolveStr https://$domain/myhello/

set -x
curl $caStr $resolveStr https://$domain/myhello/
set +x


