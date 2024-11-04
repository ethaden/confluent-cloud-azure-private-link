client
dev tun
proto tcp
ADD both the "remote" and the "verify-x609-name" lines here as they are provided in the connection file created by Microsoft which can be downloaded

remote-cert-tls server

dev tun
proto tcp
resolv-retry infinite
nobind

auth SHA256
cipher AES-256-GCM
persist-key
persist-tun

tls-timeout 30
tls-version-min 1.2
key-direction 1

verb 3

# P2S CA root certificate
<ca>
${ca_cert_pem}
</ca>

# Pre Shared Key
<tls-auth>
Please download the connection file from Azure and extract the pre-shared from it.
Unfortunately, there is no way to automate this as this is unsupported by Microsoft.
</tls-auth>

<cert>
${client_cert_pem}
</cert>

<key>
${client_key_pem}
</key>
