#!/bin/bash

# GCP project id is in both places
RAN=$((1+ RANDOM%100000))
echo "going to use unique GCP project id: $RAN"
sed -i "s/project_id=.*/project_id=my-gkeproj1-$RAN/" global.properties
sed -i "s/project_id:.*/project_id: my-gkeproj1-$RAN/" group_vars/all
sed -i "s/project\s?=*.*/project=\"my-gkeproj1-$RAN\"/" tf/envs/all.tfvars

echo "======== RESULTS ============"
grep ^project_id global.properties
grep ^project_id group_vars/all
grep ^project tf/envs/all.tfvars
