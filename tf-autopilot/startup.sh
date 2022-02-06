#!/bin/bash

echo this is from startup.sh | sudo tee /tmp/startup.log
curl -sf -H 'Metadata-Flavor:Google' http://metadata/computeMetadata/v1/instance/network-interfaces/0/ip | sudo tee -a  /tmp/startup.log
