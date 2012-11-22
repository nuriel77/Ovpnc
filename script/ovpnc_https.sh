#!/bin/bash

#
# Startup script for Ovpnc
# Using Perl Gepok HTTPS
# Server via Plackup
#

NAME=Ovpnc
APP=ovpnc.psgi
PLACKUP=/usr/local/bin/plackup
CERT=config/server.crt
KEY=config/server.key
HTTPS_PORT=9001
HTTP_PORT=9002
START_SERVERS=3
MAX_CLIENTS=24
MAX_REQ_PER_CLIENT=100
TIMEOUT=60
VER="0.01"

# Verify certificate/key
# are accessible
if [ ! -r $CERT ]; then
	echo
	echo ERROR: $CERT is not accessible
	exit 1
elif [ ! -r $KEY ]; then
	echo
	echo ERROR: $KEY is not accessible
	exit 1
fi

# Run server
$PLACKUP \
	  -I "lib" \
	  -s "Gepok" \
	  --http_ports "$HTTP_PORT" \
	  --https_ports "$HTTPS_PORT" \
	  --ssl_key_file "$KEY" \
	  --ssl_cert_file "$CERT" \
	  --max_requests_per_child "$MAX_REQ_PER_CLIENT" \
	  --time-out "$TIMEOUT" \
	  --max-clients "$MAX_CLIENTS" \
	  --start_servers "$START_SERVERS" \
	  --product_name "$NAME" \
	  --product_version "$VER" \
	  $APP
