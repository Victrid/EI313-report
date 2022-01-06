#!/bin/sh

# Hugepage Test Utility
# Copyright (C) 2021 Weihao Jiang

name="Hugepage Test Utility"

available_VM=( "Arch-hugepage-8519:default:192.168.122.84:nohp" "Arch-hugepage-3007:default:192.168.122.50:hp" )
# Get the lines and columns
LINES=$(tput lines)
COLUMNS=$(tput cols)

HEIGHT="$(($LINES - 10))"
WIDTH="$(($COLUMNS - 10))"
# Modification of boot entries

get_grub_entries () {
# From https://askubuntu.com/questions/599208

sudo gawk  'BEGIN {                                                                                                                       
  l=0                                                                                                                                
  menuindex= 0                                                                                                                       
  stack[t=0] = 0                                                                                                                     
}                                                                                                                                    

function push(x) { stack[t++] = x }                                                                                                  

function pop() { if (t > 0) { return stack[--t] } else { return "" }  }                                                              

{                                                                                                                                    

if( $0 ~ /.*menu.*{.*/ )                                                                                                             
{                                                                                                                                    
  push( $0 )                                                                                                                         
  l++;                                                                                                                               

} else if( $0 ~ /.*{.*/ )                                                                                                            
{                                                                                                                                    
  push( $0 )                                                                                                                         

} else if( $0 ~ /.*}.*/ )                                                                                                            
{                                                                                                                                    
  X = pop()                                                                                                                          
  if( X ~ /.*menu.*{.*/ )                                                                                                            
  {                                                                                                                                  
     l--;                                                                                                                            
     match( X, /^[^'\'']*'\''([^'\'']*)'\''.*$/, arr )                                                                               

     if( l == 0 )                                                                                                                    
     {                                                                                                                               
       print menuindex ": " arr[1]                                                                                                   
       menuindex++                                                                                                                   
       submenu=0                                                                                                                     
     } else                                                                                                                          
     {                                                                                                                               
       print "  " (menuindex-1) ">" submenu " " arr[1]                                                                               
       submenu++                                                                                                                     
     }                                                                                                                               
  }                                                                                                                                  
}                                                                                                                                    

}' /boot/grub/grub.cfg
}

# From Red Hat documentation

# https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/6/html/virtualization_tuning_and_optimization_guide/sect-virtualization_tuning_optimization_guide-memory-huge_pages-1gb-runtime

config_grub () {

echo "Regenerating /boot/grub/grub.cfg..."
sudo grub-mkconfig -o /boot/grub/grub.cfg
echo "Done."
echo "Current Grub entries:"
get_grub_entries
echo "If you have other grub configuration file location than \
/boot/grub/grub.cfg, remember to fix them."

}

change_grub_entries () {

if [ $1 == "1G" ] ; then
    num=2
else
    num=1024
fi

# This sed script adds linux boot parameters:
# default hugepage size, hugepages in total of 2GB, and closes 
# transparent hugepage.

sudo sed -i "s/\"\${GRUB_CMDLINE_LINUX}/\"\${GRUB_CMDLINE_LINUX} \
default_hugepagesz=$1 hugepagesz=$1 hugepages=$num transparent_hugepage=never/g; \
s/GRUB_CMDLINE_LINUX_DEFAULT}\"/GRUB_CMDLINE_LINUX_DEFAULT} 3\"/g; \
s/linux_entry \"\${OS}\"/linux_entry \"\${OS} ($1 hugepage)\"/g; \
s/ns for %s\" \"\${OS}\"/ns for %s\"\"\${OS} ($1 hugepage)\"/g"  \
$2

}

install_grub () {

if [ "$(sudo grep pse /proc/cpuinfo | uniq)" ]; then
    echo "pse detected. Installing 2M hugepage entries..."
    sudo cp /etc/grub.d/10_linux /etc/grub.d/11_linux_hugepage
    change_grub_entries 2M /etc/grub.d/11_linux_hugepage
fi

if [ "$(sudo grep pdpe1gb /proc/cpuinfo | uniq)" ]; then
    echo "pdpe1gb detected. Installing 1G hugepage entries..."
    sudo cp /etc/grub.d/10_linux /etc/grub.d/12_linux_hugepage
    change_grub_entries 1G /etc/grub.d/12_linux_hugepage
fi

echo "Installing no transparent hugepage entries..."
sudo cp /etc/grub.d/10_linux /etc/grub.d/13_linux_hugepage

sudo sed -i "s/\${GRUB_CMDLINE_LINUX}/\${GRUB_CMDLINE_LINUX} \
transparent_hugepage=never/g; \
s/GRUB_CMDLINE_LINUX_DEFAULT}\"/GRUB_CMDLINE_LINUX_DEFAULT} 3\"/g; \
s/linux_entry \"\${OS}\"/linux_entry \"\${OS} (No THP)\"/g; \
s/ns for %s\" \"\${OS}\"/ns for %s\"\"\${OS} (No THP)\"/g"  \
/etc/grub.d/13_linux_hugepage

sudo cp /etc/grub.d/10_linux /etc/grub.d/14_linux_hugepage

sudo sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT}\"/GRUB_CMDLINE_LINUX_DEFAULT} 3\"/g; \
s/linux_entry \"\${OS}\"/linux_entry \"\${OS} (THP)\"/g; \
s/ns for %s\" \"\${OS}\"/ns for %s\"\"\${OS} (THP)\"/g"  \
/etc/grub.d/14_linux_hugepage

echo "Done. Regenerating grub entries..."
config_grub

}


