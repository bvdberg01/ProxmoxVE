#!/usr/bin/env bash

# Copyright (c) 2021-2025 community-scripts ORG
# Author: bvdberg01
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/inventaire/inventaire

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
  lsb-release \
  git \
  nginx \
  graphicsmagick \
  openssl \
  inotify-tools \
  software-properties-common \
  apt-transport-https
msg_ok "Installed Dependencies"

msg_info "Setting up Node.js/Yarn"
mkdir -p /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" >/etc/apt/sources.list.d/nodesource.list
$STD apt-get update
$STD apt-get install -y nodejs
$STD npm install -g npm@latest
$STD npm install -g yarn
msg_ok "Installed Node.js/Yarn"

msg_info "Setting up Elasticsearch"
curl -fsSL https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo gpg --dearmor -o /usr/share/keyrings/elasticsearch-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/elasticsearch-keyring.gpg] https://artifacts.elastic.co/packages/7.x/apt stable main" | sudo tee /etc/apt/sources.list.d/elastic-7.x.list >/dev/null
$STD apt-get update
$STD apt-get -y install elasticsearch
echo "-Xms2g" >>/etc/elasticsearch/jvm.options
echo "-Xmx2g" >>/etc/elasticsearch/jvm.options
$STD /usr/share/elasticsearch/bin/elasticsearch-plugin install ingest-attachment -b
systemctl -q restart elasticsearch
msg_ok "Setup Elasticsearch"

msg_info "Installing Apache CouchDB"
ERLANG_COOKIE=$(openssl rand -base64 32)
ADMIN_PASS="$(openssl rand -base64 18 | cut -c1-13)"
debconf-set-selections <<< "couchdb couchdb/cookie string $ERLANG_COOKIE"
debconf-set-selections <<< "couchdb couchdb/mode select standalone"
debconf-set-selections <<< "couchdb couchdb/bindaddress string 0.0.0.0"
debconf-set-selections <<< "couchdb couchdb/adminpass password $ADMIN_PASS"
debconf-set-selections <<< "couchdb couchdb/adminpass_again password $ADMIN_PASS"
curl -fsSL https://couchdb.apache.org/repo/keys.asc | gpg --dearmor -o /usr/share/keyrings/couchdb-archive-keyring.gpg
VERSION_CODENAME="$(awk -F'=' '/^VERSION_CODENAME=/{ print $NF }' /etc/os-release)"
echo "deb [signed-by=/usr/share/keyrings/couchdb-archive-keyring.gpg] https://apache.jfrog.io/artifactory/couchdb-deb/ ${VERSION_CODENAME} main" >/etc/apt/sources.list.d/couchdb.sources.list
$STD apt-get update
$STD apt-get install -y couchdb
echo -e "CouchDB Erlang Cookie: \e[32m$ERLANG_COOKIE\e[0m" >>~/CouchDB.creds
echo -e "CouchDB Admin Password: \e[32m$ADMIN_PASS\e[0m" >>~/CouchDB.creds
msg_ok "Installed Apache CouchDB."

msg_info "Installing Inventaire"
cd /opt
git clone http://github.com/inventaire/inventaire
cd inventaire
$STD npm install --production
echo "${RELEASE}" >/opt/${APPLICATION}_version.txt
msg_ok "Installed Inventaire"

msg_info "Creating Service"

msg_ok "Created Service"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
