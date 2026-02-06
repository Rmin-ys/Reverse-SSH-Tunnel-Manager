#!/bin/bash

# Check if user is root
if [ "$EUID" -ne 0 ]; then 
  echo "Please run as root"
  exit
fi

# Main Menu
show_menu() {
    echo "--- Reverse SSH Tunnel Manager ---"
    echo "1) Setup IR Server (Initial Config)"
    echo "2) Setup Foreign Server & Create Tunnel"
    echo "3) Add/Remove Ports"
    echo "4) Show Tunnel Status"
    echo "5) Uninstall Tunnel"
    echo "0) Exit"
    read -p "Select an option: " choice
}

# 1. IR Server Setup 
setup_ir() {
    echo "Configuring SSHD for Reverse Tunneling..."
    sed -i 's/#AllowTcpForwarding yes/AllowTcpForwarding yes/' /etc/ssh/sshd_config
    sed -i 's/AllowTcpForwarding no/AllowTcpForwarding yes/' /etc/ssh/sshd_config
    echo "GatewayPorts clientspecified" >> /etc/ssh/sshd_config
    echo "PermitOpen any" >> /etc/ssh/sshd_config
    systemctl restart ssh
    echo "IR Server is ready!"
}

# 2. UK Server Setup [cite: 3, 6]
setup_uk() {
    read -p "Enter IR Server IP: " ir_ip
    read -p "Enter Ports (comma separated, e.g. 2053,2083): " ports_list
    
    apt update && apt install -y autossh
    
    # SSH Key generation 
    if [ ! -f ~/.ssh/id_ed25519 ]; then
        ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519
    fi
    
    echo "Copying SSH Key to IR Server. Please enter IR password:"
    ssh-copy-id root@$ir_ip
    
    # Generate -R lines for systemd 
    R_COMMANDS=""
    IFS=',' read -ra ADDR <<< "$ports_list"
    for port in "${ADDR[@]}"; do
        R_COMMANDS+="-R *:$port:127.0.0.1:$port "
    done

    # Create Service File 
    cat <<EOF > /etc/systemd/system/reverse-tunnel.service
[Unit]
Description=Reverse SSH Tunnel
After=network-online.target

[Service]
Type=simple
User=root
Environment="AUTOSSH_GATETIME=0"
ExecStart=/usr/bin/autossh -M 0 -N -o "ServerAliveInterval=15" -o "ServerAliveCountMax=2" -o "ExitOnForwardFailure=yes" -o "StrictHostKeyChecking=no" $R_COMMANDS root@$ir_ip
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable --now reverse-tunnel
    echo "Tunnel created and started!"
}

# 4. Status [cite: 13, 14]
show_status() {
    systemctl status reverse-tunnel --no-pager
    echo "Active Tunnel Ports (on UK side):"
    pgrep -af "ssh.*-R"
}

# Main Logic
while true; do
    show_menu
    case $choice in
        1) setup_ir ;;
        2) setup_uk ;;
        4) show_status ;;
        0) exit ;;
        *) echo "Invalid option" ;;
    esac
done
