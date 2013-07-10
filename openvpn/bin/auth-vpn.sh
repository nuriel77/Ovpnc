#!/bin/sh
#exit 0;
# Get the md5 of the temp file
# created by openvpn, it also
# contains the username/pass
MDSUM=`md5sum < $1 | sed 's/[\t +|\-]//g' | sed 's/\n//g'`
env > /tmp/last_client_env.txt

# Get the md5sum of the
# username/password from
# the ccd file, created
# earlier when user added
realSum=`head -1 conf/ccd/$common_name | grep '^#[a-z0-9]*$' | sed 's/#//'`

echo "compare $realSum and got: $MDSUM" >> /tmp/last_client_env.txt


# Verify we have a match
# ======================
case $MDSUM in
  ( $realSum ) { echo `date` $common_name connected  >> /tmp/auth.txt; exit 0; } ;;
esac
echo `date` $common_name failure  >> /tmp/auth.txt
exit 1
