#!/bin/bash

caStr="--cacert /tmp/myCA.{{cluster_name}}.local.crt"

echo "========== PUBLIC ===================="
domain=my-primary.{{cluster_name}}.local
resolveStr="--resolve $domain:443:{{subnet_prefix}}.198"
set -x
curl $caStr $resolveStr https://$domain/myhello/
set +x

echo ""
echo "========== INTERNAL ===================="
domain=my-secondary.{{cluster_name}}.local
resolveStr="--resolve $domain:443:{{subnet_prefix}}.199"
set -x
curl $caStr $resolveStr https://$domain/myint/
set +x


