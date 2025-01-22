#!/usr/bin/bash
starttime=$(date)
echo $starttime
GREEN=$(tput setaf 2)
RED=$(tput setaf 1)
NC=$(tput setaf 7)
YELLOW=$(tput setaf 3)
########## change this to your datastore!
dspath="/mnt/pve/<datastorename>"
########################################
dryrun=0
while getopts d flag
do
    case "${flag}" in
    d) dryrun=1
    esac
done

if [ $dryrun -eq 1 ]
then
echo "DRYRUN - no changes will be committed"
fi
echo "Turn off the VM to be migrated."
echo "Make sure theres a wroking backup for rollback to vmware"
echo "The vmware name cannot contain space, parenthesis, quotation marks etc. Proxmox naming rules apply."


echo -e "Which OS is the virtual machine? (Default: windows with SATA controller)\n\n  1. Windows 11/2022\n  2. Microsoft Windows 2008\n  3. Microsoft Windows 8/2012/2012r2\n  4. Microsoft Windows 10/2016/2019\n  5. Linux 2.6-6x kernel\n  6. Other\n"
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
ostypevar="l26"
elif [ $osinput == '6' ]
then
ostypename="Others"
else
osinput='1'
echo "Default Windows 11/2022"
ostypevar="win11"
ostypename="Windows 11/2022"
fi
#ostypevar="ostype: $ostypevar"

##Ask which VM
read -p "Name of the VM to be moved?  " vmname
echo "Namn: $vmname"
pmvmname="$vmname"


# Ask about VLAN

read -p "Which vlan?  " vlan
echo "VLAN $vlan"

read -p "Which IP address?  " ip
echo "IP address: $ip"

read -p "Which subnetmask (default: 255.255.255.0)?  " netmask
if [ "$netmask" == "" ]; then
netmask="255.255.255.0"
fi
echo "Netmask: $netmask"

read -p "Which default gateway?  " gateway
echo "Default gateway: $gateway"

read -p "Primary DNS?  " pridns
echo "Primary DNS: $pridns"

read -p "Secondary DNS?  " secdns
echo "Secondary DNS: $secdns"

#pmcreatevmname="${vmname// /-}"
#vmname="${vmname// /\ }"
## Ask for RAM:

read -p "How many GB RAM?  " RAM
RAMMB=$(($RAM*1024))
echo "$RAM GB of RAM, $RAMMB MB"

## Fråga om vcpu:

read -p "How many vcpus?  " vcpu
echo "$vcpu vcpus"


echo "$vmpath"



nextid=$(pvesh get /cluster/nextid)

esxpath="$dspath/$vmname"
pvepath="$dspath/$nextid"


echo -e "Creating VM $vmname with $RAM GB RAM and $vcpu vcpus and ID $nextid $ostypevar.\nSource disk $vmpath will be MOVED to $dspath/images/$nextid/"
echo -e "VLAN: $vlan"
echo -e "IP address: $ip"
echo -e "Netmask: $netmask"
echo -e "Default gateway: $gateway"
echo -e "DNS: $pridns $secdns"
echo -e "NB: the source file will be moved within the datastore.\n\nAre you sure?"
while true; do

read -p "Do you want to continue? (j/n) " yn

case $yn in
        [jJ] ) echo OK, lets go;
                break;;
        [nN] ) endtime=$(date)
        echo $endtime
            echo exiting...;
                exit;;
        * ) echo Invalid choice;;
esac

done



