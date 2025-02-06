#!/usr/bin/env bash
source <(curl -s https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2021-2025 community-scripts ORG
# Author: bvdberg01
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://sabre.io/erpnext/

# App Default Values
APP="ERPNext"
var_tags="Dav"
var_cpu="1"
var_ram="512"
var_disk="4"
var_os="debian"
var_version="12"
var_unprivileged="1"

# App Output & Base Settings
header_info "$APP"
base_settings

# Core
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources
  if [[ ! -d /opt/erpnext ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi
  RELEASE=$(curl -s https://api.github.com/repos/sabre-io/erpnext/releases/latest | grep "tag_name" | awk '{print substr($2, 2, length($2)-3) }')
  if [[ ! -f /opt/${APP}_version.txt ]] || [[ "${RELEASE}" != "$(cat /opt/${APP}_version.txt)" ]]; then
    msg_info "Stopping Service"
    systemctl stop apache2
    msg_ok "Stopped Service"

    msg_info "Updating ${APP} to v${RELEASE}"
    cd /opt
    wget -q "https://github.com/sabre-io/erpnext/releases/download/${RELEASE}/erpnext-${RELEASE}.zip"
    mv /opt/erpnext /opt/erpnext-backup
    unzip -o -q "erpnext-${RELEASE}.zip"
    cp -r /opt/erpnext-backup/config/erpnext.yaml /opt/erpnext/config/
    cp -r /opt/erpnext-backup/Specific/ /opt/erpnext/
    chown -R www-data:www-data /opt/erpnext/
    chmod -R 755 /opt/erpnext/
    echo "${RELEASE}" >/opt/${APP}_version.txt
    msg_ok "Updated $APP to v${RELEASE}"

    msg_info "Starting Service"
    systemctl start apache2
    msg_ok "Started Service"

    msg_info "Cleaning up"
    rm -rf "/opt/erpnext-${RELEASE}.zip"
    rm -rf /opt/erpnext-backup
    msg_ok "Cleaned"
    msg_ok "Updated Successfully"
  else
    msg_ok "No update required. ${APP} is already at v${RELEASE}"
  fi
  exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}${CL}"