remove_grub () {

if sudo [ -f "/etc/grub.d/11_linux_hugepage" ]; then
    echo "Removing 2M hugepage entries..."
    sudo rm /etc/grub.d/11_linux_hugepage
fi


if sudo [ -f "/etc/grub.d/12_linux_hugepage" ]; then
    echo "Removing 1G hugepage entries..."
    sudo rm /etc/grub.d/12_linux_hugepage
fi

if sudo [ -f "/etc/grub.d/13_linux_hugepage" ]; then
    echo "Removing no transparent hugepage entries..."
    sudo rm /etc/grub.d/13_linux_hugepage
fi


if sudo [ -f "/etc/grub.d/13_linux_hugepage" ]; then
    echo "Removing transparent hugepage entries..."
    sudo rm /etc/grub.d/14_linux_hugepage
fi

echo "Done. Regenerating grub entries..."
config_grub

}

# Make VM


## Prepairing images

# This might be no longer available as time passes. Replace this with a latest URL to continue.
# Can be found here: https://mirror.pkgbuild.com/images/latest/
VM_url="https://mirror.sjtu.edu.cn/archlinux/images/latest/Arch-Linux-x86_64-basic-20211201.40458.qcow2"
url=$VM_url
asking_url () {



echo "Checking original image status"

if curl --output /dev/null --silent --head --fail "${VM_url}"; then
    status="OK"
else
    status="Error"
fi

if [ "$status" == "Error" ] || [ ! -f "hugepage.qcow2" ]; then
BACKTITLE="${name}"
TITLE="${name}: VM image"
url=$(dialog --clear \
    --backtitle "$BACKTITLE" \
    --title "$TITLE" \
    --no-cancel \
    --inputbox "Enter the VM qcow2 image url. (Default status: ${status})" \
    $HEIGHT $WIDTH $VM_url \
    2>&1 >/dev/tty)
else
url=$VM_url
fi
}

download_image () {

download=yes

if [ -f "hugepage.qcow2" ]; then
    echo "hugepage.qcow2 file detected. Checking if valid..."
    if curl -s "${url}.SHA256" | sed "s/ .*/ hugepage.qcow2/g" | sha256sum --status -c - ; then
        BACKTITLE="${name}"
        TITLE="${name}: VM image"
        if dialog --clear \
        --backtitle "$BACKTITLE" \
        --title "$TITLE" \
        --yesno "hugepage.qcow2 exists and valid. Redownload?" \
        $HEIGHT $WIDTH\
        2>&1 >/dev/tty ; then
            download=yes
        else
            download=no
        fi
        clear
    else
        echo "Corrupted hugepage.qcow2 file. Redownloading..."
    fi
fi
    
if [ "$download" == "yes" ]; then
    curl -o "hugepage.qcow2" ${url}
    if curl -s "${url}.SHA256" | sed "s/ .*/ hugepage.qcow2/g" | sha256sum --status -c - ; then
        echo "Download succeed."
    else
        echo "Download failed. Please retry."
        exit
    fi
fi

}

