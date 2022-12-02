
#!/bin/bash

set -e

######## General checks #########

# exit with error status code if user is not root
if [[ $EUID -ne 0 ]]; then
  echo "* This script must be executed with root privileges (sudo)." 1>&2
  exit 1
fi

# check for curl
if ! [ -x "$(command -v curl)" ]; then
  echo "* curl is required in order for this script to work."
  echo "* install using apt UBUNTU 18 adn 20 ONLY"
  exit 1
fi

########## Variables ############

# versioning
GITHUB_SOURCE="master"
SCRIPT_RELEASE="main"

FQDN=""
APP_PORT="3070"
# Default MySQL credentials
MYSQL_DB="faliactyl"
MYSQL_USER="faliactyl"
MYSQL_PASSWORD=""

# Environment
email=""

# Initial admin account
user_email=""
user_username=""
user_firstname=""
user_lastname=""
user_password=""

# Assume SSL, will fetch different config if true
SSL_AVAILABLE=false
ASSUME_SSL=false
CONFIGURE_LETSENCRYPT=false

# ufw firewall
CONFIGURE_UFW=false

# firewall_cmd
CONFIGURE_FIREWALL_CMD=false

# firewall status
CONFIGURE_FIREWALL=false

# input validation regex's
email_regex="^(([A-Za-z0-9]+((\.|\-|\_|\+)?[A-Za-z0-9]?)*[A-Za-z0-9]+)|[A-Za-z0-9]+)@(([A-Za-z0-9]+)+((\.|\-|\_)?([A-Za-z0-9]+)+)*)+\.([A-Za-z]{2,})+$"

####### Version checking ########

# faliactyl version
echo "* Retrieving release information.."
VERSION=$(curl "https://raw.githubusercontent.com/hct-dev/faliactyl/main/release")
echo "* Release is $VERSION"
####### lib func #######

array_contains_element() {
  local e match="$1"
  shift
  for e; do [[ "$e" == "$match" ]] && return 0; done
  return 1
}

valid_email() {
  [[ $1 =~ ${email_regex} ]]
}

invalid_ip() {
  ip route get "$1" >/dev/null 2>&1
  echo $?
}

####### Visual functions ########

print_error() {
  COLOR_RED='\033[0;31m'
  COLOR_NC='\033[0m'

  echo ""
  echo -e "* ${COLOR_RED}ERROR${COLOR_NC}: $1"
  echo ""
}

print_warning() {
  COLOR_YELLOW='\033[1;33m'
  COLOR_NC='\033[0m'
  echo ""
  echo -e "* ${COLOR_YELLOW}WARNING${COLOR_NC}: $1"
  echo ""
}

print_brake() {
  for ((n = 0; n < $1; n++)); do
    echo -n "#"
  done
  echo ""
}

hyperlink() {
  echo -e "\e]8;;${1}\a${1}\e]8;;\a"
}

##### User input functions ######

required_input() {
  local __resultvar=$1
  local result=''

  while [ -z "$result" ]; do
    echo -n "* ${2}"
    read -r result

    if [ -z "${3}" ]; then
      [ -z "$result" ] && result="${4}"
    else
      [ -z "$result" ] && print_error "${3}"
    fi
  done

  eval "$__resultvar="'$result'""
}

email_input() {
  local __resultvar=$1
  local result=''

  while ! valid_email "$result"; do
    echo -n "* ${2}"
    read -r result

    valid_email "$result" || print_error "${3}"
  done

  eval "$__resultvar="'$result'""
}

password_input() {
  local __resultvar=$1
  local result=''
  local default="$4"

  while [ -z "$result" ]; do
    echo -n "* ${2}"

    # modified from https://stackoverflow.com/a/22940001
    while IFS= read -r -s -n1 char; do
      [[ -z $char ]] && {
        printf '\n'
        break
      }                               # ENTER pressed; output \n and break.
      if [[ $char == $'\x7f' ]]; then # backspace was pressed
        # Only if variable is not empty
        if [ -n "$result" ]; then
          # Remove last char from output variable.
          [[ -n $result ]] && result=${result%?}
          # Erase '*' to the left.
          printf '\b \b'
        fi
      else
        # Add typed char to output variable.
        result+=$char
        # Print '*' in its stead.
        printf '*'
      fi
    done
    [ -z "$result" ] && [ -n "$default" ] && result="$default"
    [ -z "$result" ] && print_error "${3}"
  done

  eval "$__resultvar="'$result'""
}

