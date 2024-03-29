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

# Function to check if the virtual machine exists
check_vm_exists() {
    local vm_name="$1"
    local vm_list=$(qm list | awk '{print $2}')
    for vm in $vm_list; do
        if [ "$vm" == "$vm_name" ]; then
            return 0
        fi
    done
    return 1
}

# Function to create a new virtual machine
create_vm() {
    local vm_name="$1"
    local ram="$2"
    local os="$3"
    local vmid=$(($(qm list | awk '{print $1}' | sort -n | tail -n 1) + 1))
    local ram_mb=$(echo "$ram" | sed 's/[^0-9]*//g')
    local os_type

    if [ "$os" == "Linux" ]; then
        os_type=l26
    elif [ "$os" == "Windows 10" ]; then
        os_type=win10
    elif [ "$os" == "Windows 11" ]; then
        os_type=win11
    elif [ "$os" == "Windows 7" ]; then
        os_type=win7
    elif [ "$os" == "Windows 8" ]; then
        os_type=win8
    elif [ "$os" == "Windows Vista" ]; then
        os_type=wvista
    elif [ "$os" == "Windows XP" ]; then
        os_type=wxp
    else
        slow_type "Unsupported OS type. Please choose Linux or Windows 10 or Widnows 11 or Widnows 7 or Widnows 8 or Windows Vista or Windows XP."
        exit 1
    fi

    qm create $vmid --name "$vm_name" --net0 model=virtio,bridge=vmbr0,firewall=1 --memory "$ram_mb" --ostype "$os_type" --storage local
    slow_type "New virtual machine created successfully with ID: $vmid"
}

attach_disk() {
    local VMID="$1"
    local Dnum="$2"
    
    # Path to the disk
    local path="local:$VMID/vm-$VMID-disk-$Dnum.vmdk"
    
    # Set SATA controller for the Virtual Machine
    qm set $VMID --sata0 $path
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
    slow_type "Enter the Virtual Machine's name (the file name should be same as registered in Proxmox) or you can create one (Type: Create1): "
    read -p "" VMname

    if [ "$VMname" == "Create1" ]; then
        slow_type "Creating a new virtual machine..."

        slow_type "Enter the name for the new virtual machine: "
        read -p "" IMVMname
        
        VMname=$IMVMname
        
        slow_type "How much memory would you like to allocate? (in MBs): "
        read -p "" IMRAM
        slow_type "What operating system will you be running? (Linux or Windows): "
        read -p "" IMOS

        create_vm "$IMVMname" "$IMRAM" "$IMOS"
    else
        while ! check_vm_exists "$VMname"; do
            slow_type "Virtual machine '$VMname' does not exist. Here are the virtual machines present on your server:"
            qm list | awk '{print $2}'
            slow_type "If you are not able to see your virtual machine, you can create one by typing 'Create1'"
            read -p "Enter the Virtual Machine's name: " VMname
            if [ "$VMname" == "Create1" ]; then
                slow_type "Creating a new virtual machine..."
                
                slow_type "Enter the name for the new virtual machine: "
                read -p "" IMVMname

                VMname=$IMVMname
                
                slow_type "How much memory would you like to allocate? (in MBs): "
                read -p "" IMRAM
                slow_type "What operating system will you be running? (Linux or Windows): "
                read -p "" IMOS

                create_vm "$IMVMname" "$IMRAM" "$IMOS"
                exit 0
            fi
        done
    fi

    slow_type "Enter the format of the file being downloaded: "
    read -p "" F1

    TEMP_FOLDER="TEMP"
    mkdir -p $TEMP_FOLDER
    cd $TEMP_FOLDER || exit

    # Download the file
    wget "http://$IP/$VMname.$F1"

    # Check if the file is already in vmdk format
    if [ "${F1,,}" != "vmdk" ]; then
        # Convert the file to VMDK format
        slow_type "Converting the file to VMDK format..."
        qemu-img convert -f $F1 -O vmdk "./$VMname.$F1" "./$VMname.vmdk"
    else
        slow_type "File is already in VMDK format. Skipping conversion..."
        mv "$VMname.$F1" "$VMname.vmdk"
    fi

    # Find VM's ID using qm list and grep
    VMID=$(qm list | grep -i "$VMname" | awk '{print $1}')

    # Print VM information
    echo "The Virtual Machine $VMname has ID: $VMID"

    # Import the vmdk to the virtual machine
    qm importdisk $VMID "./$VMname.vmdk" local --format vmdk

    slow_type "Enter the disk number displayed above (look at: unused0:local:105/vm-105-disk-0.vmdk and menstion the number after 'disk')"
    read -p "" Dnum

    disks=$(find / -name "vm-$VMID-disk-*" 2>/dev/null | grep $VMID)

    if echo "$disks" | grep -q "disk-$Dnum"; then
        attach_disk $VMID $Dnum
        echo "Disk attached successfully to VM $VMID"
    else
        echo "Invalid disk number. Please enter a valid disk number."
    fi

    qm set $VMID --boot="order=sata0"

    # Cleanup: Delete the TEMP folder
    cd ..
    rm -rf $TEMP_FOLDER

    slow_type "Import process completed successfully!"

    slow_type "Do you want to power on your Virtual Machine? (Type: yes or no)"
    read -p "" power

    if [ "$power" == "yes" ]; then
        qm start $VMID
        slow_type "Your Virtual machine is powered on"

    else
        slow_type "Ok, you can manually power on your Virtul Machine later."
    
    fi

    slow_type "Thank you! I am at your service anytime."

elif [ "$action" == "Export" ]; then

    slow_type "The export process involves:"
    slow_type "1. Taking information from the user"
    slow_type "2. Finding VM's ID and stopping the Virtual Machine"
    slow_type "3. Configuring and exporting the file"

    slow_type "This is the list of Virtual Machines in your server:"
    qm list | awk '{print $2}'

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
    
    loc=$"local":$VMID1

    # Find the disk information and store it in a variable
    disk_info=$(qm config $VMID1 | grep $loc)
    
    # Extract disk names dynamically
    disk_names=$(echo "$disk_info" | awk -F ': ' '{print $1}')
    
    # Count the number of disks
    disk_count=$(echo "$disk_names" | wc -l)
    
    # If there's only one disk, extract its name directly
    if [ "$disk_count" -eq 1 ]; then
        disk_name=$(echo "$disk_names")
    else
        # Print the disk information and prompt the user to select a disk
        slow_type "Multiple disks found for the virtual machine."
        slow_type "Please select the disk you want to export:"
        echo "$disk_names"
        read -p "Enter the disk name: " selected_disk
    
        # Validate user input
        while ! echo "$disk_names" | grep -qw "$selected_disk"; do
            slow_type "Invalid disk name. Please select from the following:"
            echo "$disk_names"
            read -p "Enter the disk name: " selected_disk
        done
    
        disk_name=$selected_disk
    fi
    
    # Now you have the disk name to export
    echo "Selected disk: $disk_name"


    VMDiskname=$(qm config $VMID1 | grep $disk_name: | awk '{print $3}' FS=: OFS=, | cut -d, -f1)
    Path="local:$VMDiskname"
    VMF1=$(echo "$VMDiskname" | awk -F'.' '{print $2}')

    qemu-img convert -f "$VMF1" -O $F2 "$Path" "./$VMName1.$F2"

    slow_type "Starting the Virtual Machine..."
    qm start $VMID1

    slow_type "Your file that you wanted to be Exported:"
    ls -lh | grep -i "$VMName1"
    pwd

    slow_type "Thank you! I am at your service anytime."
else
    slow_type "Invalid option. Please choose 'Import' or 'Export'."
fi
