#!/bin/bash

# --- Colors & UI Elements ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# --- Root Check ---
if [ "$EUID" -ne 0 ]; then 
  echo -e "${RED}❌ Please run as root!${NC}"
  exit
fi

# --- Main Menu Function ---
show_menu() {
    clear
    echo -e "${CYAN}┌──────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC}         ${PURPLE}${BOLD}🚀 REVERSE SSH TUNNEL MANAGER PRO${NC}        ${CYAN}│${NC}"
    echo -e "${CYAN}└──────────────────────────────────────────────────┘${NC}"
    echo -e "  ${YELLOW}1)${NC} ${BOLD}🇮🇷 Setup IR Server${NC} (Initial Configuration)"
    echo -e "  ${YELLOW}2)${NC} ${BOLD}🌍 Setup Foreign Server${NC} (Create Tunnel)"
    echo -e "  ${YELLOW}3)${NC} ${BOLD}📊 Show Status & Ping${NC}"
    echo -e "  ${YELLOW}4)${NC} ${BOLD}📜 View Live Logs${NC}"
    echo -e "  ${YELLOW}5)${NC} ${BOLD}♻️  Restart Tunnel${NC}"
    echo -e "  ${YELLOW}6)${NC} ${RED}🗑️  Uninstall${NC}"
    echo -e "  ${YELLOW}0)${NC} ${BOLD}🚪 Exit${NC}"
    echo -e "${CYAN}────────────────────────────────────────────────────${NC}"
    read -p " 💻 Selection: " choice
}

# --- IR Server Logic ---
setup_ir() {
    clear
    echo -e "${BLUE}🔹 Configuring IR Server SSH Settings...${NC}"
    sed -i 's/#AllowTcpForwarding yes/AllowTcpForwarding yes/' /etc/ssh/sshd_config
    sed -i 's/AllowTcpForwarding no/AllowTcpForwarding yes/' /etc/ssh/sshd_config
    grep -q "GatewayPorts" /etc/ssh/sshd_config || echo "GatewayPorts clientspecified" >> /etc/ssh/sshd_config
    grep -q "PermitOpen" /etc/ssh/sshd_config || echo "PermitOpen any" >> /etc/ssh/sshd_config
    
    systemctl restart ssh
    echo -e "\n${GREEN}✅ IR Server is now ready for Reverse Tunneling!${NC}"
    read -p "Press Enter to return..."
}

# --- Foreign Server Logic ---
setup_foreign() {
    clear
    echo -e "${BLUE}🔹 Starting Foreign Server Tunnel Setup...${NC}"
    read -p " 🌐 Enter IR Server IP: " ir_ip
    read -p " 🔌 Enter Ports (comma separated, e.g. 2053,2083): " ports_list
    
    echo -e "${YELLOW}⏳ Installing dependencies (autossh)...${NC}"
    apt update && apt install -y autossh
    
    if [ ! -f ~/.ssh/id_ed25519 ]; then
        echo -e "${YELLOW}🔑 Generating SSH Key...${NC}"
        ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519
    fi
    
    echo -e "${PURPLE}👉 Copying Key to IR. Enter IR password if asked:${NC}"
    ssh-copy-id -o StrictHostKeyChecking=no root@$ir_ip
    
    R_COMMANDS=""
    IFS=',' read -ra ADDR <<< "$ports_list"
    for port in "${ADDR[@]}"; do
        R_COMMANDS+="-R *:$port:127.0.0.1:$port "
    done

    cat <<EOF > /etc/systemd/system/reverse-tunnel.service
[Unit]
Description=Optimized Reverse SSH Tunnel (Foreign to IR)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
Environment="AUTOSSH_GATETIME=0"
ExecStart=/usr/bin/autossh -M 0 -N \\
  -o "ServerAliveInterval=15" \\
  -o "ServerAliveCountMax=2" \\
  -o "TCPKeepAlive=yes" \\
  -o "ExitOnForwardFailure=yes" \\
  -o "StrictHostKeyChecking=no" \\
  -o "Compression=no" \\
  -o "Ciphers=chacha20-poly1305@openssh.com" \\
  $R_COMMANDS root@$ir_ip
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable --now reverse-tunnel
    echo -e "\n${GREEN}✅ Tunnel created between Foreign and IR servers!${NC}"
    read -p "Press Enter to return..."
}

# --- Status & Ping Logic ---
show_status() {
    clear
    echo -e "${CYAN}📊 Tunnel Service Status:${NC}"
    systemctl is-active --quiet reverse-tunnel && echo -e "${GREEN}● Tunnel is Active${NC}" || echo -e "${RED}● Tunnel is Down${NC}"
    
    echo -e "\n${CYAN}⚡ Network Info:${NC}"
    # Extract IR IP from service file
    if [ -f /etc/systemd/system/reverse-tunnel.service ]; then
        ir_target=$(grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' /etc/systemd/system/reverse-tunnel.service | head -1)
        if [ ! -z "$ir_target" ]; then
            echo -n "Ping to IR ($ir_target): "
            ping -c 3 $ir_target | tail -1 | awk '{print $4}' | cut -d '/' -f 2 | sed 's/$/ ms/'
        fi
    fi
    
    echo -e "\n${BLUE}Details:${NC}"
    systemctl status reverse-tunnel --no-pager
    read -p "Press Enter to return..."
}

# --- Uninstall Logic ---
uninstall_tunnel() {
    clear
    echo -e "${RED}⚠️  Uninstalling Reverse Tunnel...${NC}"
    systemctl stop reverse-tunnel
    systemctl disable reverse-tunnel
    rm /etc/systemd/system/reverse-tunnel.service
    systemctl daemon-reload
    echo -e "${GREEN}✅ All tunnel files and services removed from Foreign server.${NC}"
    read -p "Press Enter to return..."
}

# --- Logic Loop ---
while true; do
    show_menu
    case $choice in
        1) setup_ir ;;
        2) setup_foreign ;;
        3) show_status ;;
        4) clear; echo -e "${BLUE}📜 Live Logs (Ctrl+C to exit):${NC}"; journalctl -u reverse-tunnel -f ;;
        5) systemctl restart reverse-tunnel; echo -e "${GREEN}♻️  Service Restarted.${NC}"; sleep 2 ;;
        6) uninstall_tunnel ;;
        0) clear; echo "Goodbye!"; exit ;;
        *) echo -e "${RED}❌ Invalid selection!${NC}"; sleep 1 ;;
    esac
done
