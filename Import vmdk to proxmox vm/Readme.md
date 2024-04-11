## VM creation and import of vmdk files into proxmox.

This script creates a VM based on the answer of a few questions. 

When VM is created, some options are set, the vmdk files are MOVED from vmware datastore filestructure into proxmox vm filestructure, then the proxmox vm is scanned for disks

Set the variable vmpath_default to the proxmox path of the shared folder.

Change the vmbridge in the qm create command if another vm bridge is used.

Prereqs:
Shared folder between vmware and proxmox - i use NFS for this. 

Dedicated hardware for proxmox in order to convert file to qcow2. 

Virtio tools installed in source VM, and vmware tools uninstalled.

IP config for the source VM

Local admin account for the source VM
