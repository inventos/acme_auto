#!/bin/bash

# letsencrypt certificate autoupdate script
#
# Author: Alex Svetkin
# version: 0.4
# requirements:
# - acme_tiny.py
# - sudo
# - Let's Encrypt intermediate certificate

USAGE="letsencrypt certificate autoupdate script v.04 \nusage: le_auto.sh -a ACCOUNT -d DOMAIN"

while getopts ":a:d:h" opt; do
  case $opt in
    h)
      echo -e $USAGE
      exit 1
      ;;
    a)
      ACCOUNT=$OPTARG
      ;;
    d)
      DOMAIN=$OPTARG
      ;;
    \?)
      echo "Unknown options $OPTARG"
      exit 1
      ;;
  esac
done

if [[ -z $ACCOUNT ]]; then
  echo "No account given"
  echo -e $USAGE
  exit 1
fi

if [[ -z $DOMAIN ]]; then
  echo "No domain given"
  echo -e $USAGE
  exit 1
fi

PREFIX="/home/$ACCOUNT/letsencrypt"
INTERMEDIATE_CRT_PATH="/etc/letsencrypt/lets-encrypt-x3-cross-signed.pem"

# backup
mkdir -p $PREFIX/certs-backup/ || { echo "Can not create backup dir"; exit 1; }
cp $PREFIX/certs/$DOMAIN.crt $PREFIX/certs-backup/$DOMAIN.crt.`date +"%Y-%m-%d-%H-%M-%S"`

# renew
/usr/bin/acme_tiny.py \
 --account-key $PREFIX/accounts/$ACCOUNT.key \
 --csr $PREFIX/certs/$DOMAIN.csr \
 --acme-dir /opt/nginx/acme-challenge/$DOMAIN/ > $PREFIX/certs/$DOMAIN.crt.new || { echo "Failed to renew"; exit 1; }

if [[ ! -s $PREFIX/certs/$DOMAIN.crt.new ]]; then
    # TODO: use openssl to check new crt
    echo "Erroneous new certificate"
    rm $PREFIX/certs/$DOMAIN.crt.new
    exit 1
fi

mv $PREFIX/certs/$DOMAIN.crt.new $PREFIX/certs/$DOMAIN.crt || { echo "Error replacing certificate"; exit 1; }

# chain
cat $PREFIX/certs/$DOMAIN.crt $INTERMEDIATE_CRT_PATH > $PREFIX/certs/$DOMAIN.chained.crt || { echo "Error chaining certificate"; exit 1; }

echo "Completed"