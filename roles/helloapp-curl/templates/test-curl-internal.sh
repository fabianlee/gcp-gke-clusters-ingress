#!/bin/bash

caStr="--cacert /tmp/myCA.{{cluster_name}}.local.crt"

echo ""
echo "========== INTERNAL TCP LB ===================="
domain=my-secondary.{{cluster_name}}.local
resolveStr="--resolve $domain:443:{{subnet_prefix}}.199"
set -x
curl $caStr $resolveStr --fail --connect-timeout 3 --retry 0 https://$domain/myint/
set +x

echo ""
echo "========== INTERNAL HTTPS LB ===================="
domain=my-secondary.{{cluster_name}}.local
resolveStr="--resolve $domain:443:{{subnet_prefix}}.99"
set -x
curl $caStr $resolveStr --fail --connect-timeout 3 --retry 0 https://$domain/myint/
