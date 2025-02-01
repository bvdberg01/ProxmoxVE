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
  gnupg2\
  postgresql \
  apache2 \
  composer \
  php-8.4{ctype,fileinfo,gd,iconv,intl,apcu} \
  libapache2-mod-php
msg_ok "Installed Dependencies"

msg_info "Setting up PostgreSQL"
DB_NAME=koillection
DB_USER=koillection
DB_PASS=$(openssl rand -base64 18 | tr -dc 'a-zA-Z0-9' | cut -c1-13)
$STD sudo -u postgres psql -c "CREATE ROLE $DB_USER WITH LOGIN PASSWORD '$DB_PASS';"
$STD sudo -u postgres psql -c "CREATE DATABASE $DB_NAME WITH OWNER $DB_USER TEMPLATE template0;"
{
echo "Koillection Credentials"
echo "Koillection Database User: $DB_USER"
echo "Koillection Database Password: $DB_PASS"
echo "Koillection Database Name: $DB_NAME"
} >> ~/koillection.creds
msg_ok "Set up PostgreSQL"

msg_info "Setting up Node.js/Yarn"
mkdir -p /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" >/etc/apt/sources.list.d/nodesource.list
$STD apt-get update
$STD apt-get install -y nodejs
$STD npm install -g npm@latest
$STD npm install -g yarn
msg_ok "Installed Node.js/Yarn"

msg_info "Installing Koillection"
RELEASE=$(curl -s https://api.github.com/repos/benjaminjonard/koillection/releases/latest | grep "tag_name" | awk '{print substr($2, 2, length($2)-3) }')
cd /opt
wget -q "https://github.com/benjaminjonard/koillection/archive/refs/tags/${RELEASE}.zip"
unzip -q "${RELEASE}.zip"
mv "/opt/koillection-${RELEASE}" /opt/koillection
cd /opt/koillection
cp /opt/koillection/.env /opt/koillection/.env.local
sed -i -e "s|^DB_DRIVER=.*|DB_DRIVER=pdo_pgsql|" \
       -e "s|^DB_HOST=.*|DB_HOST=localhost|" \
       -e "s|^DB_USER=.*|DB_USER=${DB_USER}|" \
       -e "s|^DB_PASSWORD=.*|DB_PASSWORD=${DB_PASS}|" \
       -e "s|^DB_NAME=.*|DB_PASSWORD=${DB_NAME}|" \
       /opt/koillection/.env
$STD composer install --no-dev -o --no-interaction
$STD php bin/console doctrine:migrations:migrate
$STD php bin/console app:translations:dump
cd assets/
$STD yarn install
$STD yarn build 
chown -R www-data:www-data /opt/koillection
echo "${RELEASE}" >/opt/${APPLICATION}_version.txt
msg_ok "Installed Koillection"

msg_info "Creating Service"
cat <<EOF >/etc/apache2/sites-available/koillection.conf
<VirtualHost *:80>
    ServerName koillection
    DocumentRoot /opt/koillection/public
    <Directory /opt/koillection/public>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog /var/log/apache2/koillection_error.log
    CustomLog /var/log/apache2/koillection_access.log combined
</VirtualHost>
EOF
$STD a2ensite koillection
$STD a2enmod rewrite
$STD a2dissite 000-default.conf
$STD systemctl reload apache2
msg_ok "Created Service"

motd_ssh
customize

msg_info "Cleaning up"
rm -rf "/opt/koillection-v${RELEASE}.tar.bz2"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
