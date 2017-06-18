#!/bin/bash
################################################################################
# wizard - Install script to help you install zmbackup in your server. You can
#          simply ignore this file and move the files to the correctly place, but
#          the chance for this goes wrong is big. So, this script made everything
#          for you easy.
#
################################################################################
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
################################################################################
# SET INTERNAL VARIABLE
################################################################################

# Exit codes
ERR_OK="0"  		# No error (normal exit)
ERR_NOBKPDIR="1"  	# No backup directory could be found
ERR_NOROOT="2"  		# Script was run without root privileges
ERR_DEPNOTFOUND="3"  	# Missing dependency

# ZMBACKUP INSTALLATION PATH
ZMBKP_SRC="/usr/local/bin"
ZMBKP_CONF="/etc/zmbackup"
ZMBKP_SHARE="/usr/local/share/zmbackup"
ZMBKP_LIB="/usr/local/lib/zmbackup"

# ZIMBRA DEFAULT INSTALLATION PATH AND INTERNAL CONFIGURATION
OSE_USER="zimbra"
OSE_INSTALL_DIR="/opt/zimbra"
OSE_DEFAULT_BKP_DIR="/opt/zimbra/backup"

################################################################################
# CHECKS BEFORE BEGIN THE INSTALL PROCESS
################################################################################

# Check if the script is running as root user
if [ $(id -u) -ne 0 ]; then
	echo "You need root privileges to install zmbackup"
	exit $ERR_NOROOT
fi

################################################################################
# INSTALL PROCESS
################################################################################

clear
echo "################################################################################"
echo "#                                                                              #"
echo "#                     ZMBACKUP INSTALLATION SCRIPT                             #"
echo "#                                                                              #"
echo "################################################################################"
echo ""
echo "Zmbackup is a Open Source software for hot backup and hot restore of the Zimbra."
echo "This is not part of the Zimbra Open Source Community Edition or the Zimbra Plus,"
echo "this is made by the community for the community, so this has NO WARRANTY.       "
echo ""
echo "#################################################################################"
echo ""
echo "WARNING: This is a pre-release and does not supposed to be used in production in"
echo "any way."
echo ""
echo "If you are okay with this and still want to install the zmbackup, press Y."
printf "Are you sure? [N]: "
read OPT
if [[ $OPT != 'Y' && $OPT != 'y' ]]; then
	echo "Stoping the installation process..."
	exit 0
fi
printf "\n\n\n\n"

# Check for missing dependencies
STATUS=0
printf "\n\nChecking system for dependencies...\n\n"

## Zimbra Mailbox
printf "  ZCS Mailbox Control...  "
su - $OSE_USER -c "which zmmailboxdctl" > /dev/null 2>&1
if [ $? = 0 ]; then
        printf "[OK]\n"
else
        printf "[NOT FOUND]\n"
        STATUS=$ERR_DEPNOTFOUND
fi

## LDAP utils
printf "  ldapsearch...	          "
su - $OSE_USER -c "which ldapsearch" > /dev/null 2>&1
if [ $? = 0 ]; then
	printf "[OK]\n"
else
	printf "[NOT FOUND]\n"
	STATUS=$ERR_DEPNOTFOUND
fi

## Curl
printf "  httpie...                 "
su - $OSE_USER -c "which httpie" > /dev/null 2>&1
if [ $? = 0 ]; then
        printf "[OK]\n"
else
        printf "[NOT FOUND]\n"
        STATUS=$ERR_DEPNOTFOUND
fi

## mktemp
printf "  mktemp...               "
su - $OSE_USER -c "which mktemp" > /dev/null 2>&1
if [ $? = 0 ]; then
        printf "[OK]\n"
else
        printf "[NOT FOUND]\n"
        STATUS=$ERR_DEPNOTFOUND
fi

## date
printf "  date...                 "
su - $OSE_USER -c "which date" > /dev/null 2>&1
if [ $? = 0 ]; then
        printf "[OK]\n"
else
        printf "[NOT FOUND]\n"
        STATUS=$ERR_DEPNOTFOUND
fi

## egrep
printf "  egrep...                "
su - $OSE_USER -c "which egrep" > /dev/null 2>&1
if [ $? = 0 ]; then
        printf "[OK]\n"
else
        printf "[NOT FOUND]\n"
        STATUS=$ERR_DEPNOTFOUND
fi

## egrep
printf "  wget...                 "
su - $OSE_USER -c "which wget" > /dev/null 2>&1
if [ $? = 0 ]; then
        printf "[OK]\n"
else
        printf "[NOT FOUND]\n"
        STATUS=$ERR_DEPNOTFOUND
fi

## egrep
printf "  parallel...             "
su - $OSE_USER -c "which parallel" > /dev/null 2>&1
if [ $? = 0 ]; then
        printf "[OK]\n"
else
        printf "[NOT FOUND]\n"
        STATUS=$ERR_DEPNOTFOUND
fi

if [[ $STATUS -ne 0 ]]; then
	echo ""
	echo "You're missing some dependencies OR they are not on $OSE_USER's PATH."
	echo "Please correct the problem and run the installer again."
	exit $ERR_DEPNOTFOUND
fi
# Done checking deps

printf "\n\n\n\n"

printf "\n Please inform the zimbra's system account:[$OSE_USER] "
read TMP
OSE_USER=${TMP:-$OSE_USER}

printf "\n Please inform the zimbra's default folder:[$OSE_INSTALL_DIR] "
read TMP
OSE_INSTALL_DIR=${TMP:-$OSE_INSTALL_DIR}

printf "\n"

echo "Configuring the Admin User for zmbackup. This user will be used to zmbackup access"
echo "the e-mail of all accounts. Please do not use the admin@domain.com account for this"
echo "activity."

