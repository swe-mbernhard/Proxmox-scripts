## VM creation and import of vmdk files into proxmox.

This script creates a VM based on the answer of a few questions. 

When VM is created, some options are set, the vmdk files are MOVED from vmware datastore filestructure into proxmox vm filestructure, then the proxmox vm is scanned for disks

Prereqs:
Shared folder between vmware and proxmox - i use NFS for this. 
Dedicated hardware for proxmox in order to convert file to qcow2. 
