#!/bin/sh
echo $1 > /tmp/env.txt
env >> /tmp/env.txt
exit 0
