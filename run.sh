#!/bin/bash

# --- Colors & UI Elements ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# --- Root Check ---
if [ "$EUID" -ne 0 ]; then 
  echo -e "${RED}❌ Please run as root!${NC}"
  exit
fi

# --- Main Menu ---
show_menu() {
    clear
    echo -e "${CYAN}┌──────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC}         ${PURPLE}${BOLD}🚀 REVERSE SSH TUNNEL MANAGER PRO${NC}        ${CYAN}│${NC}"
    echo -e "${CYAN}└──────────────────────────────────────────────────┘${NC}"
    echo -e "  ${YELLOW}1)${NC} ${BOLD}🇮🇷 Setup IR Server${NC}"
    echo -e "  ${YELLOW}2)${NC} ${BOLD}🌍 Setup Foreign Server${NC}"
    echo -e "  ${YELLOW}3)${NC} ${BOLD}📊 Show Status & Ping${NC}"
    echo -e "  ${YELLOW}4)${NC} ${BOLD}📜 View Logs (Safe Mode)${NC}"
    echo -e "  ${YELLOW}5)${NC} ${BOLD}♻️  Restart Tunnel${NC}"
    echo -e "  ${YELLOW}6)${NC} ${CYAN}🧹 Clear SSH Cache${NC}"
    echo -e "  ${YELLOW}7)${NC} ${RED}🗑️  Uninstall Tunnel${NC}"
    echo -e "  ${YELLOW}0)${NC} ${BOLD}🚪 Exit${NC}"
    echo -e "${CYAN}────────────────────────────────────────────────────${NC}"
}

# --- 2. Foreign Server Setup (With Custom Port Support) ---
setup_foreign() {
    clear
    echo -e "${BLUE}🔹 Foreign Server Tunnel Setup${NC}"
    read -p " 🌐 Enter IR Server IP (or 0 to back): " ir_ip
    [[ "$ir_ip" == "0" ]] && return
    
    # --- New: Ask for SSH Port ---
    read -p " 🔑 Enter IR Server SSH Port (Default 22): " ir_ssh_port
    ir_ssh_port=${ir_ssh_port:-22}
    
    read -p " 🔌 Enter Tunnel Ports (comma separated, e.g. 2053,2083): " ports_list
    
    echo -e "${YELLOW}⏳ Installing dependencies...${NC}"
    apt update && apt install -y autossh
    
    [[ ! -f ~/.ssh/id_ed25519 ]] && ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519
    
    echo -e "${PURPLE}👉 Copying Key to IR (Using Port $ir_ssh_port)...${NC}"
    # Added -p for custom SSH port
    ssh-copy-id -o StrictHostKeyChecking=no -p $ir_ssh_port root@$ir_ip
    
    R_COMMANDS=""
    IFS=',' read -ra ADDR <<< "$ports_list"
    for port in "${ADDR[@]}"; do
        R_COMMANDS+="-R *:$port:127.0.0.1:$port "
    done

    # Create service with custom port
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
  -p $ir_ssh_port \\
  $R_COMMANDS root@$ir_ip
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable --now reverse-tunnel
    echo -e "\n${GREEN}✅ Tunnel active with custom port $ir_ssh_port!${NC}"
    read -n 1 -s -r -p "Press any key to return to menu..."
}

# --- بقیه توابع (Status, Logs, IR Setup, ...) به همان شکل قبلی باقی می‌مانند ---
# ... (کد قبلی را اینجا قرار دهید)
