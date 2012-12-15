#!/bin/bash
cd openvpn
rm -rf lib*
cp -r /lib .
ln -s lib lib64
cd bin
cp `which env` .
cp `which grep` .
cp `which pwd` .
cp `which date` .
cp `which echo` .
cp `which sed` .
cp `which sh` .
ln -s sh bash
cd -

