# Private GKE clusters using Terraform, Anthos Service Mesh with public/private endpoints

This project creates private GKE clusters (worker nodes have private IP addresses) in four different configurations:

* Private standard GKE cluster with public endpoint
* Private Autopilot GKE cluster with public endpoint
* Private standard GKE cluster with private endpoint
* Private Autopilot GKE cluster with private endpoint

After the clusters are built, the scripts deploy [Anthos Service Mesh](https://cloud.google.com/service-mesh/v1.11/docs/unified-install/quickstart-asm) with independent [Ingress Gateway](https://cloud.google.com/service-mesh/docs/gateways).

There are two entry points configured to ASM:
* A public HTTPS LB Ingress that exposes services to the world (your public customers)
* A private TCP LB that exposes services only to internal consumers (internal management tools)

## Network and Cluster summary table

 | STD gke w/pub endpoint | AP w/pub endpoint | STD gke w/private endpoint | AP w/private endpoint
--|--|--|--|--
subnet | pub-10-0-90-0 | pub-10-0-91-0 | prv-10-0-100-0 | prv-10-0-101-0
CIDR | 10.0.90.0/24 | 10.0.91.0/24 | 10.0.100.0/24 | 10.0.101.0/24
jumpbox | vm-pub-10-0-90-0 | vm-pub-10-0-91-0 | vm-prv-10-0-100-0 | vm-prv-10-0-101-0
cluster | std-pub-10-0-90-0 | ap-pub-10-0-91-0 | std-prv-10-0-100-0 | ap-prv-10-0-101-0
services| 10.128.0.0/19 | 10.128.0.32/19 | 10.128.0.64.0/19 | 10.128.0.96.0/19
pods | 10.126.0.0/17 | 10.126.128.0/17| 10.127.0.0/17 | 10.127.128.0.17
master | 10.1.0.0/28 | 10.1.0.16/28 | 10.1.0.32/28 | 10.1.0.48/28


## Private standard GKE cluster with public endpoint

A standard private GKE cluster, that offers a public endpoint for kubeapi.  But you also have the ability to ssh into the jumpbox in the same subnet via its external IP address and run kubectl commands against the cluster.

```
subnet:    pub-10-0-90-0
jumpbox:   vm-pub-10-0-90-0
cluster:   std-pub-10-0-90-0
GKE nodes: 10.0.90.0/24
services:  10.128.0.0/19
pods:      10.126.0.0/17
master:    10.1.0.0/28


            +-------------------------------------+             
            | 10.0.90.0/24                        |             
            |                                     |             
            |                 +----------------+  |             
            |                 |  std cluster   |  |             
 public     | +--------+      |  worker nodes  |  |             
 IP         | |jumpbox |      |                |------------->  
 ---------------->     |      |                |  |  master     
            | |        |      |                |  |  10.1.0.0/28
            | +--------+      +----------------+  |             
            |             services: 10.128.0.0/19 |             
            |             pods:     10.126.0.0/17 |             
            +-------------------------------------+             
```

## Private Autopilot cluster with public endpoint

An Autopilot private GKE cluster, that offers a public endpoint for kubeapi.  But you also have the ability to ssh into the jumpbox in the same subnet via its external IP address and run kubectl commands against the cluster.

```
subnet:    pub-10-0-91-0
jumpbox:   vm-pub-10-0-91-0
cluster:   ap-pub-10-0-91-0
GKE nodes: 10.0.91.0/24
services:  10.128.32.0/19
pods:      10.126.128.0/17
master:    10.1.0.16/28


            +-------------------------------------+             
            | 10.0.91.0/24                        |             
            |                                     |             
            |                 +----------------+  |             
            |                 |  ap cluster    |  |             
 public     | +--------+      |  worker nodes  |  |             
 IP         | |jumpbox |      |                |------------->  
 ---------------->     |      |                |  |  master     
            | |        |      |                |  |  10.1.16.0/28
            | +--------+      +----------------+  |             
            |           services: 10.128.32.0/19  |             
            |           pods:     10.126.128.0/17 |             
            +-------------------------------------+             
```

## Private standard GKE cluster with private endpoint

A standard private GKE cluster, that only offers a private endpoint for kubeapi.  That means you can only run kubectl from either:
* the private jumpbox in the same subnet (reached via the public bastion/jumpbox in 10.0.90.0)
* OR directly from the bastion/jumpbox on 10.0.90.0 because it has been added as a [master authorized network](https://cloud.google.com/kubernetes-engine/docs/how-to/authorized-networks)

```
subnet:    prv-10-0-100-0
jumpbox:   vm-prv-10-0-90-0
cluster:   std-prv-10-0-100-0
GKE nodes: 10.0.100.0/24
services:  10.128.64.0/19
pods:      10.127.0.0/17
master:    10.1.0.32/28


 Public        +--------------+                          
 IP            | bastion/jump |   authorized network 
 ------------->| 10.0.90.x/32 |------------------------
               |              |                       |
               +--------------+                       | 
                   |                                  | 
                   |                                  | 
            +-------------------------------------+   |          
            | 10.0.100.0/24                       |   |          
            |      |                              |   |          
            |      |          +----------------+  |   |          
            |      v          |  std cluster   |  |   |
            | +--------+      |  worker nodes  |  |   ------->          
            | |jumpbox |      |                |------------->  
            | |        |                       |  |  master     
            | |        |      |                |  |  10.1.32.0/28
            | +--------+      +----------------+  |             
            |           services: 10.128.64.0/19  |             
            |           pods:     10.127.0.0/17   |             
            +-------------------------------------+             
```

## Private Autopilot cluster with private endpoint

An Autopilot private GKE cluster, that only offers a private endpoint for kubeapi.  That means you can only run kubectl from either:
* the private jumpbox in the same subnet (reached via the public bastion/jumpbox in 10.0.91.0)
* OR directly from the bastion/jumpbox on 10.0.91.0 because it has been added as a [master authorized network](https://cloud.google.com/kubernetes-engine/docs/how-to/authorized-networks)

```
subnet:    prv-10-0-101-0
jumpbox:   vm-prv-10-0-101-0
cluster:   ap-prv-10-0-101-0
GKE nodes: 10.0.101.0/24
services:  10.128.96.0/19
pods:      10.127.128.0/17
master:    10.1.0.48/28


 Public        +--------------+                          
 IP            | bastion/jump |   authorized network 
 ------------->| 10.0.91.x/32 |------------------------
               |              |                       |
               +--------------+                       | 
                   |                                  | 
                   |                                  | 
            +-------------------------------------+   |          
            | 10.0.101.0/24                       |   |          
            |      |                              |   |          
            |      |          +----------------+  |   |          
            |      v          |  ap cluster    |  |   |
            | +--------+      |  worker nodes  |  |   ------->          
            | |jumpbox |      |                |------------->  
            | |        |                       |  |  master     
            | |        |      |                |  |  10.1.48.0/28
            | +--------+      +----------------+  |             
            |           services: 10.128.96.0/19  |             
            |           pods:     10.127.128.0/17 |             
            +-------------------------------------+             
```

# Anthos Service Mesh

Because these are all private GKE cluster with internal IP addresses, we use Anthos Service Mesh to expose the services we want to offer publicly to end users as well as internal-only management web services.


## Anthos Service Mesh on Standard GKE

On the standard GKE Clusters, we deploy two istio ingress gateway services. One delivers for the services meant to be served over the public internet, and the other delivers the services meant for private consumption only (e.g. management UI only accessible to employees).

The VirtualService project unto the desired Gateway, and the Gateway use a selector to their desired istio IngressGateway service. 

```
                    +-------------------------------------------------------------------------------+
           creates  |   +---------------+                                     creates               |
            +-----------| Ingress       |                                 |------------------+      |
            |       |   +---------------+                                 |                  |      |
            v       |                                                     |                  v      |
Public  +--------+  |              PUBLIC SERVICES             PRIVATE SERVICES         +--------+  |
Users   | HTTPS  |  | NEG        +------------------+        +------------------+       | TCP    |  |
------->| LB     |-------------->| istio            |        | istio            |       | LB     |  |
        |        |  |            | ingressgateway   |        | ingressgateway   |       |        |  |
        +--------+  |            +------------------+        +------------------+       +--------+  |
                    |            +------------------+        +------------------+           ^       |
                    |            | Gateway          |        | Gateway          |           |       |
                    |            +------------------+        +------------------+           |       |
                    |            +------------------+        +------------------+           |       |
                    |            | VirtualService(s)|        | VirtualService(s)|           |       |
                    |            +------------------+        +------------------+        Internal   |
                    |            +------------------+        +------------------+        Users      |
                    |            | Service(s)       |        | Service(s)       |                   |
                    |            +------------------+        +------------------+                   |
                    |                                                                               |
                    +-------------------------------------------------------------------------------+
```


## Anthos Service Mesh on Autopilot GKE

On the Autopilot GKE Clusters, we only deploy istio ingress gateway services for internal, private services. This follows the same path as above; the VirtualService project unto the desired Gateway, and the Gateway use a selector to their desired istio IngressGateway service. 

But for the Public End user services, instead of using VirtualService and Gateway to select an istio IngressGateway, we define a [URL map](https://cloud.google.com/load-balancing/docs/url-map-concepts) directly on the Ingress object so that it not only creates the GCP HTTPS LB, but tells the LB how to reach our public services directly via Network Endpoint Group NEG.

This does require that we add a BackendConfig to each service so that a health check can be done by the HTTPS LB.


```
                    +-------------------------------------------------------------------------------+
           creates  |   +---------------+                                     creates               |
            +-----------| Ingress       |                                 |------------------+      |
            |       |   +---------------+                                 |                  |      |
            v       |                                                     |                  v      |
Public  +--------+  |              PUBLIC SERVICES             PRIVATE SERVICES         +--------+  |
Users   | HTTPS  |  | NEG        +------------------+        +------------------+       | TCP    |  |
------->| LB     |-------------->| Service          |        | istio            |       | LB     |  |
        |        -------+        +------------------+        | ingressgateway   |       |        |  |
        +--------+  |   |        +------------------+        +------------------+       +--------+  |
              |     |   ---------| Service          |        +------------------+           ^       |
              |     |            +------------------+        | Gateway          |           |       |
              |     |            +------------------+        +------------------+           |       |
        MAP   -------------------| Service          |        +------------------+           |       |
        /path1 svc1 |            +------------------+        | VirtualService(s)|           |       |
        /path2 svc2 |                                        +------------------+        Internal   |
        /path3 svc3 |                                        +------------------+        Users      |
                    |                                        | Service(s)       |                   |
                    |                                        +------------------+                   |
                    |                                                                               |
                    +-------------------------------------------------------------------------------+
```



# Building the clusters

## Binary Prerequisites

* [gcloud 370+](https://cloud.google.com/sdk/docs/install)
* [kubectl 1.21+](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/)
* [terraform 14+](https://fabianlee.org/2021/05/30/terraform-installing-terraform-manually-on-ubuntu/)
* [ansible 2.10+](https://fabianlee.org/2021/05/31/ansible-installing-the-latest-ansible-on-ubuntu/)
* [yq 4.x+](https://github.com/mikefarah/yq/releases)
* jq 1.5+ (sudo apt install jq)
* make 4.x+ (sudo apt install make)

## Account Prerequisites

* Login to the GCP Web UI [cloud console](https://console.cloud.google.com) with your Google Id
* Enable billing for the GCP project. Hamburger menu > Billing
* Establish login context to GCP from console
  * gcloud init
  * gcloud auth login

## Start Build from console

* git clone https://github.com/fabianlee/gcp-gke-clusters-ingress.git
* cd gcp-gke-clusters-ingres
* ./generate_random_project_id.sh
* ./menu.sh

## Menu driven build

From here forward, you can use the menu driven wizard to execute the major actions required. It will generally look like below, and you should start at the top and work your way down through the components and ultimately the GKE cluster types you want to build.

Don't forget to delete the objects you create, Google will charge you for this infrastructure.

```
===========================================================================
 MAIN MENU
===========================================================================

project          Create gcp project and enable services
svcaccount       Create service account for provisioning
networks         Create network, subnets, and firewall
cloudnat         Create Cloud NAT for public egress of private IP

sshmetadata      Load ssh key into project metadata
vms              Create VM instances in subnets
enablessh        Setup ssh config for bastions and ansible inventory
ssh              SSH into jumpbox

ansibleping      Test ansible connection to public and private vms
ansibleplay      Apply ansible playbook of minimal pkgs/utils for vms

gke              Create private GKE cluster w/public endpoint
autopilot        Create private Autopilot cluster w/public endpoint
privgke          Create private GKE cluster w/private endpoint
privautopilot    Create private Autopilot cluster w/private endpoint

kubeconfigcopy   Copy kubeconfig to jumpboxes
svcaccountcopy   Copy service account json key to jumpboxes

kubeconfig       Select KUBECONFIG
k8s-register     Register with hub and get fleet identity
k8s-scale        Apply balloon pod to warm up cluster
k8s-tinytools    Apply tiny-tools Daemonset to cluster
k8s-ASM          Install ASM on cluster
k8s-certs        Create and load TLS certificates
k8s-lb-tcp       Deploy Ingress Gateway for private TCP LB
k8s-lb-https     Deploy Ingress for public HTTPS LB
k8s-helloapp     Install hello apps
k8s-curl         Run curl to test public and private hello endpoints

delgke           Delete GKE public standard cluster
delautopilot     Delete GKE public Autopilot cluster
delprivgke       Delete GKE private standard cluster
delprivautopilot Delete GKE private Autopilot cluster
delvms           Delete VM instances
delnetwork       Delete networks and Cloud NAT
```


[diagrams created on texttik.com](https://textik.com/)

