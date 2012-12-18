#!/bin/sh

MDSUM=`md5sum < $1 | sed 's/[\t +|\-]//g'`
realSum=`grep '^#[a-z0-9]*$' conf/ccd/$common_name | sed 's/#//'`
echo $MDSUM and $realSum > /tmp/auth.txt

case $MDSUM in
  ( $realSum ) { echo `date` $common_name connected  >> /tmp/auth.txt; exit 0; } ;;
esac

exit 1
