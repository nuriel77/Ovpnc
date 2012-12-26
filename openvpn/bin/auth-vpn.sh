#!/bin/sh

# Get the md5 of the temp file
# created by openvpn, it also
# contains the username/pass
MDSUM=`md5sum < $1 | sed 's/[\t +|\-]//g'`
env > /tmp/last_client_env.txt

# Get the md5sum of the
# username/password from
# the ccd file, created
# earlier when user added
realSum=`grep '^#[a-z0-9]*$' conf/ccd/$common_name | sed 's/#//'`

# Verify we have a match
# ======================
case $MDSUM in
  ( $realSum ) { echo `date` $common_name connected  >> /tmp/auth.txt; exit 0; } ;;
esac
echo `date` $common_name failure  >> /tmp/auth.txt
exit 1