## Prepair xml files of libvirt

macaddr=$(date|md5sum|sed 's/^\(..\)\(..\)\(..\)\(..\)\(..\).*$/02:\1:\2:\3:\4:\5/')
uuid_value=$(uuidgen)


# get: vm_name, network_name

filter_name () {

case $2 in
    "Name")
    vm_name=$3
    ;;
    "libvirt_Network")
    network=$3
    ;;
    "hugepage")
    vm_hp=$3
    ;;
    *)
    exit
    ;;
esac

}

enable_memory="
<memoryBacking>
    <hugepages/>
    </memoryBacking>
"

input_names () {

CONTINUE=yes
vm_name="Arch-hugepage-$$"
network="default"
vm_hp="yes"
while [ "$CONTINUE" == "yes" ] ; do
CHOICE_HEIGHT="2"
BACKTITLE="${name}"
TITLE="${name}: VM config"
MENU="Edit the items. Make sure the network you choose is NAT and has DHCP configured."

OPTIONS=(
    "Name"                  "$vm_name"
    "libvirt_Network"       "$network"
    "hugepage"              "$vm_hp"
)
CHANGED=$(dialog --clear \
    --backtitle "$BACKTITLE" \
    --title "$TITLE" \
    --no-cancel \
    --inputmenu "$MENU" \
    $HEIGHT $WIDTH $CHOICE_HEIGHT \
    "${OPTIONS[@]}" \
    2>&1 >/dev/tty)

if [ -z "${CHANGED##*RENAMED*}" ]; then
    CONTINUE=yes
    filter_name $CHANGED
else
    CONTINUE=no
fi

if [ ! "$vm_hp" == "yes" ]; then
    enable_memory=""
fi

done

}

# get ip address

get_random_ipaddr () {
python -c "import random, \
ipaddress;print(ipaddress.IPv4Address(random.randrange(\
int(ipaddress.IPv4Address('$1')),int(ipaddress.IPv4Address('$2')))))"
}


input_ip () {

ranges=$(sudo virsh net-dumpxml --network $network | \
egrep "range start='.*' end='.*'" | \
sed "s/      <range start='\(.*\)' end='\(.*\)'\/>/\1 \2/g")

prefered_addr=$(get_random_ipaddr $ranges)

BACKTITLE="${name}"
TITLE="${name}: VM ip"

ipaddr=$(dialog --clear \
    --backtitle "$BACKTITLE" \
    --title "$TITLE" \
    --no-cancel \
    --inputbox "Enter the VM ip.\nCurrent range: $ranges" \
    $HEIGHT $WIDTH $prefered_addr \
    2>&1 >/dev/tty)
}


add_network () {
sudo virsh net-update $network add ip-dhcp-host "<host mac=\"${macaddr}\" name=\"${vm_name}\" ip=\"${ipaddr}\"/>" --live --config
}

remove_network () {
sudo virsh net-update $network delete ip-dhcp-host "<host ip=\"${ipaddr}\"/>" --live --config
}

