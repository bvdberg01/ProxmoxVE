#!/usr/bin/env bash

# Copyright (c) 2021-2025 community-scripts ORG
# Author: MickLesk (CanbiZ)
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE

function header_info {
  clear
  cat <<"EOF"
    ____                                          _    ____  ___   ____       __     __     
   / __ \_________  _  ______ ___  ____  _  __   | |  / /  |/  /  / __ \___  / /__  / /____ 
  / /_/ / ___/ __ \| |/_/ __ `__ \/ __ \| |/_/   | | / / /|_/ /  / / / / _ \/ / _ \/ __/ _ \
 / ____/ /  / /_/ />  </ / / / / / /_/ />  <     | |/ / /  / /  / /_/ /  __/ /  __/ /_/  __/
/_/   /_/   \____/_/|_/_/ /_/ /_/\____/_/|_|     |___/_/  /_/  /_____/\___/_/\___/\__/\___/ 
                                                                                            
EOF
}

spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while ps -p $pid > /dev/null; do
        printf " [%c]  " "$spinstr"
        spinstr=${spinstr#?}${spinstr%"${spinstr#?}"}
        sleep $delay
        printf "\r"
    done
    printf "    \r"
}

set -eEuo pipefail
YW=$(echo "\033[33m")
BL=$(echo "\033[36m")
RD=$(echo "\033[01;31m")
GN=$(echo "\033[1;92m")
CL=$(echo "\033[m")
TAB="  "
CM="${TAB}✔️${TAB}${CL}"

header_info
echo "Loading..."
whiptail --backtitle "Proxmox VE Helper Scripts" --title "Proxmox VE VM Deletion" --yesno "This will delete Virtual Machines. Proceed?" 10 58 || exit

NODE=$(hostname)
virtualmachines=$(qm list | tail -n +2 | awk '{print $0 " " $4}')

if [ -z "$virtualmachines" ]; then
    whiptail --title "Virtual Machine Delete" --msgbox "No Virtual Machines available!" 10 60
    exit 1
fi

menu_items=()
FORMAT="%-10s %-15s %-10s"

while read -r virtualmachine; do
    virtualmachine_id=$(echo $virtualmachine | awk '{print $1}')
    virtualmachine_status=$(echo $virtualmachine | awk '{print $2}')
    virtualmachine_name=$(echo $virtualmachine | awk '{print $3}')
    formatted_line=$(printf "$FORMAT" "$virtualmachine_name" "$virtualmachine_status")
    menu_items+=("$virtualmachine_id" "$formatted_line" "OFF")
done <<< "$virtualmachines"

CHOICES=$(whiptail --title "Virtual Machine Delete" \
                   --checklist "Select Virtual Machines to delete:" 25 60 13 \
                   "${menu_items[@]}" 3>&2 2>&1 1>&3)

if [ -z "$CHOICES" ]; then
    whiptail --title "Virtual Machine Delete" \
             --msgbox "No Virtual Machine selected!" 10 60
    exit 1
fi

read -p "Delete Virtual Machines manually or automatically? (Default: manual) m/a: " DELETE_MODE
DELETE_MODE=${DELETE_MODE:-m}

selected_ids=$(echo "$CHOICES" | tr -d '"' | tr -s ' ' '\n')

for virtualmachine_id in $selected_ids; do
    status=$(qm status $virtualmachine_id)

    if [ "$status" == "status: running" ]; then
        echo -e "${BL}[Info]${GN} Stopping Virtual Machine $virtualmachine_id...${CL}"
        qm stop $virtualmachine_id &
        sleep 5
        echo -e "${BL}[Info]${GN} Virtual Machine $virtualmachine_id stopped.${CL}"
    fi

    if [[ "$DELETE_MODE" == "a" ]]; then
        echo -e "${BL}[Info]${GN} Automatically deleting Virtual Machine $virtualmachine_id...${CL}"
        qm destroy "$virtualmachine_id" &
        pid=$!
        spinner $pid
        [ $? -eq 0 ] && echo "Virtual Machine $virtualmachine_id deleted." || whiptail --title "Error" --msgbox "Failed to delete Virtual Machine $virtualmachine_id." 10 60
    else
        read -p "Delete Virtual Machine $virtualmachine_id? (y/N): " CONFIRM
        if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
            echo -e "${BL}[Info]${GN} Deleting Virtual Machine $virtualmachine_id...${CL}"
            qm destroy "$virtualmachine_id" &
            pid=$!
            spinner $pid
            [ $? -eq 0 ] && echo "Virtual Machine $virtualmachine_id deleted." || whiptail --title "Error" --msgbox "Failed to delete Virtual Machine $virtualmachine_id." 10 60
        else
            echo -e "${BL}[Info]${RD} Skipping Virtual Machine $virtualmachine_id...${CL}"
        fi
    fi
done

header_info
echo -e "${GN}Deletion process completed.${CL}\n"
