# openstack-scripts
Scripts to configure demo/dev projects in a deployed OpenStack system

## Usage
I run these scripts after deploying a clean OpenStack environment (usually with devstack). They currently generate a working demo/test project for:
* simple_vms.sh: CirrOS VMs with a poor man's webserver
* simple_lb.sh: load balancer with LBaaS v2 API (for Octavia development), to use after simple_vms.sh
* simple_sfc_vms.sh: networking-sfc demo

## Customization
Customizable parts are regrouped in the fsourced script custom.sh. You will most likely want to customize the SSH key parts
