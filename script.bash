#!/bin/bash
#Script for deploying a WireGuard VPN on a DigitalOcean Ubuntu Droplet.

PURPLE='\033[0;35m'
NC='\033[0m'

#Set Account Password.
clear
echo -e "${PURPLE}Please Set a New User Password!${NC}"
passwd

#Get Host Public Key.
echo -e "\n${PURPLE}Please add your Public WireGuard key from WireGuard Client!${NC}" 
read -p 'Host Public Key: ' HOSTPUBLICKEY

# Enabling IP Forwarding.
echo -e "\n${PURPLE}Enabling IP Forwarding...${NC}"
sed -i "29i net.ipv4.ip_forward=1" /etc/sysctl.conf
sudo sysctl -p

#Install WireGuard.
echo -e "\n${PURPLE}Updating System & Installing WireGuard...${NC}"
sudo apt update -y
sudo apt install wireguard -y

#Automate WireGuard Setup.
echo -e "\n${PURPLE}Configuring WireGuard...${NC}"
cd /etc/wireguard
#Generate Private and Public Keys.
umask 077; wg genkey | tee privatekey | wg pubkey > publickey
SERVERPRIVATEKEY=$(cat privatekey)

#Create Server Config File.
touch /etc/wireguard/wg0.conf
cat >> /etc/wireguard/wg0.conf << $CONFIG
[Interface]
Address = 192.168.69.1/24
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE
ListenPort = 51820
PrivateKey = $SERVERPRIVATEKEY

[Peer]
#Client One
PublicKey = $HOSTPUBLICKEY
AllowedIPs = 192.168.69.2
PersistentKeepalive = 25

$CONFIG

#Generate config for the WireGuard Client on the Host machine.
cd /etc/wireguard
SERVERIP=$(dig +short myip.opendns.com @resolver1.opendns.com)
SERVERPUBLICKEY=$(cat publickey)
echo -e "\n${PURPLE}---------------Generated Host Config---------------\n"
echo [Interface]
echo PrivateKey = YourPrivateKeyInYourConfig
echo Address = 192.168.69.2/24
echo DNS = 1.1.1.1
echo
echo [Peer]
echo PublicKey = $SERVERPUBLICKEY
echo AllowedIPs = 0.0.0.0/0
echo Endpoint = $SERVERIP:51820 
echo -e "\n---------------Generated Host Config---------------${NC}\n"

read -p "Press any [Key] when config has been copied into WireGuard Client on Host. Don't Activate Yet!"

#Enable Firewall.
echo -e "\n${PURPLE}Setting up Firewall...${NC}"
sudo ufw allow 22/tcp
sudo ufw allow 51820/udp
sudo ufw enable

#Start WireGuard.
echo -e "\n${PURPLE}Starting WireGuard...${NC}"
systemctl enable wg-quick@wg0
systemctl start wg-quick@wg0
systemctl status wg-quick@wg0

echo -e "\n${PURPLE}Setup Complete. You can now connect to the WireGuard Server!${NC}"