#!/bin/bash

slow_type() {
    local text="$1"
    local delay=0.05

    for ((i = 0; i < ${#text}; i++)); do
        echo -n "${text:$i:1}"
        sleep $delay
    done
    echo
}


slow_type "Welcome! I am a program built by Pranava Rao for managing your Virtual Machines."

cat /home/.Banner

slow_type  "What would you like to do? (Type 'Import' or 'Export'): "

read -p "" action

if [ "$action" == "Import" ]; then
    slow_type "The import process involves:"
    slow_type "1. Downloading the import file"
    slow_type "2. Converting to the required format"
    slow_type "3. Adding the file to the Virtual Machine"

    slow_type "Enter the IP Address of the source to Download the file: "
    read -p "" IP
    slow_type "Enter the Virtual Machine's name (the file name should be same as registered in Proxmox): "
    read -p "" VMname
    slow_type "Enter the format of the file being downloaded: "
    read -p "" F1

    TEMP_FOLDER="TEMP"
    mkdir -p $TEMP_FOLDER
    cd $TEMP_FOLDER || exit

    # Download the file
    wget "http://$IP/$VMname.$F1"

    # Convert the file to VMDK format
    qemu-img convert -f $F1 -O vmdk "./$VMname.$F1" "./$VMname.vmdk"

    # Find VM's ID using qm list and grep
    VMID=$(qm list | grep -i "$VMname" | awk '{print $1}')

    # Print VM information
    echo "The Virtual Machine $VMname has ID: $VMID"

    # Import the vmdk to the virtual machine
    qm importdisk $VMID "./$VMname.vmdk" local

    # Cleanup: Delete the TEMP folder
    cd ..
    rm -rf $TEMP_FOLDER

    slow_type "Import process completed successfully!"

    slow_type "Thank you! I am at your service anytime."

elif [ "$action" == "Export" ]; then
    slow_type "The export process involves:"
    slow_type "1. Taking information from the user"
    slow_type "2. Finding VM's ID and stopping the Virtual Machine"
    slow_type "3. Configuring and exporting the file"

    slow_type "Enter the name of the Virtual Machine to export: "
    read -p "" VMName1

    slow_type "Enter the file format to export (e.g., vmdk, qcow2, raw): "
    read -p "" F2

    supported_formats="alloc-track backup-dump-drive blkdebug blklogwrites blkverify bochs cloop compress copy-before-write copy-on-read dmg file ftp ftps gluster host_cdrom host_device http https iscsi iser luks nbd null-aio null-co nvme parallels pbs preallocate qcow qcow2 qed quorum raw rbd replication snapshot-access throttle vdi vhdx vmdk vpc vvfat zeroinit"

    if ! echo "$supported_formats" | grep -qw "$F2"; then
        slow_type "Unsupported format. Please choose from the following supported formats:"
        echo "$supported_formats"
        exit
    fi

    slow_type "Finding VM's ID and stopping the Virtual Machine..."
    VMID1=$(qm list | grep -i "$VMName1" | awk '{print $1}')
    qm stop $VMID1

    slow_type "Configuring and exporting the file..."
    VMDisk=$(qm config $VMID1 | grep 'scsi0:' | awk '{print $2}' FS=: OFS=, | cut -d, -f1)
    VMDiskname=$(qm config $VMID1 | grep 'scsi0:' | awk '{print $3}' FS=: OFS=, | cut -d, -f1)
    Path=$(pvesm path $VMDisk:$VMDiskname)
    qemu-img convert -f vmdk -O $F2 "$Path" "./$VMName1.$F2"

    slow_type "Starting the Virtual Machine..."
    qm start $VMID1

    slow_type "Your file that you wanted to be Exported:"
    ls -lh | grep -i "$VMName1"
    pwd

    slow_type "Thank you! I am at your service anytime."
else
    slow_type "Invalid option. Please choose 'Import' or 'Export'."
fi
