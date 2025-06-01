#!/bin/bash
set -e
terraform init
terraform plan
terraform apply -auto-approve

SSH_KEY_PATH=$1
if [[ $SSH_KEY_PATH == "" ]] then
    SSH_KEY_PATH=~/.ssh/new_key/id_ed25519
fi

VPN_IP=$(terraform output -raw vpn_ip)
echo $VPN_IP

SERVER_PRIVATE_KEY=$(wg genkey)
SERVER_PUBLIC_KEY=$(echo $SERVER_PRIVATE_KEY | wg pubkey)

CLIENT_PRIVATE_KEY=$(wg genkey)
CLIENT_PUBLIC_KEY=$(echo $CLIENT_PRIVATE_KEY  | wg pubkey)


cat <<EOF > wg-server.conf
[Interface]
Address = 10.8.0.1/24,fd86:ea04:1111::1/64
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT
PostUp = iptables -t nat -I POSTROUTING -o enp1s0 -j MASQUERADE
PostUp = ip6tables -t nat -I POSTROUTING -o enp1s0 -j MASQUERADE

PostDown = ip6tables -t nat -D POSTROUTING -o enp1s0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT
PostDown = iptables -t nat -D POSTROUTING -o enp1s0 -j MASQUERADE

SaveConfig = true
MTU = 1280
ListenPort = 51820
PrivateKey = $SERVER_PRIVATE_KEY

[Peer]
PublicKey = $CLIENT_PUBLIC_KEY
AllowedIPs = 10.8.0.1/24, fd86:ea04:1111::2/128

EOF


cat <<EOF > wg-client.conf
[Interface]
PrivateKey = $CLIENT_PRIVATE_KEY
Address = 10.8.0.2/24, fd86:ea04:1111::2/64
DNS = 185.228.168.9 # Change this at some point to the 10.8.0.1:53 -> dnsmasque
MTU = 1280

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
Endpoint = $VPN_IP:51820
# AllowedIPs = 10.8.0.1/24
AllowedIPs = 0.0.0.0/0,::/0 # route all my traffic
PersistentKeepalive = 25

EOF


echo $SSH_KEY_PATH
# set up the wg0
scp -i $SSH_KEY_PATH wg-server.conf root@$VPN_IP:/etc/wireguard/wg0.conf
ssh -i $SSH_KEY_PATH root@$VPN_IP 'wg-quick up wg0'
ssh -i $SSH_KEY_PATH root@$VPN_IP 'ufw route allow in on wg0 out on enp1s0'
# disable the global ssh afterwards
ssh -i $SSH_KEY_PATH root@$VPN_IP 'ufw allow from 10.8.0.1/24 to any port 22 proto tcp'
ssh -i $SSH_KEY_PATH root@$VPN_IP 'ufw delete allow 22/tcp'
qrencode -t png -o user-qr.png -r wg-client.conf