# Private GKE clusters using Terraform, Anthos Service Mesh with dual endpoints

This project creates private GKE clusters (worker nodes have private IP addresses) in four different configurations:

* Private standard GKE cluster with public endpoint (10.0.90.0/24)
* Private Autopilot GKE cluster with public endpoint (10.0.91.0/24)
* Private standard GKE cluster with private endpoint (10.0.100.0/24)
* Private Autopilot GKE cluster with private endpoint (10.0.101.0/24)

After the clusters are built, the scripts deploy [Anthos Service Mesh](https://cloud.google.com/service-mesh/v1.11/docs/unified-install/quickstart-asm) with independent [Ingress Gateway](https://cloud.google.com/service-mesh/docs/gateways).

There are two entry points configured to ASM:
* A public HTTPS LB Ingress that exposes services to the world (your public customers)
* A private TCP LB that exposes services only to internal consumers (internal management tools)


## Private standard GKE cluster with public endpoint

```
subnet:    pub-10-0-90-0
jumpbox:   vm-pub-10-0-90-0
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

```
subnet:    pub-10-0-91-0
jumpbox:   vm-pub-10-0-91-0
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

```
subnet:    prv-10-0-100-0
jumpbox:   vm-prv-10-0-90-0
GKE nodes: 10.0.100.0/24
services:  10.128.64.0/19
pods:      10.127.0.0/17
master:    10.1.0.32/28



 Public        +--------------+                          
 IP            | Bastion  VM  |   authorized network 
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

```
subnet:    prv-10-0-101-0
jumpbox:   vm-prv-10-0-101-0
GKE nodes: 10.0.101.0/24
services:  10.128.96.0/19
pods:      10.127.128.0/17
master:    10.1.0.48/28


 Public        +--------------+                          
 IP            | Bastion  VM  |   authorized network 
 ------------->| 10.0.91.x/32 |------------------------
               |              |                       |
               +--------------+                       | 
                   |                                  | 
                   |                                  | 
            +-------------------------------------+   |          
            | 10.0.101.0/24                       |   |          
            |      |                              |   |          
            |      |          +----------------+  |   |          
            |      v          |  std cluster   |  |   |
            | +--------+      |  worker nodes  |  |   ------->          
            | |jumpbox |      |                |------------->  
            | |        |                       |  |  master     
            | |        |      |                |  |  10.1.48.0/28
            | +--------+      +----------------+  |             
            |           services: 10.128.96.0/19  |             
            |           pods:     10.127.128.0/17 |             
            +-------------------------------------+             
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

kubeconfiggen    Use gcloud to retrieve any missing kubeconfig
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


[diagrams](https://textik.com/)

