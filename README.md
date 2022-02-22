# Creates private GKE standard and Autopilot clusters

This project creates *private* GKE clusters in four different configurations:

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
