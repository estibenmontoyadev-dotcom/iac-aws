#!/bin/bash
# Installs Apache + PHP + MariaDB + Joomla on Amazon Linux 2023.
# Log: /var/log/user-data.log
set -euxo pipefail
exec > >(tee /var/log/user-data.log) 2>&1

DB_NAME='${db_name}'
DB_USER='${db_username}'
DB_PASS='${db_password}'
JOOMLA_VERSION='${joomla_version}'
SITE_NAME='${site_name}'
ADMIN_USER='${admin_username}'
ADMIN_EMAIL='${admin_email}'
ADMIN_PASS='${admin_password}'
WEB_ROOT=/var/www/html

# Swap: t3.micro has only 1 GB of RAM for Apache + PHP + MariaDB
if [ ! -f /swapfile ]; then
  dd if=/dev/zero of=/swapfile bs=1M count=1024
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile swap swap defaults 0 0' >> /etc/fstab
fi

dnf update -y
# Joomla 6 requires PHP 8.3 or newer
dnf install -y httpd unzip php8.3 php8.3-fpm php8.3-mysqlnd php8.3-gd php8.3-mbstring php8.3-xml php8.3-intl php8.3-zip mariadb105-server

systemctl enable --now mariadb

mysql <<SQL
CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost';
DELETE FROM mysql.user WHERE User='';
DROP DATABASE IF EXISTS test;
FLUSH PRIVILEGES;
SQL

# Joomla (installed from the CLI, no web installer needed)
if [ ! -f "$WEB_ROOT/configuration.php" ]; then
  rm -f "$WEB_ROOT/index.html"
  curl -fsSL -o /tmp/joomla.zip \
    "https://github.com/joomla/joomla-cms/releases/download/$JOOMLA_VERSION/Joomla_$JOOMLA_VERSION-Stable-Full_Package.zip"
  unzip -q /tmp/joomla.zip -d "$WEB_ROOT"
  rm -f /tmp/joomla.zip

  cd "$WEB_ROOT"
  php -d memory_limit=512M installation/joomla.php install \
    --site-name="$SITE_NAME" \
    --admin-user="Administrador" \
    --admin-username="$ADMIN_USER" \
    --admin-password="$ADMIN_PASS" \
    --admin-email="$ADMIN_EMAIL" \
    --db-type=mysqli \
    --db-host=localhost \
    --db-name="$DB_NAME" \
    --db-user="$DB_USER" \
    --db-pass="$DB_PASS" \
    --db-prefix=jos_ \
    --db-encryption=0
fi

chown -R apache:apache "$WEB_ROOT"
find "$WEB_ROOT" -type d -exec chmod 755 {} \;
find "$WEB_ROOT" -type f -exec chmod 644 {} \;
chmod 640 "$WEB_ROOT/configuration.php"

# Allow SEF URLs (.htaccess)
cat > /etc/httpd/conf.d/joomla.conf <<CONF
<Directory "$WEB_ROOT">
    AllowOverride All
</Directory>
CONF

systemctl enable --now php-fpm
systemctl enable --now httpd
systemctl restart php-fpm httpd

echo "Joomla installation finished"
