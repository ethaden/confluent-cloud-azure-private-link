client
dev tun
proto udp
remote ${vpn_gateway_endpoint} 443
remote-random-hostname
resolv-retry infinite
nobind
remote-cert-tls server
cipher AES-256-GCM
verb 3
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

reneg-sec 0


