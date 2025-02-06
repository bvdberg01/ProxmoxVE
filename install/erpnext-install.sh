#!/usr/bin/env bash

# Copyright (c) 2021-2025 community-scripts ORG
# Author: bvdberg01
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE

source /dev/stdin <<< "$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get install -y \
  curl \
  sudo \
  mc \
  git \
  python3-dev \
  python3.11-dev \
  python3-setuptools \
  python3-pip \
  python3-distutils \
  python3.11-venv \
  software-properties-common \
  mariadb-server \
  redis-server \
  xvfb \
  libfontconfig \
  wkhtmltopdf \
  libmysqlclient-dev
msg_ok "Installed Dependencies"

msg_info "Installing erpnext"


msg_ok "Installed erpnext"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
