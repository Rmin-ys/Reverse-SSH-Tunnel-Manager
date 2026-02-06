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

# --- Helper: Get Server Info ---
get_info() {
    IP=$(hostname -I | awk '{print $1}')
    OS=$(grep -P '^PRETTY_NAME' /etc/os-release | cut -d '"' -f 2)
}

# --- Main Menu ---
show_menu() {
    get_info
    clear
    echo -e "${CYAN}┌──────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC}         ${PURPLE}${BOLD}🚀 REVERSE SSH TUNNEL MANAGER PRO${NC}        ${CYAN}│${NC}"
    echo -e "${CYAN}└──────────────────────────────────────────────────┘${NC}"
    echo -e "${BLUE}  📍 Server IP: ${NC}$IP  |  ${BLUE}💿 OS: ${NC}$OS"
    echo -e "${CYAN}────────────────────────────────────────────────────${NC}"
    echo -e "  ${YELLOW}1)${NC} ${BOLD}🇮🇷 Setup IR Server${NC}"
    echo -e "  ${YELLOW}2)${NC} ${BOLD}🌍 Setup Foreign Server${NC}"
    echo -e "  ${YELLOW}3)${NC} ${BOLD}📊 Show Status & Ping${NC}"
    echo -e "  ${YELLOW}4)${NC} ${BOLD}📜 View Logs${NC}"
    echo -e "  ${YELLOW}5)${NC} ${BOLD}♻️  Restart Tunnel${NC}"
    echo -e "  ${YELLOW}6)${NC} ${CYAN}🧹 Clear SSH Cache${NC}"
    echo -e "  ${YELLOW}7)${NC} ${RED}🗑️  Uninstall Tunnel${NC}"
    echo -e "  ${YELLOW}0)${NC} ${BOLD}🚪 Exit${NC}"
    echo -e "${CYAN}────────────────────────────────────────────────────${NC}"
    read -p " 💻 Selection: " choice
}

# --- 1. IR Server ---
setup_ir() {
    clear
    echo -e "${BLUE}🔹 Configuring IR Server...${NC}"
    sed -i 's/#AllowTcpForwarding yes/AllowTcpForwarding yes/' /etc/ssh/sshd_config
    sed -i 's/AllowTcpForwarding no/AllowTcpForwarding yes/' /etc/ssh/sshd_config
    grep -q "GatewayPorts" /etc/ssh/sshd_config || echo "GatewayPorts clientspecified" >> /etc/ssh/sshd_config
    grep -q "PermitOpen" /etc/ssh/sshd_config || echo "PermitOpen any" >> /etc/ssh/sshd_config
    systemctl restart ssh
    echo -e "\n${GREEN}✅ IR Server configured!${NC}"
    read -n 1 -s -r -p "Press any key to return to menu..."
}

# --- 2. Foreign Server ---
setup_foreign() {
    clear
    echo -e "${BLUE}🔹 Foreign Server Tunnel Setup${NC}"
    read -p " 🌐 Enter IR Server IP (or type '0' to go back): " ir_ip
    if [[ "$ir_ip" == "0" ]]; then return; fi
    
    read -p " 🔌 Enter Ports (e.g. 2053,2083): " ports_list
    
    echo -e "${YELLOW}⏳ Installing autossh...${NC}"
    apt update && apt install -y autossh
    
    if [ ! -f ~/.ssh/id_ed25519 ]; then
        ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519
    fi
    
    echo -e "${PURPLE}👉 Copying Key to IR. Enter IR password:${NC}"
    ssh-copy-id -o StrictHostKeyChecking=no root@$ir_ip
    
    R_COMMANDS=""
    IFS=',' read -ra ADDR <<< "$ports_list"
    for port in "${ADDR[@]}"; do
        R_COMMANDS+="-R *:$port:127.0.0.1:$port "
    done

    cat <<EOF > /etc/systemd/system/reverse-tunnel.service
[Unit]
Description=Optimized Reverse SSH Tunnel
After=network-online.target

[Service]
Type=simple
User=root
Environment="AUTOSSH_GATETIME=0"
ExecStart=/usr/bin/autossh -M 0 -N \\
  -o "ServerAliveInterval=15" -o "ServerAliveCountMax=2" \\
  -o "TCPKeepAlive=yes" -o "Compression=no" \\
  -o "Ciphers=chacha20-poly1305@openssh.com" \\
  $R_COMMANDS root@$ir_ip
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable --now reverse-tunnel
    echo -e "\n${GREEN}✅ Tunnel active!${NC}"
    read -n 1 -s -r -p "Press any key to return to menu..."
}

