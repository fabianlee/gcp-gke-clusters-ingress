#!/bin/bash
#
# Deploy ASM gateways managed independently of asmcli (now preferred method)
# Creates two different Gateways for traffic: one for 'public' apps, the other for 'internal'
#
# Deploys 'public' endpoint at /myhello
# Deploys 'internal' endpoint at /myint
#

function wait_for_k8s_service() {
  ns="$1"
  service_name="$2"
  timeout_sec="${3:-15}"

  counter=1
  while [[ ($counter -le $timeout_sec) && -z $(kubectl get service -n $ns $service_name -o jsonpath="{.status.loadBalancer.ingress}" 2>/dev/null) ]]; do
    echo "$counter) still waiting for $ns/$service_name to get ingress"
    sleep 1
    ((counter++))
  done

  if [[ $counter -ge $timeout_sec ]]; then
    echo "PROBLEM reached timeout for service $ns/$service_name"
  else
    echo "$ns/$service_name now has ingress"
 fi
}


###### MAIN #######################3

asm_rev_label_from_ns=$(kubectl get ns default -o=jsonpath="{.metadata.labels}" | jq -r ". | .\"istio.io/rev\"")
[ $asm_rev_label_from_ns = "null" ] && asm_rev_label_from_ns=""
[ -n "$asm_rev_label_from_ns" ] || { echo "ERROR need rev label from default ns, was empty"; exit 3; }
echo "asm_rev_label_from_ns = $asm_rev_label_from_ns"

ns=asm-gateways
kubectl create ns $ns

# set revision label for asm gateway namespace to same as 'default'
kubectl label namespace $ns istio-injection- istio.io/rev=$asm_rev_label_from_ns --overwrite
kubectl get ns $ns --show-labels

# separately mangage gateways is now the preferred ASM method
# putting into 'default' namespace because it has the 'istio.io/rev' and we are using 'auto' for image injection
kubectl apply -f istio-ingressgateway/ -n $ns
echo "going to wait for deployment to be Available..."
kubectl wait deployment -n $ns istio-ingressgateway --for condition=Available=True --timeout=90s

# deployment and service for public access
kubectl apply -f golang-hello-world-web.yaml -n default
kubectl wait deployment -n default golang-hello-world-web --for condition=Available=True --timeout=90s
kubectl apply -f golang-hello-world-gateway-virtservice.yaml -n default

exit 0

# there are no annotations on Service or operator control ingress that can properly have GCP LB auto created
# https://github.com/istio/istio/issues/1024
#
# also check into 'purpose' flag to make sure sure internal LB can use 
# gcloud compute addresses create my-internal-lb --region europe-west3 --addresses 10.223.0.192 --subnet <subnet_name> --purpose SHARED_LOADBALANCER_VIP
#
gcloud compute addresses create istio-ingressgateway-regional --project=$projectId --region=$region
static_ip=$(gcloud compute addresses describe istio-ingressgateway-regional --region=$region --format="value(address)")
[ -n "$static_ip" ] || { echo "ERROR did not find static IP 'istio-ingressgateway-regional'"; exit 5; }
kubectl patch service istio-ingressgateway --patch '{"spec":{"loadBalancerIP": "$static_ip"}}' --namespace $ns
exit 0


# deployment and service for internal access
kubectl apply -f golang-hello-world-web-int.yaml -n $ns
# ASM dataplane gateway and virtualservice
kubectl apply -f golang-hello-world-int-gateway-virtservice.yaml -n $ns