DOMAIN=$(sudo -H -u zimbra bash -c '/opt/zimbra/bin/zmprov gad' | head -n 1)
ZMBKP_PASSWORD=$(date +%s | sha256sum | base64 | head -c 32 ; echo)
sudo -H -u $OSE_USER bash -c "/opt/zimbra/bin/zmprov ca zmbackup@$DOMAIN '$ZMBKP_PASSWORD' zimbraIsAdminAccount TRUE zimbraAdminAuthTokenLifetime 1" > /dev/null 2>&1

if ! [ $? -eq 0 ]; then
	echo "User zmbackup already exist! Changing the password to get access..."
	sudo -H -u $OSE_USER bash -c "/opt/zimbra/bin/zmprov sp zmbackup@$DOMAIN '$ZMBKP_PASSWORD'"  > /dev/null 2>&1
fi

ZMBKP_ACCOUNT="zmbackup@$DOMAIN"

echo "Account configured!"

echo "Configuring mail alert when the zmbackup is executed or finish a backup process."
echo "Please inform the account or distribuition list that will receive this messages."
printf "E-Mail: "
read ZMBKP_MAIL_ALERT

echo ""
echo "Recovering all the configuration... Please wait"

OSE_INSTALL_HOSTNAME=`su - $OSE_USER -c "zmhostname"`
OSE_INSTALL_ADDRESS=`grep $OSE_INSTALL_HOSTNAME /etc/hosts|awk '{print $1}'`
OSE_INSTALL_LDAPPASS=`su - $OSE_USER -c "zmlocalconfig -s zimbra_ldap_password"|awk '{print $3}'`

printf "\nPlease, inform the folder where the backup will be stored: "
read ZMBKP_BKPDIR || ZMBKP_BKPDIR="$OSE_INSTALL_DIR/backup"

printf "\nPlease, inform for how many days zmbackup should keep the backups: "
read ZMBKP_BKPTIME || ZMBKP_BKPTIME="30"

mkdir $ZMBKP_BKPDIR > /dev/null 2>&1 && chown $OSE_USER.$OSE_USER $ZMBKP_BKPDIR > /dev/null 2>&1

echo ""
echo "Here is a Summary of your settings:"
echo ""
echo "Zimbra User: $OSE_USER"
echo "Zimbra Hostname: $OSE_INSTALL_HOSTNAME"
echo "Zimbra IP Address: $OSE_INSTALL_ADDRESS"
echo "Zimbra LDAP Password: $OSE_INSTALL_LDAPPASS"
echo "Zimbra Zmbackup Account: $ZMBKP_ACCOUNT"
echo "Zimbra Zmbackup Password: $ZMBKP_PASSWORD"
echo "Zimbra Install Directory: $OSE_INSTALL_DIR"
echo "Zimbra Backup Directory: $ZMBKP_BKPDIR"
echo "Zmbackup Install Directory: $ZMBKP_SRC"
echo "Zmbackup Settings Directory: $ZMBKP_CONF"
echo "Zmbackup Backups Days Max: $ZMBKP_BKPTIME"
echo ""
echo "Press ENTER to continue or CTRL+C to cancel."
read

echo "Installing... Please wait while we made some changes."

# Create directories if needed
test -d $ZMBKP_CONF || mkdir -p $ZMBKP_CONF
test -d $ZMBKP_SRC  || mkdir -p $ZMBKP_SRC
test -d $ZMBKP_SHARE || mkdir -p $ZMBKP_SHARE

# Removing old files
rm -rf $ZMBKP_SHARE $ZMBKP_SRC/zmbhousekeep

# Copy files
install -o $OSE_USER -m 700 $MYDIR/zmbackup $ZMBKP_SRC
install -o $OSE_USER -m 600 $MYDIR/lib/* $ZMBKP_LIB
install --backup=numbered -o root -m 600 $MYDIR/etc/zmbackup.cron /etc/cron.d
install --backup=numbered -o $OSE_USER -m 600 $MYDIR/etc/zmbackup.conf $ZMBKP_CONF
install --backup=numbered -o $OSE_USER -m 600 $MYDIR/etc/blacklist.conf $ZMBKP_CONF

# Add custom settings
sed -i "s|{ZMBKP_BKPDIR}|${ZMBKP_BKPDIR}|g" $ZMBKP_CONF/zmbackup.conf
sed -i "s|{ZMBKP_ACCOUNT}|${ZMBKP_ACCOUNT}|g" $ZMBKP_CONF/zmbackup.conf
sed -i "s|{ZMBKP_PASSWORD}|${ZMBKP_PASSWORD}|g" $ZMBKP_CONF/zmbackup.conf
sed -i "s|{ZMBKP_MAIL_ALERT}|${ZMBKP_MAIL_ALERT}|g" $ZMBKP_CONF/zmbackup.conf
sed -i "s|{OSE_INSTALL_ADDRESS}|${OSE_INSTALL_ADDRESS}|g" $ZMBKP_CONF/zmbackup.conf
sed -i "s|{OSE_INSTALL_LDAPPASS}|${OSE_INSTALL_LDAPPASS}|g" $ZMBKP_CONF/zmbackup.conf
sed -i "s|{OSE_USER}|${OSE_USER}|g" $ZMBKP_CONF/zmbackup.conf
sed -i "s|{ROTATE_TIME}|${ZMBKP_BKPTIME}|g" $ZMBKP_CONF/zmbackup.conf

# Fix backup dir permissions (owner MUST be $OSE_USER)
chown $OSE_USER $ZMBKP_BKPDIR

# We're done!
read -p "Install completed. Do you want to display the README file? (Y/n)" tmp
case "$tmp" in
	y|Y|Yes|"") less $MYDIR/README.md;;
	*) echo "Done!";;
esac

clear
exit $ERR_OK
