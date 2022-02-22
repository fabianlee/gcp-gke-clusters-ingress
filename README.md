# Creates private GKE standard and Autopilot clusters using Terraform

This project creates private GKE clusters (worker nodes have private IP addresses) in four different configurations:

* Private standard GKE cluster with public endpoint (10.0.90.0/24)
* Private Autopilot GKE cluster with public endpoint (10.0.91.0/24)
* Private standard GKE cluster with private endpoint (10.0.100.0/24)
* Private Autopilot GKE cluster with private endpoint (10.0.101.0/24)

## Private standard GKE cluster with public endpoint

```
subnet:    pub-10-0-90-0
jumpbox:   vm-pub-10-0-90-0
GKE nodes: 10.0.90.0/24
services:  10.128.0.0/19
pods:      10.126.0.0/17
master:    10.1.0.0/28
```

## Private Autopilot cluster with public endpoint

```
subnet:    pub-10-0-91-0
jumpbox:   vm-pub-10-0-91-0
GKE nodes: 10.0.91.0/24
services:  10.128.32.0/19
pods:      10.126.128.0/17
master:    10.1.0.16/28
```

## Private standard GKE cluster with private endpoint

```
subnet:    prv-10-0-100-0
jumpbox:   vm-prv-10-0-90-0
GKE nodes: 10.0.100.0/24
services:  10.128.64.0/19
pods:      10.127.0.0/17
master:    10.1.0.32/28
```

## Private Autopilot cluster with private endpoint

```
subnet:    prv-10-0-101-0
jumpbox:   vm-prv-10-0-101-0
GKE nodes: 10.0.101.0/24
services:  10.128.96.0/19
pods:      10.127.128.0/17
master:    10.1.0.48/28
```

# Building the clusters

## Binary Prerequisites

* [gcloud](https://cloud.google.com/sdk/docs/install)
* [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/)
* [terraform 14+](https://fabianlee.org/2021/05/30/terraform-installing-terraform-manually-on-ubuntu/)
* [ansible](https://fabianlee.org/2021/05/31/ansible-installing-the-latest-ansible-on-ubuntu/)
* [yq](https://github.com/mikefarah/yq/releases)
* jq (sudo apt install jq)
* make (sudo apt install make)

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





