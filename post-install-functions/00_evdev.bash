#!/bin/bash sh

# function steps #
# 1. add users with UID 1000+ to groups input (evdev), libvirt (evdev and execute VMs).
# 2. parse current USB input devices and event devices.
# 3. save edits to libvirt config, restart services, exit.
#

# check if sudo/root #
if [[ `whoami` != "root" ]]; then
    echo -e "$0: WARNING: Script must be run as Sudo or Root! Exiting."
    exit 0
fi

# NOTE: necessary for newline preservation in arrays and files #
SAVEIFS=$IFS   # Save current IFS (Internal Field Separator)
IFS=$'\n'      # Change IFS to newline char

# system files #
str_file1="/etc/libvirt/qemu.conf"

# system file backups #
str_oldFile1=$(pwd)"/etc_libvirt_qemu.conf.old"

# prompt #
str_output1="$0: Evdev (Event Devices) is a method that assigns input devices to a Virtual KVM (Keyboard-Video-Mouse) switch.\n\tEvdev is recommended for setups without an external KVM switch and passed-through USB controller(s).\n\tNOTE: View '/etc/libvirt/qemu.conf' to review changes, and append to a Virtual machine's configuration file."

echo -e $str_output1

str_UID1000=`cat /etc/passwd | grep 1000 | cut -d ":" -f 1`             # find first normal user

# add to group
declare -a arr_User=(`getent passwd {1000..60000} | cut -d ":" -f 1`)   # find all normal users

for str_User in $arr_User; do
    sudo adduser $str_User input    # add each normal user to input group
    sudo adduser $str_User libvirt  # add each normal user to libvirt group
done  

if [[ -z $arr_InputDeviceID ]]; then
    echo -e "$0: No input devices found. Skipping."
    exit 0
else
    declare -a arr_InputDeviceID=`ls /dev/input/by-id`  # list of input devices
    declare -a arr_InputDeviceEventID=`ls -l /dev/input/by-id | cut -d '/' -f2 | grep -v 'total 0'` # list of event IDs for input devices
    
    echo -en "$0: Executing Evdev setup... "

    # file changes #
    declare -a arr_file_QEMU=(
"# NOTE: Generated by 'portellam/VFIO-setup'
# START #
#
user = \"$str_UID1000\"
group = \"user\"
#
hugetlbfs_mount = \"/dev/hugepages\"
#
nvram = [
   \"/usr/share/OVMF/OVMF_CODE.fd:/usr/share/OVMF/OVMF_VARS.fd\",
   \"/usr/share/OVMF/OVMF_CODE.secboot.fd:/usr/share/OVMF/OVMF_VARS.fd\",
   \"/usr/share/AAVMF/AAVMF_CODE.fd:/usr/share/AAVMF/AAVMF_VARS.fd\",
   \"/usr/share/AAVMF/AAVMF32_CODE.fd:/usr/share/AAVMF/AAVMF32_VARS.fd\"
]
#
cgroup_device_acl = [
")

    for str_InputDeviceID in $arr_InputDeviceID; do
        arr_file_QEMU+=("    \"/dev/input/by-id/$str_InputDeviceID\",")
    done

    for str_InputDeviceEventID in $arr_InputDeviceEventID; do
        arr_file_QEMU+=("    \"/dev/input/by-id/$str_InputDeviceEventID\",")
    done

    arr_file_QEMU+=("    \"/dev/null\", \"/dev/full\", \"/dev/zero\",
    \"/dev/random\", \"/dev/urandom\",
    \"/dev/ptmx\", \"/dev/kvm\",
    \"/dev/rtc\", \"/dev/hpet\"
]
# END #")

    ## 1 ##     # /etc/libvirt/qemu.conf
    bool_readLine=true

    if [[ -z $str_oldFile1 ]]; then
        mv $str_file1 $str_oldFile1

        while read -r str_line1; do
            if [[ $str_line1 == *"# START #"* || $str_line1 == *"portellam/VFIO-setup"* ]]; then
                bool_readLine=false
            fi

            if [[ $bool_readLine == true ]]; then
                echo -e $str_line1 >> $str_file1
            fi

            if [[ $str_line1 == *"# END #"* ]]; then
                bool_readLine=true
            fi
        done < $str_oldFile1
    else
        cp $str_oldFile1 $str_file1
    fi

    # write to file #
    for str_line1 in ${arr_file_QEMU[@]}; do
        echo -e $str_line1 >> $str_file1
    done

    echo -e "Complete.\n"
    systemctl enable libvirtd
    systemctl restart libvirtd
fi

IFS=$SAVEIFS        # reset IFS     # NOTE: necessary for newline preservation in arrays and files
exit 0