echo "Creating VM $nextid by name $pmvmname, $RAM GB RAM and $vcpu cpu. OS: $ostypevar..."
qm create $nextid --cores $vcpu --sockets 1 --cpu cputype=x86-64-v3 --memory $RAMMB --name $pmvmname --ostype $ostypevar --bios seabios --machine pc-i440fx-8.1
sleep 5
echo "Adding Virtio-nätverskort with vlan $vlan to vm $nextid..."
qm set $nextid -net0 virtio,bridge=vmbr1,tag=$vlan
sleep 5
echo "Creating VM diskfolder i $dspath/images/$nextid/..."
mkdir $dspath/images/$nextid
sleep 5
echo "Moving vmdks from $dspath/$vmname to $dspath/images/$nextid/..."
echo "${YELLOW}För att flytta tillbaka filerna och starta i VmWare igen, kör kommandot mv $dspath/images/$nextid/*.vmdk $dspath/$vmname/${NC}"
echo "${YELLOW}To move the files back to the vmware path, run mv $dspath/images/$nextid/*.vmdk $dspath/$vmname/${NC}"

find "$dspath/$vmname/" -name "*.vmdk" -exec mv '{}' $dspath/images/$nextid/ \;

sleep 5
echo "Undersöker VM mapp $dspath/images/$nextid/ efter diskar..."
qm disk rescan --vmid $nextid

sleep 5
echo "Adding disks to VM"
VMDK_DIR=$dspath/images/$nextid
# Initialize SATA index
sata_index=0

# Loop through all VMDK files
for vmdk_file in "$VMDK_DIR"/*.vmdk; do
    # Check if the file ends with "flat.vmdk" or "ctk.vmdk"
    if [[ "$vmdk_file" =~ (flat|ctk)\.vmdk$ ]]; then
        continue  # Skip these files
    fi

    # Determine SATA index based on filename
    if [[ "$vmdk_file" =~ _([0-9]+)\.vmdk$ ]]; then
        sata_index="${BASH_REMATCH[1]}"
    else
        sata_index=0
    fi

    echo "Adding disks, OBS: the order is a guess, based on the vmdk files number"
    qm set $nextid -sata$((sata_index)) $vmdk_file
done


sed -i 's/scsi0:/sata0:/' /etc/pve/qemu-server/$nextid.conf
echo 'boot: order=sata0' >>/etc/pve/qemu-server/$nextid.conf

echo 'ide2: none,media=cdrom' >>/etc/pve/qemu-server/$nextid.conf
echo 'scsihw: virtio-scsi-pci' >>/etc/pve/qemu-server/$nextid.conf
echo 'agent: 1' >>/etc/pve/qemu-server/$nextid.conf

echo "Setting VM options, and starting. Wait for the script to set network information automatically, or cancel the script to log in and set IP manually."
echo "For setting IP successfully, qemu tools is required in the VM."
sleep 5
echo "Trying to boot VM"
output_count=0
qm start $nextid


# Loop until we get 3 successful outputs
while [ "$output_count" -lt 3 ]; do
    # Run the command and redirect output to /dev/null
    qm guest cmd "$nextid" ping &>/dev/null

    # Check the exit status of the command
    if [ $? -eq 0 ]; then
        # Increment the output count
        ((output_count++))
echo "Qemu agent running, test $output_count of 3!"
    else
        # Reset the count if the command fails
echo "Qemu agent not running yet."
        output_count=0
    fi

    # Wait for 3 seconds before the next iteration
    sleep 3
done
echo "Searcing for NICs"
out_data=$(qm guest exec $nextid netsh interface show interface | jq -r '.["out-data"]')
interface_name=$(echo -e "$out_data" | awk '/Dedicated/ {print substr($0, index($0, "Dedicated") + length("Dedicated") + 1)}')

# Remove all \r characters and trim leading/trailing whitespace and newlines
interface_name=$(echo "$interface_name" | tr -d '\r' | sed 's/^[ \t]*//;s/[ \t]*$//;s/\n*$//')
export interface_name_env="$interface_name"
echo "${YELLOW}Found NIC $interface_name ${NC}"

echo "Trying to set IP!"

echo "Setting IP on $nextid to $ip $netmask $gateway"
json_output=$(qm guest exec $nextid netsh interface ipv4 set address name="$interface_name" static $ip $netmask $gateway)

exitcode=$(echo "$json_output" | jq -r '.exitcode')

