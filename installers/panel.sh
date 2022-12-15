#!/bin/bash

set -e

# Check if script is loaded, load if not or fail otherwise.
fn_exists() { declare -F "$1" >/dev/null; }
if ! fn_exists lib_loaded; then
  # shellcheck source=lib/lib.sh
  source /tmp/lib.sh || source <(curl -sSL "$GITHUB_BASE_URL/$GITHUB_SOURCE"/lib/lib.sh)
  ! fn_exists lib_loaded && echo "* ERROR: Could not load lib script" && exit 1
fi

# ------------------ Variables ----------------- #

# Domain name / IP
FQDN="${FQDN:-localhost}"

# Default MySQL credentials
MYSQL_DB="${MYSQL_DB:-faliactyl}"
MYSQL_USER="${MYSQL_USER:-faliactyl}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-$(gen_passwd 64)}"

# Environment
timezone="${timezone:-Europe/Stockholm}"

# Assume SSL, will fetch different config if true
ASSUME_SSL="${ASSUME_SSL:-false}"
CONFIGURE_LETSENCRYPT="${CONFIGURE_LETSENCRYPT:-false}"

# Firewall
CONFIGURE_FIREWALL="${CONFIGURE_FIREWALL:-false}"

# Must be assigned to work, no default values
email="${email:-}"
if [[ -z "${email}" ]]; then
  error "Email is required"
  exit 1
fi
'''
user_email="${user_email:-}"
user_username="${user_username:-}"
user_firstname="${user_firstname:-}"
user_lastname="${user_lastname:-}"
user_password="${user_password:-}"

if [[ -z "${email}" ]]; then
  error "Email is required"
  exit 1
fi

if [[ -z "${user_email}" ]]; then
  error "User email is required"
  exit 1
fi

if [[ -z "${user_username}" ]]; then
  error "User username is required"
  exit 1
fi

if [[ -z "${user_firstname}" ]]; then
  error "User firstname is required"
  exit 1
fi

if [[ -z "${user_lastname}" ]]; then
  error "User lastname is required"
  exit 1
fi

if [[ -z "${user_password}" ]]; then
  error "User password is required"
  exit 1
fi
'''
# --------- Main installation functions -------- #

install_composer() {
  output "Installing composer.."
  curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
  success "Composer installed!"
}