define_vm () {

xml_template="<domain type=\"kvm\">
  <name>${vm_name}</name>
  <uuid>${uuid_value}</uuid>
  <metadata>
    <libosinfo:libosinfo xmlns:libosinfo=\"http://libosinfo.org/xmlns/libvirt/domain/1.0\">
      <libosinfo:os id=\"http://archlinux.org/archlinux/rolling\"/>
    </libosinfo:libosinfo>
  </metadata>
  <memory unit=\"GiB\">2</memory>
  <currentMemory unit=\"GiB\">2</currentMemory>
  <vcpu placement=\"static\">1</vcpu>
    $enable_memory
  <os>
    <type arch=\"x86_64\" machine=\"pc-q35-5.2\">hvm</type>
    <boot dev=\"hd\"/>
  </os>
  <features>
    <acpi/>
    <apic/>
    <vmport state=\"off\"/>
  </features>
  <cpu mode=\"host-model\" check=\"partial\"/>
  <clock offset=\"utc\">
    <timer name=\"rtc\" tickpolicy=\"catchup\"/>
    <timer name=\"pit\" tickpolicy=\"delay\"/>
    <timer name=\"hpet\" present=\"no\"/>
  </clock>
  <on_poweroff>destroy</on_poweroff>
  <on_reboot>restart</on_reboot>
  <on_crash>destroy</on_crash>
  <pm>
    <suspend-to-mem enabled=\"no\"/>
    <suspend-to-disk enabled=\"no\"/>
  </pm>
  <devices>
    <emulator>/usr/bin/qemu-system-x86_64</emulator>
    <disk type=\"file\" device=\"disk\">
      <driver name=\"qemu\" type=\"qcow2\"/>
      <source file=\"$(realpath hugepage.qcow2)\"/>
      <target dev=\"vda\" bus=\"virtio\"/>
      <address type=\"pci\" domain=\"0x0000\" bus=\"0x04\" slot=\"0x00\" function=\"0x0\"/>
    </disk>
    <controller type=\"usb\" index=\"0\" model=\"qemu-xhci\" ports=\"15\">
      <address type=\"pci\" domain=\"0x0000\" bus=\"0x02\" slot=\"0x00\" function=\"0x0\"/>
    </controller>
    <controller type=\"sata\" index=\"0\">
      <address type=\"pci\" domain=\"0x0000\" bus=\"0x00\" slot=\"0x1f\" function=\"0x2\"/>
    </controller>
    <controller type=\"pci\" index=\"0\" model=\"pcie-root\"/>
    <controller type=\"pci\" index=\"1\" model=\"pcie-root-port\">
      <model name=\"pcie-root-port\"/>
      <target chassis=\"1\" port=\"0x10\"/>
      <address type=\"pci\" domain=\"0x0000\" bus=\"0x00\" slot=\"0x02\" function=\"0x0\" multifunction=\"on\"/>
    </controller>
    <controller type=\"pci\" index=\"2\" model=\"pcie-root-port\">
      <model name=\"pcie-root-port\"/>
      <target chassis=\"2\" port=\"0x11\"/>
      <address type=\"pci\" domain=\"0x0000\" bus=\"0x00\" slot=\"0x02\" function=\"0x1\"/>
    </controller>
    <controller type=\"pci\" index=\"3\" model=\"pcie-root-port\">
      <model name=\"pcie-root-port\"/>
      <target chassis=\"3\" port=\"0x12\"/>
      <address type=\"pci\" domain=\"0x0000\" bus=\"0x00\" slot=\"0x02\" function=\"0x2\"/>
    </controller>
    <controller type=\"pci\" index=\"4\" model=\"pcie-root-port\">
      <model name=\"pcie-root-port\"/>
      <target chassis=\"4\" port=\"0x13\"/>
      <address type=\"pci\" domain=\"0x0000\" bus=\"0x00\" slot=\"0x02\" function=\"0x3\"/>
    </controller>
    <controller type=\"pci\" index=\"5\" model=\"pcie-root-port\">
      <model name=\"pcie-root-port\"/>
      <target chassis=\"5\" port=\"0x14\"/>
      <address type=\"pci\" domain=\"0x0000\" bus=\"0x00\" slot=\"0x02\" function=\"0x4\"/>
    </controller>
    <controller type=\"pci\" index=\"6\" model=\"pcie-root-port\">
      <model name=\"pcie-root-port\"/>
      <target chassis=\"6\" port=\"0x15\"/>
      <address type=\"pci\" domain=\"0x0000\" bus=\"0x00\" slot=\"0x02\" function=\"0x5\"/>
    </controller>
    <controller type=\"pci\" index=\"7\" model=\"pcie-root-port\">
      <model name=\"pcie-root-port\"/>
      <target chassis=\"7\" port=\"0x16\"/>
      <address type=\"pci\" domain=\"0x0000\" bus=\"0x00\" slot=\"0x02\" function=\"0x6\"/>
    </controller>
    <interface type=\"network\">
        <mac address=\"${macaddr}\"/>
        <source network=\"${network}\"/>
        <model type=\"virtio\"/>
        <address type=\"pci\" domain=\"0x0000\" bus=\"0x01\" slot=\"0x00\" function=\"0x0\"/>
    </interface>
    <graphics type=\"spice\" autoport=\"yes\">
        <listen type=\"address\"/>
        <image compression=\"off\"/>
    </graphics>
    <memballoon model=\"virtio\">
      <address type=\"pci\" domain=\"0x0000\" bus=\"0x05\" slot=\"0x00\" function=\"0x0\"/>
    </memballoon>
    <rng model=\"virtio\">
      <backend model=\"random\">/dev/urandom</backend>
      <address type=\"pci\" domain=\"0x0000\" bus=\"0x06\" slot=\"0x00\" function=\"0x0\"/>
    </rng>
  </devices>
</domain>
"
echo $xml_template > /tmp/xml-$$.xml
sudo virsh define /tmp/xml-$$.xml
rm /tmp/xml-$$.xml

if [ "$enable_memory" == "" ]; then
sed -i "s/^available_VM=( /available_VM=( \"${vm_name}:${network}:${ipaddr}:nohp\" /g" "$(readlink -f $0)"
else
sed -i "s/^available_VM=( /available_VM=( \"${vm_name}:${network}:${ipaddr}:hp\" /g" "$(readlink -f $0)"
fi

}

