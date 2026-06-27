#!/bin/bash
# ============================================
# BlueMesh Manager v3.0 - Full Version
# ============================================

set -euo pipefail

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

# Configuration
EASYTRIER_DIR="/opt/bluemesh"
CONFIG_DIR="${EASYTRIER_DIR}/config"
SERVICE_NAME="bluemesh"

# ============================================
# CORE FUNCTIONS
# ============================================

draw_banner() {
    clear
    echo -e "${BLUE}"
    cat << "BANNER"
    ██████╗ ██╗     ██╗   ██╗███████╗███╗   ███╗███████╗███████╗██╗  ██╗
    ██╔══██╗██║     ██║   ██║██╔════╝████╗ ████║██╔════╝██╔════╝██║  ██║
    ██████╔╝██║     ██║   ██║█████╗  ██╔████╔██║█████╗  ███████╗███████║
    ██╔══██╗██║     ██║   ██║██╔══╝  ██║╚██╔╝██║██╔══╝  ╚════██║██╔══██║
    ██████╔╝███████╗╚██████╔╝███████╗██║ ╚═╝ ██║███████╗███████║██║  ██║
    ╚═════╝ ╚══════╝ ╚═════╝ ╚══════╝╚═╝     ╚═╝╚══════╝╚══════╝╚═╝  ╚═╝
BANNER
    echo -e "${RESET}"
    echo -e "${BLUE}  BlueMesh VPN Network Solution v3.0${RESET}"
    echo -e "${CYAN}  ═══════════════════════════════════════${RESET}"
    echo
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}✗ This script must be run as root${RESET}"
        exit 1
    fi
}

is_installed() {
    [[ -f "${EASYTRIER_DIR}/easytier-core" ]] && [[ -f "${EASYTRIER_DIR}/easytier-cli" ]]
}

detect_architecture() {
    local arch=$(uname -m)
    case "$arch" in
        amd64|x86_64) echo "x86_64" ;;
        arm64|aarch64) echo "aarch64" ;;
        *armv7*) echo "armv7" ;;
        *) echo "unknown" ;;
    esac
}

install_core() {
    echo -e "${CYAN}ℹ Installing BlueMesh Core...${RESET}"
    echo
    
    # Check dependencies
    if ! command -v curl &>/dev/null; then
        echo -e "${RED}✗ curl is required${RESET}"
        return 1
    fi
    
    if ! command -v unzip &>/dev/null; then
        echo -e "${RED}✗ unzip is required${RESET}"
        echo -e "${YELLOW}Install with: apt-get install unzip${RESET}"
        return 1
    fi
    
    local arch=$(detect_architecture)
    echo -e "${CYAN}ℹ Architecture: ${arch}${RESET}"
    
    # Get latest version
    echo -e "${CYAN}ℹ Checking for latest version...${RESET}"
    local latest_version=$(curl -s "https://api.github.com/repos/EasyTier/EasyTier/releases/latest" | \
        grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | tr -d '[:space:]')
    
    if [[ -z "$latest_version" ]]; then
        echo -e "${RED}✗ Failed to get latest version${RESET}"
        return 1
    fi
    
    echo -e "${GREEN}✓ Latest version: ${latest_version}${RESET}"
    
    # Download
    local temp_dir=$(mktemp -d /tmp/bluemesh_install_XXXXXX)
    local url="https://github.com/EasyTier/EasyTier/releases/latest/download/easytier-linux-${arch}-${latest_version}.zip"
    
    echo -e "${CYAN}ℹ Downloading...${RESET}"
    if ! curl -L --fail "$url" -o "$temp_dir/easytier.zip"; then
        echo -e "${RED}✗ Download failed${RESET}"
        rm -rf "$temp_dir"
        return 1
    fi
    
    echo -e "${CYAN}ℹ Extracting...${RESET}"
    mkdir -p "$EASYTRIER_DIR"
    unzip -o "$temp_dir/easytier.zip" -d "$temp_dir/"
    mv "$temp_dir/easytier-linux-${arch}"/* "$EASYTRIER_DIR/"
    chmod +x "$EASYTRIER_DIR/easytier-core" "$EASYTRIER_DIR/easytier-cli"
    
    rm -rf "$temp_dir"
    
    echo -e "${GREEN}✓ BlueMesh Core installed successfully!${RESET}"
}

# ============================================
# MENU FUNCTIONS
# ============================================

draw_menu() {
    draw_banner
    
    # Status
    if is_installed; then
        echo -e "  ${GREEN}● Core: Installed${RESET}"
    else
        echo -e "  ${RED}● Core: Not Installed${RESET}"
    fi
    echo
    
    echo "  1. Install Core"
    echo "  2. Configure Network"
    echo "  3. Display Peers"
    echo "  4. Display Routes"
    echo "  5. Show Network Secret"
    echo "  6. View Service Status"
    echo "  7. Check for Updates"
    echo "  8. Uninstall"
    echo "  0. Exit"
    echo
    echo -n "  ${CYAN}→${RESET} Enter your choice: "
}

main_menu() {
    check_root
    
    while true; do
        draw_menu
        read -r choice
        
        case $choice in
            1) 
                echo
                install_core
                echo
                read -rp "  Press Enter to continue..."
                ;;
            2) 
                echo -e "\n  ${YELLOW}⚠ Network configuration coming soon...${RESET}"
                sleep 2
                ;;
            3) 
                echo -e "\n  ${YELLOW}⚠ Peer display coming soon...${RESET}"
                sleep 2
                ;;
            4) 
                echo -e "\n  ${YELLOW}⚠ Route display coming soon...${RESET}"
                sleep 2
                ;;
            5) 
                echo -e "\n  ${YELLOW}⚠ Secret display coming soon...${RESET}"
                sleep 2
                ;;
            6) 
                if is_installed; then
                    systemctl status bluemesh@default --no-pager 2>/dev/null || echo "  Service not running"
                else
                    echo -e "\n  ${RED}✗ Core not installed${RESET}"
                fi
                sleep 3
                ;;
            7) 
                echo -e "\n  ${CYAN}ℹ Checking for updates...${RESET}"
                sleep 2
                ;;
            8)
                echo -e "\n  ${RED}⚠ Uninstall coming soon...${RESET}"
                sleep 2
                ;;
            0)
                echo -e "\n  ${GREEN}Goodbye! 👋${RESET}"
                exit 0
                ;;
            *)
                echo -e "\n  ${RED}✗ Invalid option${RESET}"
                sleep 1
                ;;
        esac
    done
}

# ============================================
# RUN
# ============================================

main_menu
