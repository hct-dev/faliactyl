#!/bin/bash

set -e

# Check if script is loaded, load if not or fail otherwise.
rm -rf /tmp/lib.sh
curl -sSL -o /tmp/lib.sh https://raw.githubusercontent.com/hct-dev/faliactyl/main/lib.sh
# shellcheck source=lib/lib.sh
source /tmp/lib.sh

# ------------------ Variables ----------------- #

# Install mariadb
export INSTALL_MARIADB=false

# Firewall
export CONFIGURE_FIREWALL=false

# SSL (Let's Encrypt)
export CONFIGURE_LETSENCRYPT=false
export FQDN=""
export EMAIL=""

# Database host
export CONFIGURE_DBHOST=false
export CONFIGURE_DB_FIREWALL=false
export MYSQL_DBHOST_HOST="127.0.0.1"
export MYSQL_DBHOST_USER="faliactyldbhost"
export MYSQL_DBHOST_PASSWORD=""

# ------------ User input functions ------------ #

ask_letsencrypt() {
  if [ "$CONFIGURE_UFW" == false ] && [ "$CONFIGURE_FIREWALL_CMD" == false ]; then
    warning "Let's Encrypt requires port 80/443 to be opened! You have opted out of the automatic firewall configuration; use this at your own risk (if port 80/443 is closed, the script will fail)!"
  fi

  warning "You cannot use Let's Encrypt with your hostname as an IP address! It must be a FQDN (e.g. node.example.org)."

  echo -e -n "* Do you want to automatically configure HTTPS using Let's Encrypt? (y/N): "
  read -r CONFIRM_SSL

  if [[ "$CONFIRM_SSL" =~ [Yy] ]]; then
    CONFIGURE_LETSENCRYPT=true
  fi
}

ask_database_user() {
  echo -n "* Do you want to automatically configure a user for database hosts? (y/N): "
  read -r CONFIRM_DBHOST

  if [[ "$CONFIRM_DBHOST" =~ [Yy] ]]; then
    ask_database_external
    CONFIGURE_DBHOST=true
  fi
}

ask_database_external() {
  echo -n "* Do you want to configure MySQL to be accessed externally? (y/N): "
  read -r CONFIRM_DBEXTERNAL

  if [[ "$CONFIRM_DBEXTERNAL" =~ [Yy] ]]; then
    echo -n "* Enter the panel address (blank for any address): "
    read -r CONFIRM_DBEXTERNAL_HOST
    if [ "$CONFIRM_DBEXTERNAL_HOST" == "" ]; then
      MYSQL_DBHOST_HOST="%"
    else
      MYSQL_DBHOST_HOST="$CONFIRM_DBEXTERNAL_HOST"
    fi
    [ "$CONFIGURE_FIREWALL" == true ] && ask_database_firewall
    return 0;
  fi
}

ask_database_firewall() {
  warning "Allow incoming traffic to port 3306 (MySQL) can potentially be a security risk, unless you know what you are doing!"
  echo -n "* Would you like to allow incoming traffic to port 3306? (y/N): "
  read -r CONFIRM_DB_FIREWALL
  if [[ "$CONFIRM_DB_FIREWALL" =~ [Yy] ]]; then
    CONFIGURE_DB_FIREWALL=true
  fi
}

####################
## MAIN FUNCTIONS ##
####################