ask_letsencrypt() {
  if [ "$CONFIGURE_UFW" == false ] && [ "$CONFIGURE_FIREWALL_CMD" == false ]; then
    print_warning "Let's Encrypt requires port 80/443 to be opened! You have opted out of the automatic firewall configuration; use this at your own risk (if port 80/443 is closed, the script will fail)!"
  fi

  echo -e -n "* Do you want to automatically configure HTTPS using Let's Encrypt? (y/N): "
  read -r CONFIRM_SSL

  if [[ "$CONFIRM_SSL" =~ [Yy] ]]; then
    CONFIGURE_LETSENCRYPT=true
    ASSUME_SSL=false
  fi
}

ask_assume_ssl() {
  echo "* Let's Encrypt is not going to be automatically configured by this script (user opted out)."
  echo "* You can 'assume' Let's Encrypt, which means the script will download a nginx configuration that is configured to use a Let's Encrypt certificate but the script won't obtain the certificate for you."
  echo "* If you assume SSL and do not obtain the certificate, your installation will not work."
  echo -n "* Assume SSL or not? (y/N): "
  read -r ASSUME_SSL_INPUT

  [[ "$ASSUME_SSL_INPUT" =~ [Yy] ]] && ASSUME_SSL=true
  true
}

check_FQDN_SSL() {
  if [[ $(invalid_ip "$FQDN") == 1 && $FQDN != 'localhost' ]]; then
    SSL_AVAILABLE=true
  else
    print_warning "* Let's Encrypt will not be available for IP addresses."
    echo "* To use Let's Encrypt, you must use a valid domain name."
  fi
}

ask_firewall() {
  case "$OS" in
  ubuntu | debian)
    echo -e -n "* Do you want to automatically configure UFW (firewall)? (y/N): "
    read -r CONFIRM_UFW

    if [[ "$CONFIRM_UFW" =~ [Yy] ]]; then
      CONFIGURE_UFW=true
      CONFIGURE_FIREWALL=true
    fi
    ;;
  centos)
    echo -e -n "* Do you want to automatically configure firewall-cmd (firewall)? (y/N): "
    read -r CONFIRM_FIREWALL_CMD

    if [[ "$CONFIRM_FIREWALL_CMD" =~ [Yy] ]]; then
      CONFIGURE_FIREWALL_CMD=true
      CONFIGURE_FIREWALL=true
    fi
    ;;
  esac
}

####### OS check funtions #######

detect_distro() {
  if [ -f /etc/os-release ]; then
    # freedesktop.org and systemd
    . /etc/os-release
    OS=$(echo "$ID" | awk '{print tolower($0)}')
    OS_VER=$VERSION_ID
  elif [ -f /etc/lsb-release ]; then
    # For some versions of Debian/Ubuntu without lsb_release command
    . /etc/lsb-release
    OS=$(echo "$DISTRIB_ID" | awk '{print tolower($0)}')
    OS_VER=$DISTRIB_RELEASE
  elif [ -f /etc/debian_version ]; then
    # Older Debian/Ubuntu/etc.
    OS="debian"
    OS_VER=$(cat /etc/debian_version)
  else
    # Fall back to uname, e.g. "Linux <version>", also works for BSD, etc.
    OS=$(uname -s)
    OS_VER=$(uname -r)
  fi

  OS=$(echo "$OS" | awk '{print tolower($0)}')
  OS_VER_MAJOR=$(echo "$OS_VER" | cut -d. -f1)
}

check_os_comp() {
  CPU_ARCHITECTURE=$(uname -m)
  if [ "${CPU_ARCHITECTURE}" != "x86_64" ]; then # check the architecture
    print_warning "Detected CPU architecture $CPU_ARCHITECTURE"
    print_warning "Using any other architecture than 64 bit (x86_64) will cause problems."

    echo -e -n "* Are you sure you want to proceed? (y/N): "
    read -r choice

    if [[ ! "$choice" =~ [Yy] ]]; then
      print_error "Installation aborted!"
      exit 1
    fi
  fi

  case "$OS" in
  ubuntu)
    [ "$OS_VER_MAJOR" == "18" ] && SUPPORTED=true
    [ "$OS_VER_MAJOR" == "20" ] && SUPPORTED=true
    ;;
  *)
    SUPPORTED=false
    ;;
  esac

  # exit if not supported
  if [ "$SUPPORTED" == true ]; then
    echo "* $OS $OS_VER is supported."
  else
    echo "* $OS $OS_VER is not supported"
    print_error "Unsupported OS"
    exit 1
  fi
}

