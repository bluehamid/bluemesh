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
RESET='\033[0m'

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
    echo
}

draw_menu() {
    draw_banner
    echo "  1. Install Core"
    echo "  2. Configure Network"
    echo "  3. Display Peers"
    echo "  4. Display Routes"
    echo "  5. Show Network Secret"
    echo "  6. View Service Status"
    echo "  7. Check for Updates"
    echo "  0. Exit"
    echo
    echo -n "  Enter your choice: "
}

main_menu() {
    while true; do
        draw_menu
        read -r choice
        
        case $choice in
            1) echo "  Installing core..." ;;
            2) echo "  Configuring network..." ;;
            3) echo "  Displaying peers..." ;;
            4) echo "  Displaying routes..." ;;
            5) echo "  Showing secret..." ;;
            6) echo "  Viewing status..." ;;
            7) echo "  Checking for updates..." ;;
            0) 
                echo -e "\n  ${GREEN}Goodbye! 👋${RESET}"
                exit 0
                ;;
            *) echo "  ${RED}Invalid option${RESET}" ;;
        esac
        sleep 2
    done
}

main_menu
