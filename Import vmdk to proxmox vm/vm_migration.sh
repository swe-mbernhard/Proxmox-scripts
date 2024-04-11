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
vmpath_default="/mnt/pve/<sharedfolder>"

if [ $dryrun -eq 1 ]
then
echo "DRYRUN - inget kommer att ändras"
fi
echo "Stäng av VM:en i ESX som du vill migrera."
echo "Se till att det finns backup för rollback till VMware"
echo "VM namnet i VMware kan INTE innehålla mellanslag eller paranteser, citationstecken osv."

echo -e "Vilket OS är den virtuella maskinen? (Default windows med SATA controller)\n\n  1. Windows 11/2022\n  2. Microsoft Windows 2008\n  3. Microsoft Windows 8/2012/2012r2\n  4. Microsoft Windows 10/2016/2019\n  5. Linux 2.6-6x kernel\n  6. Annat\n"
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


##Fråga om namn
read -p "Namn på VM som ska flyttas?  " vmname
echo "Namn: $vmname"


## Fråga om RAM:

read -p "Hur många GB RAM?  " RAM
RAMMB=$(($RAM*1024))
echo "$RAM GB of RAM, $RAMMB MB"

## Fråga om vcpu:

read -p "Hur många vcpu?  " vcpu
echo "$vcpu vcpus"

## Fråga om VLAN

read -p "Vilket kundvlan?  " vlan
echo "VLAN $vlan"


## Fråga om vmware path:
echo -e "Vilken vmware path? ($vmpath_default)"
read vmpath
if [ "$vmpath" = "" ]; then
vmpath=$vmpath_default
else
echo "$vmpath"
fi

nextid=$(pvesh get /cluster/nextid)

echo -e "Skapar VM $vmname med $RAM GB RAM, $vcpu vcpus, VLAN $vlan och ID $nextid $ostypevar.\nSource vmdk diskar i $vmpath/$vmname/ kommer att flyttas till $vmpath/images/$nextid/"
echo -e "\nÄr du helt säker på att du vill göra det?"
while true; do

read -p "Vill du fortsätta? (j/n) " yn

case $yn in
        [jJ] ) echo OK, fortsätter;
                break;;
        [nN] ) endtime=$(date)
        echo $endtime
            echo Avbryter...;
                exit;;
        * ) echo Felaktig inmatning;;
esac

done



echo "Skapar VM $nextid med namn $vmname. $RAMMB MB RAM, $vcpu vcpu, $ostypevar..."
if [ $dryrun -eq 0 ] ; then
qm create $nextid --cores $vcpu --sockets 1 --cpu cputype=x86-64-v3 --memory $RAMMB --name $vmname --ostype $ostypevar --bios seabios
else
echo "Dryrun."
fi

sleep 5
echo "Lägger till nätverkskort 0 i bridge vmbr1 med VLAN $vlan till vm $nextid"
if [ $dryrun -eq 0 ] ; then
qm set $nextid -net0 virtio,bridge=vmbr1,tag=$vlan
else
echo "Dryrun."
fi

sleep 5
echo "Skapar VM diskmapp $vmpath/images/$nextid..."
if [ $dryrun -eq 0 ] ; then
mkdir $vmpath/images/$nextid
else
echo "Dryrun."
fi

sleep 5
echo "Flyttar vmdk från $vmpath/$vmname/ till $vmpath/images/$nextid/..."
if [ $dryrun -eq 0 ] ; then
find "$vmpath/$vmname/" -name "*.vmdk" -exec mv '{}' $vmpath/images/$nextid/ \;
else
echo "Dryrun."
fi


sleep 5
echo "Scannar VM $nextid efter nya diskar ..."
if [ $dryrun -eq 0 ] ; then
qm disk rescan --vmid $nextid
else
echo "Dryrun."
fi

sleep 5
echo "Lägger till options i vm configen"
if [ $dryrun -eq 0 ] ; then
echo "Modifierar vm config filen"
sed -i 's/scsi0:/sata0:/' /etc/pve/qemu-server/$nextid.conf
echo 'scsihw: virtio-scsi-pci' >>/etc/pve/qemu-server/$nextid.conf
echo 'boot: order=sata0' >>/etc/pve/qemu-server/$nextid.conf
echo 'ide2: VTN-BE-01-SSD-PM:iso/virtio-win-0.1.240.iso,media=cdrom,size=612812K' >>/etc/pve/qemu-server/$nextid.conf
else
echo "Dryrun."
fi
echo "Installera virtio drivers och tools för att installera scsi drivern, och ändra sedan diskarna till scsi."

endtime=$(date)
echo $endtime
