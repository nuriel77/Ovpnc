#!/bin/bash
chmod o-rwx * -R
chown ovpnc.ovpnc lib lib/* root root/* t t/ config/ config/.* -R
find openvpn -type f -exec chmod 660 {} \;
chmod 700 config t lib root
chmod 770 openvpn
chown openvpn.ovpnc openvpn -R
chown ovpnc.ovpnc openvpn/conf/.management
chmod 600 openvpn/conf/.management
if [ -d openvpn/conf/2.0/keys ]; then
    chown ovpnc.ovpnc openvpn/conf/2.0/keys/ca.*
    chown ovpnc.ovpnc openvpn/conf/2.0/keys/*.key
    chmod 400 openvpn/conf/2.0/keys/*.key
    chmod 770 openvpn/conf/2.0/keys
    chmod 770 openvpn/conf/2.0/whichopensslcnf \
            openvpn/conf/2.0/sign-req \
            openvpn/conf/2.0/revoke-full \
            openvpn/conf/2.0/pkitool \
            openvpn/conf/2.0/list-crl \
            openvpn/conf/2.0/inherit-inter \
            openvpn/conf/2.0/clean-all \
            openvpn/conf/2.0/build* \
            openvpn/bin/ \
            openvpn/bin/*
fi
