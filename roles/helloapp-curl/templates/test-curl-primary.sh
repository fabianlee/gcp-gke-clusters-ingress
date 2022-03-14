#!/bin/bash
#

caStr="--cacert /tmp/myCA.{{cluster_name}}.local.crt"

echo "========== PRIMARY TCP LB ===================="
{% if ingressgateway_primary %}
domain=my-primary.{{cluster_name}}.local
resolveStr="--resolve $domain:443:{{subnet_prefix}}.198"
set -x
curl $caStr $resolveStr --fail --connect-timeout 3 --retry 0 https://$domain/myhello/
set +x
{% else %}
echo "No primary TCP LB deployed"
{% endif %}

echo ""


echo "========== PRIMARY HTTPS LB ===================="
{% if https_lb_primary %}
ingress_name="{{ https_lb_primary_container_native_routing | ternary('cnr-my-ingress','my-ingress') }}"
# have to lookup public IP because it is ephemeral
publicIP=$(kubectl get ingress -n default $ingress_name -o=jsonpath="{.status.loadBalancer.ingress[0].ip}")
[ -n "$publicIP" ] || { echo "ERROR could not find public IP for ingress object"; exit 3; }

domain=my-primary.{{cluster_name}}.local
resolveStr="--resolve $domain:443:$publicIP"
# Host header not required, HTTPS LB uses SNI
#curl --header "Host: $domain" $caStr $resolveStr https://$domain/myhello/
set -x
curl $caStr $resolveStr --fail --connect-timeout 3 --retry 0 https://$domain/myhello/
{% else %}
echo "No primary HTTPS LB deployed"
{% endif %}
