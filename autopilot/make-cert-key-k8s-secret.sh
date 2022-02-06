#!/bin/bash

domain="gke.fabianlee.online"

# create key and cert
if [ ! -f $domain.key ]; then
  # error from Ingress if key is 4096, Error 400: The SSL key is too large., sslCertificate KeyTooLarge
  openssl req -new -newkey rsa:2048 -days 365 -nodes -x509 -subj "/CN=$domain" -keyout $domain.key -out $domain.crt
fi

# load key into secret (gateway is in default ns, ingress is in asm-gateways ns)
for ns in default asm-gateways; do 
  kubectl -n $ns create secret tls my-tls-credential --key=$domain.key --cert=$domain.crt
done

# pulling from TLS with curl requires providing self-signed cert as CA
#domain=gke.fabianlee.online
#IP=34.107.178.3
#resolveStr="--resolve $domain:443:$IP"
#curl $resolveStr https://$domain/myhello/ --cacert $domain.crt