# Testing environment checking

test_if_hugepages () {

total_hp=$(grep HugePages_Total /proc/meminfo | sed "s/^.* \([0-9]\+\)$/\1/g")
if [ "$total_hp" == "0" ]; then
    current_hp=nohp
else
    current_hp=hp
fi

}

get_vm_entries () {

for vm in "${available_VM[@]}"; do
    IFS=: read -r vm_name network ipaddr status <<< "$vm"
    if [ "$status" == "$1" ]; then
        break
    fi
done

found=no

if [ "$status" == "$1" ]; then
    found=yes
fi

}

# VM operations

start_vm () {

if [ "$1" == "hp" ]; then
    # Check if hugepage space is sufficient
    hpsize=$(grep Hugepagesize /proc/meminfo | sed "s/^.* \([0-9]\+\) kB$/\1/g")
    free_hp=$(grep HugePages_Free /proc/meminfo | sed "s/^.* \([0-9]\+\)$/\1/g")
    total_hp=$((hpsize * free_hp))
    if [ $total_hp -lt 2097152 ]; then
        echo "Hugepage is occupied! Check these programs and terminate them"
        sudo grep '^VmFlags:.* ht' /proc/[0-9]*/smaps
        exit
    fi
fi

download_image

sudo virsh start $vm_name

}

stop_vm () {

sleep 5
sudo virsh destroy --graceful $vm_name

}

remove_vm () {

for vm in "${available_VM[@]}"
do
echo $vm
IFS=: read -r vm_name network ipaddr status <<< "$vm"
sudo virsh destroy --graceful $vm_name
sudo virsh undefine $vm_name
remove_network
done

sed -i "s/^available_VM=(.*)/available_VM=( )/g" "$(readlink -f $0)"

}


# Memory Testing

prepare_memory_test () {

command='"echo \"" > /etc/pacman.d/mirrorlist"'
echo "Linear memory read and write"
sleep 10
ssh-keygen -R ${ipaddr}
ssh-keyscan ${ipaddr} >> ~/.ssh/known_hosts
sshpass -p arch ssh arch@${ipaddr} sudo sed -i 's/^SigLevel.*$/SigLevel=Never/g' /etc/pacman.conf
echo 'Server = https://mirror.sjtu.edu.cn/archlinux/$repo/os/$arch' > /tmp/$$-ml
sshpass -p arch scp /tmp/$$-ml arch@${ipaddr}:/tmp/mirrorlist
rm /tmp/$$-ml
sshpass -p arch ssh arch@${ipaddr} sudo cp /tmp/mirrorlist /etc/pacman.d/mirrorlist
sshpass -p arch ssh arch@${ipaddr} sudo rm -f /var/lib/pacman/db.lck
sshpass -p arch ssh arch@${ipaddr} sudo pacman --noconfirm -Syy sysbench

}