# --- 3. Status ---
show_status() {
    clear
    echo -e "${CYAN}📊 Status Check:${NC}"
    systemctl is-active --quiet reverse-tunnel && echo -e "${GREEN}● Tunnel: Online${NC}" || echo -e "${RED}● Tunnel: Offline${NC}"
    
    if [ -f /etc/systemd/system/reverse-tunnel.service ]; then
        ir_target=$(grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' /etc/systemd/system/reverse-tunnel.service | head -1)
        if [ ! -z "$ir_target" ]; then
            echo -n "⚡ Latency to IR: "
            ping -c 2 $ir_target | tail -1 | awk '{print $4}' | cut -d '/' -f 2 | sed 's/$/ ms/' 2>/dev/null || echo "Timeout"
        fi
    fi
    echo -e "\n${BLUE}Systemd Status:${NC}"
    systemctl status reverse-tunnel --no-pager
    echo -e "\n${YELLOW}----------------------------------------------------${NC}"
    echo -e "${PURPLE}Press 0 to return to menu${NC}"
    while true; do
        read -n 1 -s key
        if [[ $key == "0" ]]; then break; fi
    done
}

# --- 4. Logs (The Bug-Free Version) ---
view_logs() {
    clear
    echo -e "${BLUE}📜 Tunnel Logs${NC}"
    echo -e "${YELLOW}1)${NC} Last 20 lines (Quick view)"
    echo -e "${YELLOW}2)${NC} Last 100 lines"
    echo -e "${YELLOW}0)${NC} Back to menu"
    read -p " Selection: " log_choice
    
    case $log_choice in
        1) journalctl -u reverse-tunnel -n 20 --no-pager ;;
        2) journalctl -u reverse-tunnel -n 100 --no-pager ;;
        0) return ;;
        *) echo "Invalid"; sleep 1; return ;;
    esac
    
    echo -e "\n${CYAN}----------------------------------------------------${NC}"
    read -n 1 -s -r -p "Press any key to return to menu..."
}

# --- 6. Clear Cache ---
clear_ssh_cache() {
    clear
    echo -e "${YELLOW}🧹 Clearing Known Hosts Cache...${NC}"
    read -p "Enter IP to clear (or '0' to cancel): " target_ip
    if [[ "$target_ip" == "0" ]]; then return; fi
    
    ssh-keygen -R "$target_ip" &>/dev/null
    echo -e "${GREEN}Cache for $target_ip cleared.${NC}"
    sleep 2
}

# --- 7. Uninstall ---
uninstall_tunnel() {
    clear
    echo -e "${RED}⚠️  Uninstall Tunnel? (y/n): ${NC}"
    read -p "Selection: " confirm
    if [[ "$confirm" == "y" ]]; then
        systemctl stop reverse-tunnel && systemctl disable reverse-tunnel
        rm -f /etc/systemd/system/reverse-tunnel.service
        systemctl daemon-reload
        echo -e "${GREEN}✅ Uninstalled.${NC}"
    fi
    sleep 1
}

# --- Main Loop ---
while true; do
    show_menu
    case $choice in
        1) setup_ir ;;
        2) setup_foreign ;;
        3) show_status ;;
        4) view_logs ;;
        5) systemctl restart reverse-tunnel; echo -e "${GREEN}♻️  Restarted.${NC}"; sleep 1 ;;
        6) clear_ssh_cache ;;
        7) uninstall_tunnel ;;
        0) clear; echo "Goodbye!"; exit ;;
        *) echo -e "${RED}Invalid!${NC}"; sleep 1 ;;
    esac
done
