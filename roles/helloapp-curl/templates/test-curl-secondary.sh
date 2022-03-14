#!/bin/bash

caStr="--cacert /tmp/myCA.{{cluster_name}}.local.crt"

echo "========== SECONDARY TCP LB ===================="
{% if ingressgateway_secondary %}
domain=my-secondary.{{cluster_name}}.local
resolveStr="--resolve $domain:443:{{subnet_prefix}}.199"
set -x
curl $caStr $resolveStr --fail --connect-timeout 3 --retry 0 https://$domain/myint/
set +x
{% else %}
echo "No secondary TCP LB deployed"
{% endif %}

echo ""

echo "========== SECONDARY HTTPS LB ===================="
{% if https_lb_secondary %}
domain=my-secondary.{{cluster_name}}.local
resolveStr="--resolve $domain:443:{{subnet_prefix}}.99"
set -x
curl $caStr $resolveStr --fail --connect-timeout 3 --retry 0 https://$domain/myint/
{% else %}
echo "No secondary HTTPS LB deployed"
{% endif %}
