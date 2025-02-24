#!/usr/bin/env bash

# Copyright (c) 2021-2025 community-scripts ORG
# Author: BvdBerg01
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE

function header_info {
  clear
  cat <<"EOF"
    __   _  ________   __  __          __      __     
   / /  | |/ / ____/  / / / /___  ____/ /___ _/ /____ 
  / /   |   / /      / / / / __ \/ __  / __ `/ __/ _ \
 / /___/   / /___   / /_/ / /_/ / /_/ / /_/ / /_/  __/
/_____/_/|_\____/   \____/ .___/\__,_/\__,_/\__/\___/ 
                        /_/                           
EOF
}

set -eEuo pipefail
YW=$(echo "\033[33m")
BL=$(echo "\033[36m")
RD=$(echo "\033[01;31m")
GN=$(echo "\033[1;92m")
CL=$(echo "\033[m")
TAB="  "
BFR="\\r\\033[K"
HOLD="-"
CROSS="${RD}✗${CL}"
CM="${TAB}✔️${TAB}${CL}"

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

# msg_info() {
#   local msg="$1"
#   echo -ne " ${HOLD} ${YW}${msg}..."
# }

# msg_ok() {
#   local msg="$1"
#   echo -e "${BFR} ${CM} ${GN}${msg}${CL}"
# }

# msg_error() {
#   local msg="$1"
#   echo -e "${BFR} ${CROSS} ${RD}${msg}${CL}"
# }



header_info
echo "Loading..."
whiptail --backtitle "Proxmox VE Helper Scripts" --title "LXC Container Update" --yesno "This will update LXC container. Proceed?" 10 58 || exit

NODE=$(hostname)
containers=$(pct list | tail -n +2 | awk '{print $0 " " $4}')

if [ -z "$containers" ]; then
    whiptail --title "LXC Container Update" --msgbox "No LXC containers available!" 10 60
    exit 1
fi

menu_items=()
FORMAT="%-10s %-15s %-10s"

while read -r container; do
    container_id=$(echo $container | awk '{print $1}')
    container_name=$(echo $container | awk '{print $2}')
    container_status=$(echo $container | awk '{print $3}')
    formatted_line=$(printf "$FORMAT" "$container_name" "$container_status")
    menu_items+=("$container_id" "$formatted_line" "OFF")
done <<< "$containers"

CHOICE=$(whiptail --title "LXC Container Update" \
                   --radiolist "Select LXC containers to update:" 25 60 13 \
                   "${menu_items[@]}" 3>&2 2>&1 1>&3)

if [ -z "$CHOICE" ]; then
    whiptail --title "LXC Container Update" \
             --msgbox "No containers selected!" 10 60
    exit 1
fi

header_info
if(whiptail --backtitle "Proxmox VE Helper Scripts" --title "LXC Container Update" --yesno "Do you want to create a backup from your container?" 10 58); then
msg_info "Creating backup"
vzdump $CHOICE --compress zstd --storage local -notes-template "community-scripts backup updater" > /dev/null 2>&1
status=$?
if [ $status -eq 0 ]; then
msg_ok "Backup created"
pct exec $CHOICE -- update --from-pve
exit_code=$?
else
msg_error "Backup failed"
fi
else
set +e
pct exec $CHOICE -- update --from-pve
exit_code=$?
set -e
fi
if [ $exit_code -eq 0 ]; then
    msg_ok "Update completed"
else
    msg_error "Update failed"
fi