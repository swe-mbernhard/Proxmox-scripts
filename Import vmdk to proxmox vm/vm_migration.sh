#!/usr/bin/bash
starttime=$(date)
echo $starttime
dryrun=0
while getopts d flag
do
    case "${flag}" in
    d) dryrun=1
    esac
done
## Set this to shared folder with access from esxi and proxmox
vmpath_default="/mnt/pve/sharedfolder"

if [ $dryrun -eq 1 ]
then
echo "DRYRUN - no changes will be committed"
fi
echo "Shut down the ESX VM you would like to migrate."
echo "Make sure there is a good backup for rollback to VMware"
echo "The ESX name CANNOT contain spaces, parenthesis, quotationmarks ec."

echo -e "Which operating system? (Default windows with SATA controller)\n\n  1. Windows 11/2022\n  2. Microsoft Windows 2008\n  3. Microsoft Windows 8/2012/2012r2\n  4. Microsoft Windows 10/2016/2019\n  5. Linux 2.6-6x kernel\n  6. Other\n"
read osinput
if [ $osinput == '1' ]
then
ostypename="Microsoft Windows 11/2022"
ostypevar="win11"
elif [ $osinput == '2' ]
then
ostypename="Microsoft Windows 2008"
ostypevar="w2k8"
elif [ $osinput == '3' ]
then
ostypename="Microsoft Windows 8/2012/2012r2"
ostypevar="win8"
elif [ $osinput == '4' ]
then
ostypename="Microsoft Windows 10/2016/2019"
ostypevar="win10"
elif [ $osinput == '5' ]
then
ostypename="Linux 2.6-6x"
ostypevar="126"
elif [ $osinput == '6' ]
then
ostypename="Annat"
else
osinput='1'
echo "Default Windows 11/2022"
ostypevar="win11"
ostypename="Windows 11/2022"
fi
#ostypevar="ostype: $ostypevar"

##Q for name
read -p "What is the VM name in ESX?  " vmname
echo "Namn: $vmname"



#pmcreatevmname="${vmname// /-}"
#vmname="${vmname// /\ }"
## Q for RAM:

read -p "How many GB RAM?  " RAM
RAMMB=$(($RAM*1024))
echo "$RAM GB of RAM, $RAMMB MB"

## Q for vcpu:

read -p "How many vcpu?  " vcpu
echo "$vcpu vcpus"

## Q for VLAN

read -p "Which vlan number?  " vlan
echo "VLAN $vlan"


## Q for vmware path:
echo -e "Which vmware path? ($vmpath_default)"
read vmpath
if [ "$vmpath" = "" ]; then
vmpath=$vmpath_default
else
echo "$vmpath"
fi



nextid=$(pvesh get /cluster/nextid)

echo -e "Creating VM $vmname with $RAM GB RAM, $vcpu vcpus, VLAN $vlan and ID $nextid $ostypevar.\nSource vmdk disks in $vmpath/$vmname/ will be moved to $vmpath/images/$nextid/"
echo -e "\nAre you sure you want to proceed?"
while true; do

read -p "Procees? (y/n) " yn

case $yn in
        [yY] ) echo OK, continuing;
            break;;
        [nN] ) endtime=$(date)
        echo $endtime
            echo Aborting...;
                exit;;
        * ) echo Wrong input;;
esac

done



#echo "qm create $nextid --cores $vcpu --sockets 1 --cpu cputype=host --memory $RAMMB --name "$vmname" --ostype $ostypevar --bios seabios"
echo "Creating VM $nextid with name $vmname. $RAMMB MB RAM, $vcpu vcpu, $ostypevar..."
if [ $dryrun -eq 0 ] ; then
qm create $nextid --cores $vcpu --sockets 1 --cpu cputype=x86-64-v3 --memory $RAMMB --name $vmname --ostype $ostypevar --bios seabios
else
echo "Dryrun."
fi

sleep 5
echo "Adding nic 0 in bridge vmbr1 with VLAN $vlan to vm $nextid"
if [ $dryrun -eq 0 ] ; then
qm set $nextid -net0 virtio,bridge=vmbr1,tag=$vlan
else
echo "Dryrun."
fi

sleep 5
echo "Creating VM diskfolder $vmpath/images/$nextid..."
if [ $dryrun -eq 0 ] ; then
mkdir $vmpath/images/$nextid
else
echo "Dryrun."
fi

sleep 5
echo "Moving vmdk from $vmpath/$vmname/ to $vmpath/images/$nextid/..."
if [ $dryrun -eq 0 ] ; then
find "$vmpath/$vmname/" -name "*.vmdk" -exec mv '{}' $vmpath/images/$nextid/ \;
else
echo "Dryrun."
fi

sleep 5
echo "Scanning VM $nextid for new disks ..."
if [ $dryrun -eq 0 ] ; then
qm disk rescan --vmid $nextid
else
echo "Dryrun."
fi

sleep 5
echo "Adding options to vm config"
if [ $dryrun -eq 0 ] ; then
echo "Modifying vm config"
sed -i 's/scsi0:/sata0:/' /etc/pve/qemu-server/$nextid.conf
echo 'scsihw: virtio-scsi-pci' >>/etc/pve/qemu-server/$nextid.conf
echo 'boot: order=sata0' >>/etc/pve/qemu-server/$nextid.conf
## Uncomment below and add your datastore in order to mount the ISO with virtio guest tools and drivers
##echo 'ide2: <datastore>:iso/virtio-win-0.1.240.iso,media=cdrom,size=612812K' >>/etc/pve/qemu-server/$nextid.conf
else
echo "Dryrun."
fi
echo "Install virtio drivers och tools to install the scsi driver, and change the disks to virtio scsi."

endtime=$(date)
echo $endtime