##### Main installation functions #####

# Install Node JS and RPM
install_software() {
  echo "* Installing software.."
  sudo apt update && sudo apt upgrade
  sudo apt install git
  curl -fsSL https://deb.nodesource.com/setup_16.x | sudo -E bash -
  sudo apt install -y nodejs
  echo "* software installed!"
}

# Download Faliactyl files
download() {
  echo "* Downloading Faliactyl Dashboard files .. "
  cd /var/www/ || exit
  wget https://raw.githubusercontent.com/hct-dev/faliactyl/main/Faliactyl-Release-$VERSION.zip
  unzip Faliactyl-Release-$VERSION.zip
  cd faliactyl && npm install
  echo "* Downloaded Faliactyl files & installed software dependencies!"
}

# Create a databse with user
create_database() {
  if [ "$OS" == "centos" ]; then
    # secure MariaDB
    echo "* MariaDB secure installation. The following are safe defaults."
    echo "* Set root password? [Y/n] Y"
    echo "* Remove anonymous users? [Y/n] Y"
    echo "* Disallow root login remotely? [Y/n] Y"
    echo "* Remove test database and access to it? [Y/n] Y"
    echo "* Reload privilege tables now? [Y/n] Y"
    echo "*"

    [ "$OS_VER_MAJOR" == "7" ] && mariadb-secure-installation
    [ "$OS_VER_MAJOR" == "8" ] && mysql_secure_installation

    echo "* The script should have asked you to set the MySQL root password earlier (not to be confused with the pterodactyl database user password)"
    echo "* MySQL will now ask you to enter the password before each command."

    echo "* Create MySQL user."
    mysql -u root -p -e "CREATE USER '${MYSQL_USER}'@'127.0.0.1' IDENTIFIED BY '${MYSQL_PASSWORD}';"

    echo "* Create database."
    mysql -u root -p -e "CREATE DATABASE ${MYSQL_DB};"

    echo "* Grant privileges."
    mysql -u root -p -e "GRANT ALL PRIVILEGES ON ${MYSQL_DB}.* TO '${MYSQL_USER}'@'127.0.0.1' WITH GRANT OPTION;"

    echo "* Flush privileges."
    mysql -u root -p -e "FLUSH PRIVILEGES;"
  else
    echo "* Performing MySQL queries.."

    echo "* Creating MySQL user.."
    mysql -u root -e "CREATE USER '${MYSQL_USER}'@'127.0.0.1' IDENTIFIED BY '${MYSQL_PASSWORD}';"

    echo "* Creating database.."
    mysql -u root -e "CREATE DATABASE ${MYSQL_DB};"

    echo "* Granting privileges.."
    mysql -u root -e "GRANT ALL PRIVILEGES ON ${MYSQL_DB}.* TO '${MYSQL_USER}'@'127.0.0.1' WITH GRANT OPTION;"

    echo "* Flushing privileges.."
    mysql -u root -e "FLUSH PRIVILEGES;"

    echo "* MySQL database created & configured! Please Manually Add it via /var/www/faliactyl/settings.yml"
  fi
}