install_node() {
  output "Installing Node JS.."
  curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
  install_packages "nodejs"
  success "Composer installed!"
}
fali_dl() {
  output "Downloading Faliactyl files .. "
  mkdir -p /var/www
  cd /var/www || exit
  wget https://raw.githubusercontent.com/hct-dev/faliactyl/main/Faliactyl-Release-V$VERSION.zip
  unzip Faliactyl-Release-V$VERSION.zip
  rm Faliactyl-Release-V$VERSION.zip
  cd faliactyl
  chmod -R 755 storage/*
  success "Downloaded Faliactyl files!"
}

install_composer_deps() {
  output "Installing composer dependencies.."
  [ "$OS" == "rocky" ] || [ "$OS" == "almalinux" ] && export PATH=/usr/local/bin:$PATH
  COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader
  success "Installed composer dependencies!"
}

# Configure environment
'''
configure() {
  output "Configuring environment.."

  local app_url="http://$FQDN"
  [ "$ASSUME_SSL" == true ] && app_url="https://$FQDN"
  [ "$CONFIGURE_LETSENCRYPT" == true ] && app_url="https://$FQDN"

  # Generate encryption key
  php artisan key:generate --force

  # Fill in environment:setup automatically
  php artisan p:environment:setup \
    --author="$email" \
    --url="$app_url" \
    --timezone="$timezone" \
    --cache="redis" \
    --session="redis" \
    --queue="redis" \
    --redis-host="localhost" \
    --redis-pass="null" \
    --redis-port="6379" \
    --settings-ui=true

  # Fill in environment:database credentials automatically
  php artisan p:environment:database \
    --host="127.0.0.1" \
    --port="3306" \
    --database="$MYSQL_DB" \
    --username="$MYSQL_USER" \
    --password="$MYSQL_PASSWORD"

  # configures database
  php artisan migrate --seed --force

  # Create user account
  php artisan p:user:make \
    --email="$user_email" \
    --username="$user_username" \
    --name-first="$user_firstname" \
    --name-last="$user_lastname" \
    --password="$user_password" \
    --admin=1

  success "Configured environment!"
}

insert_cronjob() {
  output "Installing cronjob.. "

  crontab -l | {
    cat
    output "* * * * php /var/www/pterodactyl/artisan schedule:run >> /dev/null 2>&1"
  } | crontab -

  success "Cronjob installed!"
}

install_faliactyl_service() {
  output "Installing Faliactyl service.."

  curl -o /etc/systemd/system/faliactyl.service "$GITHUB_URL"/configs/faliactyl.service

  case "$OS" in
  debian | ubuntu)
    sed -i -e "s@<user>@www-data@g" /etc/systemd/system/faliactyl.service
    ;;
  rocky | almalinux)
    sed -i -e "s@<user>@nginx@g" /etc/systemd/system/faliactyl.service
    ;;
  esac

  systemctl enable faliactyl.service
  systemctl start faliactyl

  success "Installed Faliactyl Service!"
}
'''

# -------- OS specific install functions ------- #

enable_services() {
  case "$OS" in
  ubuntu | debian)
    systemctl enable redis-server
    systemctl start redis-server
    ;;
  rocky | almalinux)
    systemctl enable redis
    systemctl start redis
    ;;
  esac
  systemctl enable nginx
  systemctl enable mariadb
  systemctl start mariadb
}

selinux_allow() {
  setsebool -P httpd_can_network_connect 1 || true # these commands can fail OK
  setsebool -P httpd_execmem 1 || true
  setsebool -P httpd_unified 1 || true
}

ubuntu_dep() {
  # Install deps for adding repos
  install_packages "software-properties-common apt-transport-https ca-certificates gnupg"

  # Add Ubuntu universe repo
  add-apt-repository universe -y

  # Add the MariaDB repo (bionic has mariadb version 10.1 and we need newer than that)
  [ "$OS_VER_MAJOR" == "18" ] && curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | bash

  # Add PPA for PHP (we need 8.1)
  LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php
}

debian_dep() {
  # Install deps for adding repos
  install_packages "dirmngr ca-certificates apt-transport-https lsb-release"

  # Install PHP 8.1 using sury's repo
  curl -o /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
  echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/php.list
}

alma_rocky_dep() {
  # SELinux tools
  install_packages "policycoreutils selinux-policy selinux-policy-targeted \
    setroubleshoot-server setools setools-console mcstrans"

  # add remi repo (php8.1)
  install_packages "epel-release http://rpms.remirepo.net/enterprise/remi-release-$OS_VER_MAJOR.rpm"
  dnf module enable -y php:remi-8.1
}

dep_install() {
  output "Installing dependencies for $OS $OS_VER..."

  # Update repos before installing
  update_repos

  [ "$CONFIGURE_FIREWALL" == true ] && install_firewall && firewall_ports

  case "$OS" in
  ubuntu | debian)
    [ "$OS" == "ubuntu" ] && ubuntu_dep
    [ "$OS" == "debian" ] && debian_dep

    update_repos

    # Install dependencies
    install_packages " php-curl php8.1 php8.1-{cli,common,gd,mysql,mbstring,bcmath,xml,curl,zip} \
      mariadb-common mariadb-server mariadb-client \
      nginx \
      redis-server \
      zip unzip tar \
      git cron"

    [ "$CONFIGURE_LETSENCRYPT" == true ] && install_packages "certbot python3-certbot-nginx"

    ;;
  rocky | almalinux)
    alma_rocky_dep

    # Install dependencies
    install_packages "php php-{common,cli,json,mysqlnd,mcrypt,gd,mbstring,pdo,zip,bcmath,dom,opcache,posix} \
      mariadb mariadb-server \
      nginx \
      redis \
      zip unzip tar \
      git cronie"

    [ "$CONFIGURE_LETSENCRYPT" == true ] && install_packages "certbot python3-certbot-nginx"

    # Allow nginx
    selinux_allow
    ;;
  esac

  enable_services

  success "Dependencies installed!"
}

# --------------- Other functions -------------- #

firewall_ports() {
  output "Opening ports: 22 (SSH), 80 (HTTP) 443 (HTTPS) 3070 (Faliactyl)"

  firewall_allow_ports "22 80 443 3070"

  success "Firewall ports opened!"
}

letsencrypt() {
  FAILED=false

  output "Configuring Let's Encrypt..."

  # Obtain certificate
  certbot --nginx --redirect --no-eff-email --email "$email" -d "$FQDN" || FAILED=true

  # Check if it succeded
  if [ ! -d "/etc/letsencrypt/live/$FQDN/" ] || [ "$FAILED" == true ]; then
    warning "The process of obtaining a Let's Encrypt certificate failed!"
    echo -n "* Still assume SSL? (y/N): "
    read -r CONFIGURE_SSL

    if [[ "$CONFIGURE_SSL" =~ [Yy] ]]; then
      ASSUME_SSL=true
      CONFIGURE_LETSENCRYPT=false
      configure_nginx
    else
      ASSUME_SSL=false
      CONFIGURE_LETSENCRYPT=false
    fi
  else
    success "The process of obtaining a Let's Encrypt certificate succeeded!"
  fi
}

# ------ Webserver configuration functions ----- #

configure_nginx() {
  output "Configuring nginx .."

  if [ $ASSUME_SSL == true ] && [ $CONFIGURE_LETSENCRYPT == false ]; then
    DL_FILE="nginx_ssl.conf"
  else
    DL_FILE="nginx.conf"
  fi

  case "$OS" in
  ubuntu | debian)
    CONFIG_PATH_AVAIL="/etc/nginx/sites-available"
    CONFIG_PATH_ENABL="/etc/nginx/sites-enabled"
    ;;
  rocky | almalinux)
    CONFIG_PATH_AVAIL="/etc/nginx/conf.d"
    CONFIG_PATH_ENABL="$CONFIG_PATH_AVAIL"
    ;;
  esac

  rm -rf $CONFIG_PATH_ENABL/default

  curl -o $CONFIG_PATH_AVAIL/pterodactyl.conf "$GITHUB_URL"/configs/$DL_FILE

  sed -i -e "s@<domain>@${FQDN}@g" $CONFIG_PATH_AVAIL/pterodactyl.conf

  case "$OS" in
  ubuntu | debian)
    ln -sf $CONFIG_PATH_AVAIL/pterodactyl.conf $CONFIG_PATH_ENABL/pterodactyl.conf
    ;;
  esac

  if [ "$ASSUME_SSL" == false ] && [ "$CONFIGURE_LETSENCRYPT" == false ]; then
    systemctl restart nginx
  fi

  success "Nginx configured!"
}

# --------------- Main functions --------------- #

perform_install() {
  output "Starting installation.. this might take a while!"
  dep_install
  install_composer
  install_node
  fali_dl
  install_composer_deps
  create_db_user "$MYSQL_USER" "$MYSQL_PASSWORD"
  create_db "$MYSQL_DB" "$MYSQL_USER"
  #configure
  #insert_cronjob
  install_pteroq
  configure_nginx
  [ "$CONFIGURE_LETSENCRYPT" == true ] && letsencrypt

  return 0
}

# ------------------- Install ------------------ #

perform_install
rm lib.sh