clear_memory_test () {

ssh-keygen -R ${ipaddr}

}


ping_until_connected () {

sleep 180

GOOD=10
while [ "$GOOD" != "0" ]
do
    echo "Ping testing: $ipaddr"
    ping -c 10 $ipaddr > /dev/null 2>&1
    if [ "$?" == "0" ] ; then
        break
    fi
    GOOD=$(($GOOD - 1))
done

if [ "$GOOD" == "0" ]; then
    echo "Not connected. Exiting..."
    stop_vm
    exit
fi

GOOD=10
while [ "$GOOD" != "0" ]
do
    echo "SSH testing: $ipaddr"
    if [ "x$(nmap ${ipaddr} -PN -p ssh | grep open)x" != "xx" ] ; then
        break
    fi
    sleep 10
    GOOD=$(($GOOD - 1))
done

if [ "$GOOD" == "0" ]; then
    echo "Not connected. Exiting..."
    stop_vm
    exit
fi
echo "Connection Established."

}


# Sysbench Testing

# From: developers.redhat.com benchmarking 

sysbench_memory_test () {

result_seq_r="$(sshpass -p arch ssh arch@${ipaddr} sudo sysbench memory --memory-block-size=64M --memory-total-size=4096G --time=500 --memory-oper=read --memory-access-mode=seq run)"
result_seq_w="$(sshpass -p arch ssh arch@${ipaddr} sudo sysbench memory --memory-block-size=64M --memory-total-size=4096G --time=500 --memory-oper=write --memory-access-mode=seq run)"
result_rnd_r="$(sshpass -p arch ssh arch@${ipaddr} sudo sysbench memory --memory-block-size=64M --memory-total-size=4096G --time=500 --memory-oper=read --memory-access-mode=rnd run)"
result_rnd_w="$(sshpass -p arch ssh arch@${ipaddr} sudo sysbench memory --memory-block-size=64M --memory-total-size=4096G --time=500 --memory-oper=write --memory-access-mode=rnd run)"

}

sysbench_print () {

hpsize=$(grep Hugepagesize /proc/meminfo | sed "s/^.* \([0-9]\+\) kB$/\1/g")
total_hp=$(grep HugePages_Total /proc/meminfo | sed "s/^.* \([0-9]\+\)$/\1/g")
anon_hp=$(grep AnonHugePages /proc/meminfo | sed "s/^.* \([0-9]\+\).*$/\1/g")
if [ "$total_hp" == "0" ]; then
    if [ "$anon_hp" == "0" ]; then
        echo "No Hugepage"
    else
        echo "Transparent Hugepage"
    fi
else
    echo "Hugepage Size: $hpsize KB"
fi

printf "Seq Read:\t$( printf "$result_seq_r" | grep "transferred" | sed "s/^.*(\(.*\)).*$/\1/g")"
latency="$(python -c "print(\"{:.3f}\".format( $( printf "$result_seq_r" | grep "sum" | sed "s/^.* \([0-9.]\+\).*$/\1/g" ) / $( printf "$result_seq_r" | grep "total number" | sed "s/^.* \([0-9.]\+\).*$/\1/g") * 1000000 ))")"
printf "\t|Latency\tMax:\t$( printf "$result_seq_r" | grep "max" | sed "s/^.* \([0-9.]\+\).*$/\1/g" )ms\tAvg:\t${latency}ns\n"

printf "Seq Write:\t$( printf "$result_seq_w" | grep "transferred" | sed "s/^.*(\(.*\)).*$/\1/g")"
latency="$(python -c "print(\"{:.3f}\".format( $( printf "$result_seq_w" | grep "sum" | sed "s/^.* \([0-9.]\+\).*$/\1/g" ) / $( printf "$result_seq_w" | grep "total number" | sed "s/^.* \([0-9.]\+\).*$/\1/g") * 1000000 ))")"
printf "\t|Latency\tMax:\t$( printf "$result_seq_w" | grep "max" | sed "s/^.* \([0-9.]\+\).*$/\1/g" )ms\tAvg:\t${latency}ns\n"

printf "Rnd Read:\t$( printf "$result_rnd_r" | grep "transferred" | sed "s/^.*(\(.*\)).*$/\1/g")"
latency="$(python -c "print(\"{:.3f}\".format( $( printf "$result_rnd_r" | grep "sum" | sed "s/^.* \([0-9.]\+\).*$/\1/g" ) / $( printf "$result_rnd_r" | grep "total number" | sed "s/^.* \([0-9.]\+\).*$/\1/g") * 1000000 ))")"
printf "\t|Latency\tMax:\t$( printf "$result_rnd_r" | grep "max" | sed "s/^.* \([0-9.]\+\).*$/\1/g" )ms\tAvg:\t${latency}ns\n"

printf "Rnd Write:\t$( printf "$result_rnd_w" | grep "transferred" | sed "s/^.*(\(.*\)).*$/\1/g")"
latency="$(python -c "print(\"{:.3f}\".format( $( printf "$result_rnd_w" | grep "sum" | sed "s/^.* \([0-9.]\+\).*$/\1/g" ) / $( printf "$result_rnd_w" | grep "total number" | sed "s/^.* \([0-9.]\+\).*$/\1/g") * 1000000 ))")"
printf "\t|Latency\tMax:\t$( printf "$result_rnd_w" | grep "max" | sed "s/^.* \([0-9.]\+\).*$/\1/g" )ms\tAvg:\t${latency}ns\n\n"

}


