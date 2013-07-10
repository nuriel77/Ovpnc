#!/bin/bash
cd openvpn
rm -rf lib*
cp -r /lib .
if [ `uname -m` == 'x86_64' ]; then
    ln -s lib lib64
fi
cd bin
cp `which env` .
cp `which grep` .
cp `which pwd` .
cp `which date` .
cp `which echo` .
cp `which sed` .
cp `which head` .
cp `which md5sum` .
cp `which sh` .
ln -s sh bash
cd -

