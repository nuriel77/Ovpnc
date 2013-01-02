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

export OPENVPN_USER=openvpn
export OVPNC_USER=ovpnc
export OPENVPN_EASYRSA_UTILS=$1

function initialize(){
    echo Ovpnc initialization script
    if [ ! -f .first_setup ];then
        echo "Warning! This script will overwrite any existing data and rebuild the database with the default user (ovpncadmin)."
        echo Press Ctrl-C to break.
        touch .first_setup
    fi

    if [ -z $OPENVPN_EASYRSA_UTILS ];then
        echo "Please provide the directory of the easy-rsa/2.0"
        echo "Example: $0 /usr/share/doc/openvpn/examples/easy-rsa/2.0"
        exit 1
    fi

}


# (1)
function conf_openvpn_utils() {
    ./script/conf_openvpn_utils $OPENVPN_EASYRSA_UTILS
    [ $? -ne 0 ] && { exit 1; }
    if [ -d openvpn/conf/2.0/tmp ];then
        rm -rf openvpn/conf/2.0/tmp
    fi
    echo "- OpenVPN easy-rsa utilities copied successfully to target"
}

# (2)
function conf_mysql_db(){
    echo
    echo "- Configuring MySQL Ovpnc's database"
    ./script/conf_mysql_db
    [[ $? -ne 0 ]] && {
        echo "[error] Something went wrong while configuring the database;"
        exit 1;
    }
}

# (3)
function setup_git_submodules(){
    echo
    echo "- Getting git submodules"
    GIT=`which git`
    if [ -z $GIT ];then
        echo [error] I cannot find the git binary. Do you have git installed? If so, provide its path using the PATH environment variable.
        exit 1
    fi
    $GIT submodule update --init
    [[ $? -ne 0 ]] && { echo "[error] Something went wrong while initializing git submodules"; exit 1; }
    $GIT submodule init
    [[ $? -ne 0 ]] && { echo "[error] Something went wrong while initializing git submodules"; exit 1; }
}

# (4)
function setup_users_and_permissions(){
    echo
    echo "- Verifying users"

    id $OVPNC_USER
    [[ $? -ne 0 ]] && {
        echo "[error] Could not find user $OVPNC_USER. Please create the user 'useradd -d /nonexsistent -s /bin/false -U -M $OVPNC_USER'";
        echo "Should I create the user? [Y/n]"
        read CONF
        if [[ $CONF = "n" ]] || [[ $CONF = "N" ]];then
            exit 1;
        else
            useradd -d /nonexsistent -s /bin/false -U -M $OVPNC_USER
            [[ $? -ne 0 ]] && { echo "[error] Failed to create user $OVPNC_USER"; exit 1; }
        fi
    }

    id $OPENVPN_USER
    [[ $? -ne 0 ]] && {
        echo "Could not find user $OPENVPN_USER. Please create the user 'useradd -d /nonexsistent -s /bin/false -U -M $OPENVPN_USER'";
        echo "Should I create the user? [Y/n]"
        read CONF
        if [[ $CONF = "n" ]] || [[ $CONF = "N" ]];then
            exit 1;
        else
            useradd -d /nonexsistent -s /bin/false -U -M $OPENVPN_USER
            [[ $? -ne 0 ]] && { echo "[error] Failed to create user $OPENVPN_USER"; exit 1; }
        fi
    }

    adduser $OPENVPN_USER $OVPNC_USER
    [[ $? -ne 0 ]] && { echo "[error] Failed to add user $OPENVPN_USER to group $OVPNC_USER"; exit 1; }

    echo
    echo "- Setting file and directories ownerships and permissions"
    ./script/set_permissions.sh
    [[ $? -ne 0 ]] && {
        echo "Something went wrong while setting permissions and ownerships"
        exit 1;
    }
}


initialize
conf_openvpn_utils
conf_mysql_db
setup_git_submodules
setup_users_and_permissions
echo
echo Done
exit 0
