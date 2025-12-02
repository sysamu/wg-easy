#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}WireGuard Easy - Host Preparation Script${NC}"
echo "=========================================="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: This script must be run as root (use sudo)${NC}"
    exit 1
fi

# Check if .env file exists
if [ ! -f .env ]; then
    echo -e "${RED}Error: .env file not found${NC}"
    echo "Please create .env file from .env.example first"
    exit 1
fi

# Source the .env file
echo -e "${YELLOW}Reading configuration from .env...${NC}"
export $(cat .env | grep -v '^#' | grep -v '^$' | xargs)

# Set default values if not in .env
VPN_CIDR="${INIT_IPV4_CIDR:-10.32.33.0/24}"
LAN_ALLOWED="${INIT_ALLOWED_IPS:-192.168.124.0/23}"

# Detect the network interface (exclude docker and loopback)
MAIN_IFACE=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)
if [ -z "$MAIN_IFACE" ]; then
    echo -e "${RED}Error: Could not detect main network interface${NC}"
    exit 1
fi

echo "VPN Network: ${VPN_CIDR}"
echo "Allowed LANs: ${LAN_ALLOWED}"
echo "Main Interface: ${MAIN_IFACE}"
echo ""

# Enable IP forwarding
echo -e "${YELLOW}Enabling IP forwarding...${NC}"
sysctl -w net.ipv4.ip_forward=1
sysctl -w net.ipv4.conf.all.src_valid_mark=1

# Make IP forwarding persistent
if ! grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf 2>/dev/null; then
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
fi
if ! grep -q "net.ipv4.conf.all.src_valid_mark=1" /etc/sysctl.conf 2>/dev/null; then
    echo "net.ipv4.conf.all.src_valid_mark=1" >> /etc/sysctl.conf
fi

# Configure iptables rules
echo -e "${YELLOW}Configuring iptables rules...${NC}"

# Check if DOCKER-USER chain exists, if not create it
if ! iptables -L DOCKER-USER -n >/dev/null 2>&1; then
    echo "Creating DOCKER-USER chain..."
    iptables -N DOCKER-USER
    iptables -I FORWARD -j DOCKER-USER
fi

# Function to add rule if it doesn't exist (filter table)
add_rule_if_not_exists() {
    local chain=$1
    shift
    if ! iptables -C "$chain" "$@" 2>/dev/null; then
        echo "Adding rule: iptables -I $chain $@"
        iptables -I "$chain" "$@"
    else
        echo "Rule already exists: iptables -I $chain $@"
    fi
}

# Function to add NAT rule if it doesn't exist
add_nat_rule_if_not_exists() {
    local chain=$1
    shift
    if ! iptables -t nat -C "$chain" "$@" 2>/dev/null; then
        echo "Adding NAT rule: iptables -t nat -A $chain $@"
        iptables -t nat -A "$chain" "$@"
    else
        echo "NAT rule already exists: iptables -t nat -A $chain $@"
    fi
}

# Parse INIT_ALLOWED_IPS and create rules for each network
IFS=',' read -ra ADDR_ARRAY <<< "$LAN_ALLOWED"
for lan_network in "${ADDR_ARRAY[@]}"; do
    # Skip IPv6 addresses (contain :)
    if [[ $lan_network == *":"* ]]; then
        continue
    fi

    # Trim whitespace
    lan_network=$(echo "$lan_network" | xargs)

    echo ""
    echo "Configuring rules for LAN: ${lan_network}"

    # Allow VPN to LAN traffic
    add_rule_if_not_exists DOCKER-USER -s "$VPN_CIDR" -d "$lan_network" -j ACCEPT

    # Allow LAN to VPN return traffic (established connections)
    add_rule_if_not_exists DOCKER-USER -s "$lan_network" -d "$VPN_CIDR" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

    # Add NAT/MASQUERADE for VPN to LAN traffic
    # This makes VPN traffic appear as if it comes from the server's IP
    add_nat_rule_if_not_exists POSTROUTING -s "$VPN_CIDR" -d "$lan_network" -o "$MAIN_IFACE" -j MASQUERADE
done

echo ""
echo -e "${GREEN}Host preparation completed successfully!${NC}"
echo ""
echo "Current iptables rules in DOCKER-USER chain:"
iptables -L DOCKER-USER -n -v --line-numbers
echo ""
echo "Current NAT rules in POSTROUTING chain:"
iptables -t nat -L POSTROUTING -n -v --line-numbers
echo ""
echo -e "${YELLOW}Note: These rules are not persistent across reboots.${NC}"
echo "To make them persistent, install iptables-persistent:"
echo "  sudo apt-get install iptables-persistent"
echo "  sudo netfilter-persistent save"
echo ""
