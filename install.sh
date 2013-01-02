#!/bin/bash

#
# This script will execute all necessary scripts in order
# to get Ovpnc up and running for the first time
#
# 1. Assuming you already have OpenVPN installed, the first script
#    will copy all the necessary OpenVPN utility files to its own
#    "OpenVPN" working directory. This script requires the path
#    to the OpenVPN easy-rsa/2.0
#
# 2. The next script configures the ovpnc database.
#    Will drop any existing tables and provide the
#    default admin (ovpncadmin) with the passwd 'ovpncadmin'
#
# 3. Sets permissions for all files and directories
#
#

OPENVPN_USER=openvpn
OVPNC_USER=ovpnc

echo Ovpnc initialization script
if [ ! -f .first_setup ];then
    echo "Warning! This script will overwrite any existing data and rebuild the database with the default user (ovpncadmin)."
    echo Press Ctrl-C to break.
    touch .first_setup
fi

if [ -z $1 ];then
    echo "Please provide the directory of the easy-rsa/2.0"
    echo "Example: $0 /usr/share/doc/openvpn/examples/easy-rsa/2.0"
    exit 1
fi

# (1)
./script/conf_openvpn_utils $1
[ $? -ne 0 ] && { exit 1; }

# (2)
echo "Configuring MySQL Ovpnc's database"
./script/conf_mysql_db
[[ $? -ne 0 ]] && {
    echo "Something went wrong while configuring the database;"
    exit 1;
}

# (3)
echo Getting git submodules
GIT=`which git`
if [ -z $GIT ];then
    echo I cannot find the git binary. Do you have git installed? If so, provide its path using the PATH environment variable.
    exit 1
fi
$GIT submodule update --init
[[ $? -ne 0 ]] && { echo "Something went wrong while initializing git submodules"; exit 1; }
$GIT submodule init
[[ $? -ne 0 ]] && { echo "Something went wrong while initializing git submodules"; exit 1; }


# (4)
id $OVPNC_USER
[[ $? -ne 0 ]] && {
    echo "Could not find user $OVPNC_USER. Please create the user 'useradd -d /nonexsistent -s /bin/false -U -M $OVPNC_USER'";
    exit 1;
}

id $OPENVPN_USER
[[ $? -ne 0 ]] && {
    echo "Could not find user $OPENVPN_USER. Please create the user 'useradd -d /nonexsistent -s /bin/false -U -M $OPENVPN_USER'";
    exit 1;
}

echo Setting file and directories ownerships and permissions
./script/set_permissions.sh

echo Done