# Memory testing

do_memory_test () {

prepare_memory_test

sysbench_memory_test

clear_memory_test

}

## result page

print_result () {

sysbench_result="$(sysbench_print)"

CHOICE_HEIGHT="$(($HEIGHT - 5))"
BACKTITLE="${name}"
TITLE="${name}: Result"

dialog --clear --cr-wrap \
    --backtitle "$BACKTITLE" \
    --title "$TITLE" \
    --msgbox "$(printf "Sysbench Result \n$sysbench_result \n")" \
    $HEIGHT $WIDTH \
    2>&1 >/dev/tty
    
printf "Sysbench Result \n$sysbench_result \n" >> result
}

## Menu to select

test_if_hugepages

CHOICE_HEIGHT="$(($HEIGHT - 5))"
BACKTITLE="${name}"
TITLE="${name}: Main"
MENU="Tasks:"
OPTIONS=(
    "Install Grub entries"   "Add grub entries for Huge page testing"
    "Remove Grub entries"    "Remove grub entries added above"
    "Make VM"                "Make VM for testing"
    "Remove VM"              "Remove VM created for testing"
    "Memory Test"            "Run memory test with existing VM"
    "Quit"                   "Quit the ${name}"
)
CHOICE=$(dialog --clear \
    --backtitle "$BACKTITLE" \
    --title "$TITLE" \
    --menu "$MENU" \
    $HEIGHT $WIDTH $CHOICE_HEIGHT \
    "${OPTIONS[@]}" \
    2>&1 >/dev/tty)
    
clear
case $CHOICE in
    "Install Grub entries")
        echo "Installing Grub entries"
        install_grub
        ;;
    
    "Remove Grub entries")
        echo "Removing Grub entries"
        remove_grub
        ;;
        
    "Make VM")
        asking_url
        download_image
        input_names
        input_ip
        remove_network
        add_network
        define_vm
        ;;
        
    "Remove VM")
        remove_vm
        ;;
        
    "Memory Test")
        echo "Running memory test"
        get_vm_entries $current_hp
        if [ ! "$found" == "yes" ]; then
            clear
            echo "VM Not found. Use Make VM entries first."
            exit
        fi
        start_vm $current_hp
        echo "Waiting VM to be started..."
        ping_until_connected
        do_memory_test
        print_result
        clear
        stop_vm
        ;;
    
    "Quit")
        :
        ;;
esac
