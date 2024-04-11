THE SCRIPTS IN THIS REPOSITORY ARE PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND. You are responsible for ensuring that any scripts you execute does not contain malicious code, or does not cause unwanted changes to your environment. If you do not understand what the code does, do not blindly execute it! A script has access to the full power of the hypervisor environment. Do not execute a script from sources you do not trust.

With that said, I use it in a production environment.

NEVER RUN SCRIPTS WITH CODE YOU DON'T UNDERSTAND.

## VM creation and import of vmdk files into proxmox.

Copy this script to your proxmox host and make it executable by chmod +X

This script creates a VM based on the answer of a few questions. 

When VM is created, some options are set, the vmdk files are MOVED from vmware datastore filestructure into proxmox vm filestructure, then the proxmox vm is scanned for disks

Set the variable vmpath_default to the proxmox path of the shared folder.

Change the vmbridge in the qm create command if another vm bridge is used.

Prereqs:
Shared folder between vmware and proxmox - i use NFS for this. 

Dedicated storage for proxmox in order to convert file to qcow2. 

Virtio tools installed in source VM, and vmware tools uninstalled.

IP config documentation for the source VM

Local admin account for the source VM