# Check if exit code is 0
if [ "$exitcode" -eq 0 ]; then
    ipresult="${YELLOW}Successfully set IP $ip $netmask $gateway on $interface_name${NC}"
else
    ipresult="${RED}Failed to set IP $ip $netmask $gateway. Run the following manually to retry:\nqm guest exec $nextid netsh interface ipv4 set address name=\"$interface_name\" static $ip $netmask $gateway ${NC}"

fi
echo -e "Result: $ipresult"
until qm guest cmd $nextid ping &>/dev/null
do
echo "Qemu agent not running yet."
sleep 2
done

echo "Setting DNS to $pridns."
json_output=$(qm guest exec $nextid netsh interface ipv4 set dnsservers name="$interface_name" static $pridns primary no)
exitcode=$(echo "$json_output" | jq -r '.exitcode')

# Check if exit code is 0
if [ "$exitcode" -eq 0 ]; then
    dns1result="${YELLOW}Successfully set primary DNS to $pridns ${NC}"
else
    dns1result="${RED}Failed to set DNS 1 $pridns. Run the following manually to retry: \nqm guest exec $nextid netsh interface ipv4 set dnsservers name=\"$interface_name\" static $pridns primary no ${NC}"
fi
echo -e "Result: $dns1result"
until qm guest cmd $nextid ping &>/dev/null
do
echo "Qemu agent not running yet."
sleep 2
done
if [ "$secdns" = "" ]; then
echo "Sec DNS not provided"
else
echo "Setting secondary DNS to $secdns"
json_output=$(qm guest exec $nextid netsh interface ipv4 add dnsservers name="$interface_name" address=$secdns index=2 no)
exitcode=$(echo "$json_output" | jq -r '.exitcode')

# Check if exit code is 0
if [ "$exitcode" -eq 0 ]; then
    dns2result="Successfully set DNS 2 $secdns"
else
    dns2result="${RED}Failed to set DNS 2 $secdns. Run the following manually to retry:\nqm guest exec $nextid netsh interface ipv4 add dnsservers name=\"$interface_name\" address=$secdns index=2 no ${NC}"
fi
echo -e "Result: $dns2result"
fi
endtime=$(date)
echo $endtime
#echo -e "IP address summary:\n"
#echo -e "IP: $ipresult\nDNS1: $dns1result\nDNS2: $dns2result"

## Checking IP via qemu agent

echo -e "\nChecking IP on $interface_name"

agentip=$(qm agent $nextid network-get-interfaces | jq -r '.[] | select(.name == env.interface_name_env) | .["ip-addresses"][] | select(.["ip-address-type"] == "ipv4") | .["ip-address"]')
if [ "$agentip" = "$ip" ]; then
echo "${YELLOW}IP address is $ip - VM has the correct ip. ${NC}"
else
echo -e "${RED}\n$agentip != $ip\nRun the following manually to retry!\nqm guest exec $nextid netsh interface ipv4 set address name=\"$interface_name\" static $ip $netmask $gateway\n${NC}"

fi
echo "Checking DNS info of VM"
addressinfo=$(qm guest exec $nextid netsh interface ip show dnsservers name="$interface_name")
if [[ "$addressinfo" == *"$pridns"* ]]; then
    echo "${YELLOW}$pridns is DNS server - has the correct primary DNS${NC}"
else
    echo -e "${RED}Hittar inte primär DNS $pridns i VM:en. Run the following manually to retry!\nqm guest exec $nextid netsh interface ipv4 set dnsservers name=\"$interface_name\" static $pridns primary no ${NC}"

fi
if [[ "$addressinfo" == *"$secdns"* ]]; then
    echo "${YELLOW}$secdns is secondary DNS server - has the correct secondary DNS ${NC}"
else
    echo -e "${RED}Cannot find sekundär DNS $secdns in the VM. Run the following manually to retry!\nqm guest exec $nextid netsh interface ipv4 add dnsservers name=\"$interface_name\" address=$secdns index=2 no ${NC}"
fi
