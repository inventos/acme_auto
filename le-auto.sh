#!/bin/bash
# Let's Encrypt certificate autoupdate script
# Copyright: 2016 Inventos.ru
# Author: Alex Svetkin
VERSION="0.5"
# requirements: acme_tiny.py, sudo, Let's Encrypt intermediate certificate
USAGE="Let's Encrypt certificate autoupdate script v.$VERSION\nusage: le_auto.sh -a ACCOUNT -d DOMAIN"

errcho() { echo "$@" 1>&2; }

while getopts ":a:d:h" opt; do
  case $opt in
    h)
      echo -e $USAGE && exit 1;;
    a)
      ACCOUNT=$OPTARG;;
    d)
      DOMAIN=$OPTARG;;
    \?)
      errcho "Unknown option '$OPTARG'" && exit 1 ;;
  esac
done

if [[ -z $ACCOUNT ]]; then errcho "No account given" && exit 1; fi
if [[ -z $DOMAIN ]]; then errcho "No domain given" && exit 1; fi

LOCKDIR="/tmp/le-auto.sh-lock-$ACCOUNT"
# TODO: make options to intialize all the dirs etc.
PREFIX="/home/$ACCOUNT/letsencrypt"
# TODO: download intermediate certificate from Let's Encrypt site
INTERMEDIATE_CRT_PATH="/etc/letsencrypt/lets-encrypt-x3-cross-signed.pem"

if mkdir $LOCKDIR; then
  echo $$ > $LOCKDIR/pid
else
  errcho "$0 is already running, pid: $(<$LOCKDIR/pid)" && exit 6
fi
trap 'rm -r $LOCKDIR > /dev/null 2>&1' 0

# backup
mkdir -p $PREFIX/certs-backup/ || { errcho "Can not create backup dir"; exit 1; }
cp $PREFIX/certs/$DOMAIN.crt $PREFIX/certs-backup/$DOMAIN.crt.`date +"%Y-%m-%d-%H-%M-%S"` || { errcho "Can not make backup"; exit 1; }

# renew
/usr/bin/acme_tiny.py \
 --account-key $PREFIX/accounts/$ACCOUNT.key \
 --csr $PREFIX/certs/$DOMAIN.csr \
 --acme-dir /opt/nginx/acme-challenge/$DOMAIN/ > $PREFIX/certs/$DOMAIN.crt.new || { errcho "Failed to renew"; exit 1; }

if [[ ! -s $PREFIX/certs/$DOMAIN.crt.new ]]; then
    # TODO: use openssl to check new crt
    errcho "Erroneous new certificate"
    rm $PREFIX/certs/$DOMAIN.crt.new
    exit 1
fi

mv $PREFIX/certs/$DOMAIN.crt.new $PREFIX/certs/$DOMAIN.crt || { errcho "Error replacing certificate"; exit 1; }

# chain
cat $PREFIX/certs/$DOMAIN.crt $INTERMEDIATE_CRT_PATH > $PREFIX/certs/$DOMAIN.chained.crt || { errcho "Error chaining certificate"; exit 1; }

rm -f $LOCKFILE
echo "Completed. Dont't forget to reload your web server!"