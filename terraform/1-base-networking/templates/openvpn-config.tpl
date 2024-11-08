client
# TODO both the "remote" and the "verify-x609-name" lines here as they are provided in the connection file created by Microsoft which can be downloaded
# remote <vpngw host> <port>
# verify-x509-name <vpngw hostname basename> name
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

#log openvpn.log
verb 3

# TODO: Update the marked values in order to ensure that dns resolution for the private link names is forwarded to Azure
# Note: These values will only be known after the Confluent Cloud cluster has been provisioned
dhcp-option DNS ${dns_resolver_ip}
dhcp-option DOMAIN lkc-UPDATEME.UPDATEME.UPDATEME.azure.confluent.cloud

# P2S CA root certificate
<ca>
TODO: Please download the connection file from Azure and extract the CA certificate from it.
Unfortunately, there is no way to automate this as this is unsupported by Microsoft.
</ca>

# Pre Shared Key
<tls-auth>
TODO: Please download the connection file from Azure and extract the pre-shared from it.
Unfortunately, there is no way to automate this as this is unsupported by Microsoft.
</tls-auth>

<cert>
${client_cert_pem}</cert>

<key>
${client_key_pem}</key>
