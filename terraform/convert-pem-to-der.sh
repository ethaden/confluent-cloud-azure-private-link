#!/bin/sh
OPENSSL_CMD=openssl

if [ -z $1 ]; then
  echo "Usage: $0 <PEM file>"
  exit 1
fi

CERTIFICATE_DER=$(${OPENSSL_CMD} x509 -in $1 -outform DER | base64 -w 0)

cat <<EOF
{
"CERT_DER": "${CERTIFICATE_DER}"
}
EOF