main() {
  welcome "fwings"

  check_virt

  echo "* "
  echo "* The installer will install Docker, required dependencies for FWings"
  echo "* as well as FWings itself. But it's still required to create the node"
  echo "* on the faliactyl panel and then place the configuration file on the node manually after"
  echo "* the installation has finished. Read more about this process on the"
  echo "* official documentation: $(hyperlink 'https://faliactyl.tech/docs/install/V4/fwings')"
  echo "* "
  echo -e "* ${COLOR_RED}Note${COLOR_NC}: this script will not configure FWings automatically."
  echo -e "* ${COLOR_RED}Note${COLOR_NC}: this script will not enable swap (for docker)."
  print_brake 42

  ask_firewall CONFIGURE_FIREWALL

  ask_database_user

  if [ "$CONFIGURE_DBHOST" == true ]; then
    type mysql >/dev/null 2>&1 && HAS_MYSQL=true || HAS_MYSQL=false

    if [ "$HAS_MYSQL" == false ]; then
      INSTALL_MARIADB=true
    fi

    MYSQL_DBHOST_USER="-"
    while [[ "$MYSQL_DBHOST_USER" == *"-"* ]]; do
      required_input MYSQL_DBHOST_USER "Database host username (faliactyldbhost): " "" "faliactyldbhost"
      [[ "$MYSQL_DBHOST_USER" == *"-"* ]] && error "Database user cannot contain hyphens"
    done

    password_input MYSQL_DBHOST_PASSWORD "Database host password: " "Password cannot be empty"
  fi

  ask_letsencrypt

  if [ "$CONFIGURE_LETSENCRYPT" == true ]; then
    while [ -z "$FQDN" ]; do
      echo -n "* Set the FQDN to use for Let's Encrypt (node.example.com): "
      read -r FQDN

      ASK=false

      [ -z "$FQDN" ] && error "FQDN cannot be empty"                                                            # check if FQDN is empty
      bash <(curl -s "$GITHUB_URL"/lib/verify-fqdn.sh) "$FQDN" || ASK=true                                      # check if FQDN is valid
      [ -d "/etc/letsencrypt/live/$FQDN/" ] && error "A certificate with this FQDN already exists!" && ASK=true # check if cert exists

      [ "$ASK" == true ] && FQDN=""
      [ "$ASK" == true ] && echo -e -n "* Do you still want to automatically configure HTTPS using Let's Encrypt? (y/N): "
      [ "$ASK" == true ] && read -r CONFIRM_SSL

      if [[ ! "$CONFIRM_SSL" =~ [Yy] ]] && [ "$ASK" == true ]; then
        CONFIGURE_LETSENCRYPT=false
        FQDN=""
      fi
    done
  fi

  if [ "$CONFIGURE_LETSENCRYPT" == true ]; then
    # set EMAIL
    while ! valid_email "$EMAIL"; do
      echo -n "* Enter email address for Let's Encrypt: "
      read -r EMAIL

      valid_email "$EMAIL" || error "Email cannot be empty or invalid"
    done
  fi

  echo -n "* Proceed with installation? (y/N): "

  read -r CONFIRM
  if [[ "$CONFIRM" =~ [Yy] ]]; then
    run_installer "fwings"
  else
    error "Installation aborted."
    exit 1
  fi
}

function goodbye {
  echo ""
  print_brake 70
  echo "* FWings installation completed"
  echo "*"
  echo "* To continue, you need to configure FWings to run with your Faliactyl panel"
  echo "* Please refer to the official guide, $(hyperlink 'https://faliactyl.tech/docs/install/V4/fwings/configuration')"
  echo "* "
  echo "* You can either copy the configuration file from the panel manually to /etc/faliactyl/config.yml"
  echo "* "
  echo "* You can then start FWings manually to verify that it's working"
  echo "*"
  echo "* sudo fwings"
  echo "*"
  echo "* Once you have verified that it is working, use CTRL+C and then restart FWings as a service (runs in the background)"
  echo "*"
  echo "* systemctl restart fwings"
  echo "*"
  echo -e "* ${COLOR_RED}Note${COLOR_NC}: It is recommended to enable swap (for Docker, read more about it in official documentation)."
  [ "$CONFIGURE_FIREWALL" == false ] && echo -e "* ${COLOR_RED}Note${COLOR_NC}: If you haven't configured your firewall, ports 8080 and 2022 needs to be open."
  print_brake 70
  echo ""
}

# run script
main
goodbye