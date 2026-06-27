#!/bin/bash
echo "BlueMesh VPN Network Solution"
echo "=============================="
echo "1. Connect to Mesh Network"
echo "2. Display Peers"
echo "3. Exit"
read -p "Choose: " choice
case $choice in
    1) echo "Connecting..." ;;
    2) echo "Displaying peers..." ;;
    3) exit 0 ;;
    *) echo "Invalid option" ;;
esac
