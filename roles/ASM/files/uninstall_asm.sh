#!/bin/bash
#
# https://cloud.google.com/service-mesh/docs/uninstall
#
# Usage: clsterType=autopilot|standard asmType=managed|incluster
#

cluster_type="${1:-autopilot}"
[[ "autopilot standard " =~ $cluster_type[[:space:]] ]] || { echo "ERROR only valid types are standard|autopilot"; exit 3; }

[ $cluster_type = "autopilot" ] && cluster_name="autopilot-cluster1" || cluster_name="cluster1"

asm_type="${2:-managed}"
[[ "managed incluster " =~ $asm_type[[:space:]] ]] || { echo "ERROR only valid types are managed|incluster"; exit 3; }


for ns in default asm-gateways; do
  kubectl label namespace $ns istio.io/rev-
  kubectl label namespace $ns istio-injection-
done

set -x

kubectl delete controlplanerevision -n istio-system --ignore-not-found=true

if [ "incluster" = $asm_type ]; then
  kubectl delete validatingwebhookconfiguration,mutatingwebhookconfiguration -l operator.istio.io/component=Pilot
elif [ "managed" = $asm_type ]; then
  kubectl delete validatingwebhookconfiguration istiod-istio-system-mcp
  kubectl delete mutatingwebhookconfiguration RELEASE_CHANNEL
fi

# restart any workloads that were injected
kubectl rollout restart deploy -n default

# do removal of ASM related objects
output-cluster1/istioctl x uninstall --purge

kubectl delete ns istio-system