# set the correct folder permissions depending on OS and webserver
set_folder_permissions() {
  # if os is ubuntu or debian, we do this
  case "$OS" in
  debian | ubuntu)
    chown -R www-data:www-data ./*
    ;;
  esac
}

# insert cronjob
#insert_cronjob() {
#  echo "* Installing cronjob.. "
#
#  crontab -l | {
#    cat
#    echo "* * * * * php /var/www/pterodactyl/artisan schedule:run >> /dev/null 2>&1"
#  } | crontab -
#
#  echo "* Cronjob installed!"
#}

install_faliactyl_service() {
  echo "* Installing faliactyl service.."

  cp /var/www/faliactyl/configs/faliactyl.service /etc/systemd/system/faliactyl.service
  
  case "$OS" in
  debian | ubuntu)
    sed -i -e "s@<user>@www-data@g" /etc/systemd/system/faliactyl.service
    ;;
  esac

  systemctl enable faliactyl.service
  systemctl start faliactyl

  echo "* Installed Faliactyl Service!"
}

##### OS specific install functions #####

apt_update() {
  apt update -q -y && apt upgrade -y
}

enable_services_debian_based() {
  systemctl enable mariadb
  systemctl start mariadb
}

selinux_allow() {
  setsebool -P httpd_can_network_connect 1 || true # these commands can fail OK
  setsebool -P httpd_execmem 1 || true
  setsebool -P httpd_unified 1 || true
}

ubuntu_dep() {
  echo "* Installing dependencies for Ubuntu 18 and 20.."

  # Add "add-apt-repository" command
  apt -y install software-properties-common curl apt-transport-https ca-certificates gnupg

  # Ubuntu universe repo
  add-apt-repository universe

  # Add the MariaDB repo (bionic has mariadb version 10.1 and we need newer than that)
  curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | sudo bash

  # Update repositories list
  apt_update

  # Install Dependencies
  apt -y install mariadb-server nginx tar unzip cron

  # Enable services
  enable_services_debian_based

  echo "* Dependencies for Ubuntu installed!"
}

##### OTHER OS SPECIFIC FUNCTIONS #####
firewall_ufw() {
  apt install -y ufw

  echo -e "\n* Enabling Uncomplicated Firewall (UFW)"
  echo "* Opening port 22 (SSH), 80 (HTTP) and 443 (HTTPS)"

  # pointing to /dev/null silences the command output
  ufw allow ssh >/dev/null
  ufw allow http >/dev/null
  ufw allow https >/dev/null
  ufw allow 3070 >/dev/null

  ufw --force enable
  ufw --force reload
  ufw status numbered | sed '/v6/d'
}

letsencrypt() {
  FAILED=false

  # Install certbot
  case "$OS" in
  debian | ubuntu)
    apt-get -y install certbot python3-certbot-nginx
    ;;
  esac

  # Obtain certificate
  certbot --nginx --redirect --no-eff-email --email "$email" -d "$FQDN" || FAILED=true

  # Check if it succeded
  if [ ! -d "/etc/letsencrypt/live/$FQDN/" ] || [ "$FAILED" == true ]; then
    print_warning "The process of obtaining a Let's Encrypt certificate failed!"
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
  fi
}

##### WEBSERVER CONFIGURATION FUNCTIONS #####

configure_nginx() {
  echo "* Configuring nginx .."

  if [ $ASSUME_SSL == true ] && [ $CONFIGURE_LETSENCRYPT == false ]; then
    DL_FILE="nginx_ssl.conf"
  else
    DL_FILE="nginx.conf"
  fi

# remove default config
rm -rf /etc/nginx/sites-enabled/default

cp /var/www/faliactyl/configs/faliactyl.conf /etc/nginx/sites-available/faliactyl.conf

# replace all <domain> places with the correct domain
sed -i -e "s@<domain>@${FQDN}@g" /etc/nginx/sites-available/faliactyl.conf

# replace all <port> places with the correct domain
sed -i -e "s@<port>@${APP_PORT}@g" /etc/nginx/sites-available/faliactyl.conf

    # enable pterodactyl
    ln -sf /etc/nginx/sites-available/faliactyl.conf /etc/nginx/sites-enabled/faliactyl.conf

  if [ "$ASSUME_SSL" == false ] && [ "$CONFIGURE_LETSENCRYPT" == false ]; then
    systemctl restart nginx
  fi

  echo "* nginx configured!"
}

##### MAIN FUNCTIONS #####


perform_install() {
  echo "* Starting installation.. this might take a while!"

  ubuntu_dep
  install_composer
  download
  create_database
  set_folder_permissions
  install_faliactyl_service
  configure_nginx
  [ "$CONFIGURE_LETSENCRYPT" == true ] && letsencrypt
  true
}

main() {
  # check if we can detect an already existing installation
  if [ -d "/var/www/Faliactyl" ]; then
    print_warning "The script has detected that you already have Faliactyl on your system! You cannot run the script multiple times, it will fail!"
    echo -e -n "* Are you sure you want to proceed? (y/N): "
    read -r CONFIRM_PROCEED
    if [[ ! "$CONFIRM_PROCEED" =~ [Yy] ]]; then
      print_error "Installation aborted!"
      exit 1
    fi
  fi

  # detect distro
  detect_distro

  print_brake 70
  echo "* Faliactyl Free Edition installation script @ $SCRIPT_RELEASE"
  echo "*"
  echo "* Copyright (C) 2022, Hydra Cloud LLC"
  echo "*"
  echo "* This script is associated with the official Faliactyl Project."
  echo "*"
  echo "* Running $OS version $OS_VER."
  echo "* Latest Faliactyl is $VERSION"
  print_brake 70

  # checks if the system is compatible with this installation script
  check_os_comp

  # set database credentials
  print_brake 72
  echo "* Database configuration."
  echo ""
  echo "* This will be the credentials used for communication between the MySQL"
  echo "* database and the panel. You do not need to create the database"
  echo "* before running this script, the script will do that for you."
  echo ""

  MYSQL_DB="-"
  while [[ "$MYSQL_DB" == *"-"* ]]; do
    required_input MYSQL_DB "Database name (panel): " "" "panel"
    [[ "$MYSQL_DB" == *"-"* ]] && print_error "Database name cannot contain hyphens"
  done

  MYSQL_USER="-"
  while [[ "$MYSQL_USER" == *"-"* ]]; do
    required_input MYSQL_USER "Database username (pterodactyl): " "" "pterodactyl"
    [[ "$MYSQL_USER" == *"-"* ]] && print_error "Database user cannot contain hyphens"
  done

  # MySQL password input
  rand_pw=$(
    tr -dc 'A-Za-z0-9!"#$%&()*+,-./:;<=>?@[\]^_`{|}~' </dev/urandom | head -c 64
    echo
  )
  password_input MYSQL_PASSWORD "Password (press enter to use randomly generated password): " "MySQL password cannot be empty" "$rand_pw"

  email_input email "Provide the email address that will be used to configure Let's Encrypt: " "Email cannot be empty or invalid"

  print_brake 72

  # set FQDN
  while [ -z "$FQDN" ]; do
    echo -n "* Set the FQDN of this panel (panel.example.com): "
    read -r FQDN
    [ -z "$FQDN" ] && print_error "FQDN cannot be empty"
  done

  # Check if SSL is available
  check_FQDN_SSL

  # Ask if firewall is needed
  ask_firewall

  # Only ask about SSL if it is available
  if [ "$SSL_AVAILABLE" == true ]; then
    # Ask if letsencrypt is needed
    ask_letsencrypt
    # If it's already true, this should be a no-brainer
    [ "$CONFIGURE_LETSENCRYPT" == false ] && ask_assume_ssl
  fi

  # verify FQDN if user has selected to assume SSL or configure Let's Encrypt
  [ "$CONFIGURE_LETSENCRYPT" == true ] || [ "$ASSUME_SSL" == true ] && bash <(curl -s $GITHUB_BASE_URL/lib/verify-fqdn.sh) "$FQDN" "$OS"

  # summary
  summary

  # confirm installation
  echo -e -n "\n* Initial configuration completed. Continue with installation? (y/N): "
  read -r CONFIRM
  if [[ "$CONFIRM" =~ [Yy] ]]; then
    perform_install
  else
    # run welcome script again
    print_error "Installation aborted."
    exit 1
  fi
}

summary() {
  print_brake 62
  echo "* Faliactyl Free Edition $VERSION with nginx on $OS"
  echo "* Database name: $MYSQL_DB"
  echo "* Database user: $MYSQL_USER"
  echo "* Database password: (censored)"
  echo "* Hostname/FQDN: $FQDN"
  echo "* Configure Firewall? $CONFIGURE_FIREWALL"
  echo "* Configure Let's Encrypt? $CONFIGURE_LETSENCRYPT"
  echo "* Assume SSL? $ASSUME_SSL"
  print_brake 62
}

goodbye() {
  print_brake 62
  echo "* Faliacyl installation completed"
  echo "*"

  [ "$CONFIGURE_LETSENCRYPT" == true ] && echo "* Your panel should be accessible from $(hyperlink "$app_url")"
  [ "$ASSUME_SSL" == true ] && [ "$CONFIGURE_LETSENCRYPT" == false ] && echo "* You have opted in to use SSL, but not via Let's Encrypt automatically. Your panel will not work until SSL has been configured."
  [ "$ASSUME_SSL" == false ] && [ "$CONFIGURE_LETSENCRYPT" == false ] && echo "* Your panel should be accessible from $(hyperlink "$app_url")"

  echo "*"
  echo "* Installation is using nginx on $OS"
  echo "* Thank you for using this script."
  [ "$CONFIGURE_FIREWALL" == false ] && echo -e "* ${COLOR_RED}Note${COLOR_NC}: If you haven't configured the firewall: 80/443 (HTTP/HTTPS) is required to be open!"
  print_brake 62
}

# run script
main
goodbye
