#!/bin/bash
P=`pwd`;
chmod o-rwx * -R
chown ovpnc.ovpnc lib root t config config/.* -R
chmod 600 config/.* ovpnc.*
chmod 700 config t lib root script script/* tmp tmp/*
chmod 770 openvpn openvpn/conf
chown openvpn.ovpnc openvpn
chown openvpn.ovpnc openvpn/var openvpn/conf openvpn/tmp -R
chown ovpnc.ovpnc openvpn/conf/.management openvpn/conf/*
chmod 600 openvpn/conf/.management openvpn/conf/openvpn*
chown openvpn.ovpnc openvpn/conf/2.0 openvpn/conf/ccd openvpn/conf/ipp.txt -R
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
            openvpn/conf/2.0/build*
fi
chmod 770 .
rm -rf openvpn/lib*
cp -r /lib openvpn/.
ln -s $P/openvpn/lib $P/openvpn/lib64
chmod 755 $P/openvpn/bin -R
