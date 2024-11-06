#!/usr/bin/env bash

# Copyright (c) 2021-2024 tteck
# Author: tteck (tteckster)
# License: MIT
# https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE

source /dev/stdin <<< "$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies (Patience)"
$STD apt-get install -y curl
$STD apt-get install -y sudo
$STD apt-get install -y wget
$STD apt-get install -y gnupg
$STD apt-get install -y build-essential
$STD apt-get install -y libsqlite3-dev
msg_ok "Installed Dependencies"

msg_info "Installing Golang"
set +o pipefail
RELEASE=$(curl -s https://go.dev/dl/ | grep -o "go.*\linux-amd64.tar.gz" | head -n 1)
wget -q https://golang.org/dl/$RELEASE
tar -xzf $RELEASE -C /usr/local
$STD ln -s /usr/local/go/bin/go /usr/local/bin/go
set -o pipefail
msg_ok "Installed Golang"


msg_info "Creating Service"
service_path="/etc/systemd/system/authelia.service"
echo "[Unit]
Description=Authelia
After=network-online.target
[Service]
User=root
WorkingDirectory=/opt/authelia
ExecStart=/opt/authelia/bin/kc.sh start-dev
[Install]
WantedBy=multi-user.target" >$service_path
$STD systemctl enable --now authelia.service
msg_ok "Created Service"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
