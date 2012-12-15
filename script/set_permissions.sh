#!/bin/bash
chmod o-rwx * -R
chown ovpnc.ovpnc lib lib/* root root/* t t/ config/ config/.* -R
chmod 700 config t lib root
chmod 770 openvpn
chown openvpn.ovpnc openvpn -R

