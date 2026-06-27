#!/bin/bash
# ============================================
# BlueMesh Manager v3.0 - Complete Version
# Integrated from EasyTier Official + BlueMesh
# ============================================

set -euo pipefail

# ============================================
# COLORS
# ============================================

BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
RESET='\033[0m'

# ============================================
# CONFIGURATION
# ============================================

EASYTRIER_DIR="/opt/bluemesh"
CONFIG_DIR="${EASYTRIER_DIR}/config"
SERVICE_NAME="bluemesh"
EASY_CLI="${EASYTRIER_DIR}/easytier-cli"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

# ============================================
# BANNER & UI
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

# ============================================
# HELPERS
# ============================================

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}✗ This script must be run as root${RESET}"
        exit 1
    fi
}

is_installed() {
    [[ -f "${EASYTRIER_DIR}/easytier-core" ]] && [[ -f "${EASYTRIER_DIR}/easytier-cli" ]]
}

service_running() {
    systemctl is-active --quiet "${SERVICE_NAME}.service" 2>/dev/null
}

detect_architecture() {
    local arch=$(uname -m)
    case "$arch" in
        amd64|x86_64) echo "x86_64" ;;
        arm64|aarch64) echo "aarch64" ;;
        *armv7*) 
            if cat /proc/cpuinfo | grep Features | grep -i 'half' >/dev/null 2>&1; then
                echo "armv7hf"
            else
                echo "armv7"
            fi
            ;;
        *) echo "unknown" ;;
    esac
}

detect_init_system() {
    if command -v systemctl >/dev/null 2>&1; then
        echo "systemd"
    elif command -v rc-update >/dev/null 2>&1; then
        echo "openrc"
    else
        echo "unknown"
    fi
}

generate_secret() {
    openssl rand -hex 6 2>/dev/null || tr -dc 'a-f0-9' < /dev/urandom | head -c 12
}

press_key() {
    echo
    read -rp "  Press Enter to continue..."
}

# ============================================
# CORE INSTALLATION (from official installer)
# ============================================

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
    if [[ "$arch" == "unknown" ]]; then
        echo -e "${RED}✗ Unsupported architecture: $(uname -m)${RESET}"
        return 1
    fi
    
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
    if ! curl -L --fail --progress-bar "$url" -o "$temp_dir/easytier.zip"; then
        echo -e "${RED}✗ Download failed${RESET}"
        rm -rf "$temp_dir"
        return 1
    fi
    
    echo -e "${CYAN}ℹ Extracting...${RESET}"
    mkdir -p "$EASYTRIER_DIR" "$CONFIG_DIR"
    unzip -o "$temp_dir/easytier.zip" -d "$temp_dir/"
    mv "$temp_dir/easytier-linux-${arch}"/* "$EASYTRIER_DIR/"
    chmod +x "$EASYTRIER_DIR/easytier-core" "$EASYTRIER_DIR/easytier-cli"
    
    # Create default config (from official installer)
    cat > "$CONFIG_DIR/default.conf" <<EOF
instance_name = "default"
dhcp = true
listeners = [
    "tcp://0.0.0.0:11010",
    "udp://0.0.0.0:11010",
    "wg://0.0.0.0:11011",
    "ws://0.0.0.0:11011/",
    "wss://0.0.0.0:11012/",
]
exit_nodes = []
rpc_portal = "0.0.0.0:0"

[[peer]]
uri = "tcp://public.easytier.top:11010"

[network_identity]
network_name = "default"
network_secret = "default"

[flags]
default_protocol = "udp"
dev_name = ""
enable_encryption = true
enable_ipv6 = true
mtu = 1380
latency_first = false
enable_exit_node = false
no_tun = false
use_smoltcp = false
foreign_network_whitelist = "*"
disable_p2p = false
p2p_only = false
relay_all_peer_rpc = false
disable_tcp_hole_punching = false
disable_udp_hole_punching = false
EOF
    
    # Create systemd service (from official installer)
    cat > /etc/systemd/system/${SERVICE_NAME}@.service <<EOF
[Unit]
Description=BlueMesh Network Service (%I)
Wants=network.target
After=network.target network.service
StartLimitIntervalSec=0

[Service]
Type=simple
WorkingDirectory=$EASYTRIER_DIR
ExecStart=$EASYTRIER_DIR/easytier-core -c $CONFIG_DIR/%i.conf
Restart=always
RestartSec=1s

[Install]
WantedBy=multi-user.target
EOF
    
    # Create symlinks
    ln -sf "$EASYTRIER_DIR/easytier-core" /usr/sbin/easytier-core 2>/dev/null || true
    ln -sf "$EASYTRIER_DIR/easytier-cli" /usr/sbin/easytier-cli 2>/dev/null || true
    
    # Start service
    systemctl daemon-reload
    systemctl enable ${SERVICE_NAME}@default
    systemctl start ${SERVICE_NAME}@default
    
    rm -rf "$temp_dir"
    
    echo -e "${GREEN}✓ BlueMesh Core installed successfully!${RESET}"
    echo -e "${CYAN}ℹ Service started: ${SERVICE_NAME}@default${RESET}"
    echo -e "${CYAN}ℹ Default config: $CONFIG_DIR/default.conf${RESET}"
}

# ============================================
# NETWORK CONFIGURATION (from original BlueMesh)
# ============================================

configure_network() {
    echo -e "${CYAN}ℹ Configure Mesh Network${RESET}"
    echo
    
    if ! is_installed; then
        echo -e "${RED}✗ Core not installed. Please install first.${RESET}"
        press_key
        return 1
    fi
    
    local instance_name network_name network_secret
    local listeners peers default_protocol
    
    read -rp "  Instance name [default]: " instance_name
    instance_name=${instance_name:-default}
    
    read -rp "  Network name [default]: " network_name
    network_name=${network_name:-default}
    
    local generated_secret=$(generate_secret)
    echo -e "${CYAN}ℹ Generated Secret: ${generated_secret}${RESET}"
    read -rp "  Network secret (or use generated): " network_secret
    network_secret=${network_secret:-$generated_secret}
    
    echo
    echo -e "${CYAN}ℹ Listeners Configuration${RESET}"
    echo "  Example: tcp://0.0.0.0:11010, udp://0.0.0.0:11010, wg://0.0.0.0:11011"
    read -rp "  Listeners (comma separated): " listeners_input
    
    echo
    echo -e "${CYAN}ℹ Peer Configuration${RESET}"
    read -rp "  Peer URIs (comma separated): " peers_input
    
    echo
    echo "  ${CYAN}Protocol Options:${RESET}"
    echo "    1) TCP  2) UDP  3) WS  4) WSS"
    read -rp "  Default protocol [2]: " proto_choice
    proto_choice=${proto_choice:-2}
    
    case "$proto_choice" in
        1) default_protocol="tcp" ;;
        2) default_protocol="udp" ;;
        3) default_protocol="ws" ;;
        4) default_protocol="wss" ;;
        *) default_protocol="udp" ;;
    esac
    
    local config_file="$CONFIG_DIR/${instance_name}.conf"
    
    cat > "$config_file" <<EOF
instance_name = "$instance_name"
dhcp = true
listeners = [
EOF
    
    if [[ -n "$listeners_input" ]]; then
        IFS=',' read -ra listeners <<< "$listeners_input"
        for listener in "${listeners[@]}"; do
            listener=$(echo "$listener" | xargs)
            [[ -n "$listener" ]] && echo "    \"$listener\"," >> "$config_file"
        done
    else
        echo "    \"${default_protocol}://0.0.0.0:11010\"," >> "$config_file"
        echo "    \"wg://0.0.0.0:11011\"," >> "$config_file"
    fi
    echo "]" >> "$config_file"
    
    if [[ -n "$peers_input" ]]; then
        echo "[[peer]]" >> "$config_file"
        IFS=',' read -ra peers <<< "$peers_input"
        for peer in "${peers[@]}"; do
            peer=$(echo "$peer" | xargs)
            [[ -n "$peer" ]] && echo "uri = \"$peer\"" >> "$config_file"
        done
    fi
    
    cat >> "$config_file" <<EOF

[network_identity]
network_name = "$network_name"
network_secret = "$network_secret"

[flags]
default_protocol = "$default_protocol"
dev_name = ""
enable_encryption = true
enable_ipv6 = true
mtu = 1380
latency_first = false
enable_exit_node = false
no_tun = false
use_smoltcp = false
foreign_network_whitelist = "*"
disable_p2p = false
p2p_only = false
relay_all_peer_rpc = false
disable_tcp_hole_punching = false
disable_udp_hole_punching = false
EOF
    
    echo -e "${GREEN}✓ Configuration saved: $config_file${RESET}"
    
    # Restart service with new config
    systemctl restart ${SERVICE_NAME}@${instance_name} 2>/dev/null || \
        systemctl start ${SERVICE_NAME}@${instance_name}
    
    echo -e "${GREEN}✓ Service started: ${SERVICE_NAME}@${instance_name}${RESET}"
    press_key
}

# ============================================
# DISPLAY FUNCTIONS (from original BlueMesh)
# ============================================

display_peers() {
    echo -e "${CYAN}ℹ Displaying Peers...${RESET}"
    echo
    
    if ! is_installed; then
        echo -e "${RED}✗ Core not installed${RESET}"
        press_key
        return 1
    fi
    
    if ! service_running; then
        echo -e "${YELLOW}⚠ Service not running${RESET}"
        press_key
        return 1
    fi
    
    "$EASY_CLI" peer 2>/dev/null || echo -e "${RED}✗ Failed to get peers${RESET}"
    press_key
}

display_routes() {
    echo -e "${CYAN}ℹ Displaying Routes...${RESET}"
    echo
    
    if ! is_installed; then
        echo -e "${RED}✗ Core not installed${RESET}"
        press_key
        return 1
    fi
    
    if ! service_running; then
        echo -e "${YELLOW}⚠ Service not running${RESET}"
        press_key
        return 1
    fi
    
    "$EASY_CLI" route 2>/dev/null || echo -e "${RED}✗ Failed to get routes${RESET}"
    press_key
}

peer_center() {
    echo -e "${CYAN}ℹ Peer Center...${RESET}"
    echo
    
    if ! is_installed; then
        echo -e "${RED}✗ Core not installed${RESET}"
        press_key
        return 1
    fi
    
    if ! service_running; then
        echo -e "${YELLOW}⚠ Service not running${RESET}"
        press_key
        return 1
    fi
    
    "$EASY_CLI" peer-center 2>/dev/null || echo -e "${RED}✗ Failed to get peer center${RESET}"
    press_key
}

# ============================================
# SECRET MANAGEMENT
# ============================================

show_secret() {
    echo -e "${CYAN}ℹ Network Secret${RESET}"
    echo
    
    if ! is_installed; then
        echo -e "${RED}✗ Core not installed${RESET}"
        press_key
        return 1
    fi
    
    local config_files=("$CONFIG_DIR"/*.conf)
    if [[ ${#config_files[@]} -gt 0 ]]; then
        for config in "${config_files[@]}"; do
            local secret=$(grep -oP '(?<=network_secret = ")[^"]+' "$config" 2>/dev/null)
            if [[ -n "$secret" ]]; then
                local name=$(basename "$config" .conf)
                echo -e "  ${GREEN}Instance '$name':${RESET} ${CYAN}$secret${RESET}"
            fi
        done
    else
        echo -e "${RED}✗ No configuration found${RESET}"
    fi
    
    press_key
}

# ============================================
# SERVICE MANAGEMENT (from original BlueMesh)
# ============================================

view_service_status() {
    echo -e "${CYAN}ℹ Service Status${RESET}"
    echo
    
    if ! is_installed; then
        echo -e "${RED}✗ Core not installed${RESET}"
        press_key
        return 1
    fi
    
    systemctl status ${SERVICE_NAME}@default --no-pager -l 2>/dev/null || \
        echo -e "${RED}✗ Service not found${RESET}"
    press_key
}

restart_service() {
    echo -e "${CYAN}ℹ Restarting Service...${RESET}"
    
    if ! is_installed; then
        echo -e "${RED}✗ Core not installed${RESET}"
        press_key
        return 1
    fi
    
    systemctl restart ${SERVICE_NAME}@default
    echo -e "${GREEN}✓ Service restarted${RESET}"
    press_key
}

remove_service() {
    echo -e "${RED}⚠ Removing Service...${RESET}"
    echo
    
    if ! confirm "Remove BlueMesh service?"; then
        return 0
    fi
    
    systemctl stop ${SERVICE_NAME}@default 2>/dev/null || true
    systemctl disable ${SERVICE_NAME}@default 2>/dev/null || true
    rm -f /etc/systemd/system/${SERVICE_NAME}@.service
    systemctl daemon-reload
    
    echo -e "${GREEN}✓ Service removed${RESET}"
    press_key
}

remove_core() {
    echo -e "${RED}⚠ Removing Core...${RESET}"
    echo
    
    if ! is_installed; then
        echo -e "${YELLOW}⚠ Core not installed${RESET}"
        press_key
        return 0
    fi
    
    if ! confirm "Remove BlueMesh core files?"; then
        return 0
    fi
    
    remove_service
    rm -rf "$EASYTRIER_DIR"
    rm -f /usr/sbin/easytier-core /usr/sbin/easytier-cli
    
    echo -e "${GREEN}✓ Core removed${RESET}"
    press_key
}

# ============================================
# UPDATE SYSTEM (from official installer)
# ============================================

check_for_updates() {
    echo -e "${CYAN}ℹ Checking for updates...${RESET}"
    echo
    
    if ! is_installed; then
        echo -e "${RED}✗ Core not installed${RESET}"
        press_key
        return 1
    fi
    
    local latest_version=$(curl -s "https://api.github.com/repos/EasyTier/EasyTier/releases/latest" | \
        grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | tr -d '[:space:]')
    
    if [[ -z "$latest_version" ]]; then
        echo -e "${RED}✗ Failed to check for updates${RESET}"
        press_key
        return 1
    fi
    
    local current_version=$(strings "$EASYTRIER_DIR/easytier-core" | grep -oP 'v?\d+\.\d+\.\d+' | head -1)
    echo -e "  ${CYAN}Current version:${RESET} ${current_version:-Unknown}"
    echo -e "  ${CYAN}Latest version:${RESET} ${latest_version}"
    
    if [[ "$current_version" == "$latest_version" ]]; then
        echo -e "${GREEN}✓ You are running the latest version!${RESET}"
    else
        echo -e "${YELLOW}⚠ New version available!${RESET}"
        if confirm "Update to $latest_version?"; then
            update_core
        fi
    fi
    
    press_key
}

update_core() {
    echo -e "${CYAN}ℹ Updating Core...${RESET}"
    echo
    
    # Backup config
    local backup_name="config_$(date +%Y%m%d_%H%M%S)"
    cp -r "$CONFIG_DIR" "/tmp/$backup_name" 2>/dev/null || true
    
    # Get running services
    local active_services=$(systemctl list-units --type=service --state=active | \
        grep "${SERVICE_NAME}@" | awk '{print $1}' || true)
    
    if [[ -n "$active_services" ]]; then
        echo -e "${CYAN}ℹ Stopping services...${RESET}"
        systemctl stop $active_services
    fi
    
    # Reinstall
    local arch=$(detect_architecture)
    local latest_version=$(curl -s "https://api.github.com/repos/EasyTier/EasyTier/releases/latest" | \
        grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | tr -d '[:space:]')
    
    local temp_dir=$(mktemp -d /tmp/bluemesh_update_XXXXXX)
    local url="https://github.com/EasyTier/EasyTier/releases/latest/download/easytier-linux-${arch}-${latest_version}.zip"
    
    echo -e "${CYAN}ℹ Downloading...${RESET}"
    curl -L --fail "$url" -o "$temp_dir/easytier.zip"
    unzip -o "$temp_dir/easytier.zip" -d "$temp_dir/"
    
    cp -f "$temp_dir/easytier-linux-${arch}/easytier-core" "$EASYTRIER_DIR/"
    cp -f "$temp_dir/easytier-linux-${arch}/easytier-cli" "$EASYTRIER_DIR/"
    chmod +x "$EASYTRIER_DIR/easytier-core" "$EASYTRIER_DIR/easytier-cli"
    
    # Restore config
    cp -af "/tmp/$backup_name/." "$CONFIG_DIR/" 2>/dev/null || true
    
    # Restart services
    if [[ -n "$active_services" ]]; then
        echo -e "${CYAN}ℹ Restarting services...${RESET}"
        systemctl start $active_services
    fi
    
    rm -rf "$temp_dir"
    rm -rf "/tmp/$backup_name"
    
    echo -e "${GREEN}✓ Updated to version $latest_version${RESET}"
    press_key
}

# ============================================
# WATCHDOG (from original BlueMesh)
# ============================================

configure_watchdog() {
    echo -e "${CYAN}ℹ Watchdog Configuration${RESET}"
    echo
    
    if service_running; then
        echo -e "${GREEN}● Watchdog is running${RESET}"
    else
        echo -e "${RED}● Watchdog is not running${RESET}"
    fi
    echo
    
    echo "  1) Create/Start Watchdog"
    echo "  2) Stop/Remove Watchdog"
    echo "  3) View Logs"
    echo "  4) Back"
    echo
    read -rp "  Choice: " choice
    
    case "$choice" in
        1) start_watchdog ;;
        2) stop_watchdog ;;
        3) view_watchdog_logs ;;
        *) return 0 ;;
    esac
}

start_watchdog() {
    local ip threshold interval
    
    read -rp "  Enter IP to monitor: " ip
    [[ -z "$ip" ]] && { echo -e "${RED}✗ IP required${RESET}"; return 1; }
    
    read -rp "  Latency threshold (ms) [200]: " threshold
    threshold=${threshold:-200}
    
    read -rp "  Check interval (s) [8]: " interval
    interval=${interval:-8}
    
    # Create watchdog script
    local script="/usr/local/bin/bluemesh-watchdog.sh"
    cat > "$script" <<'EOF'
#!/bin/bash
IP="$1"
THRESHOLD="$2"
INTERVAL="$3"
LOG="/var/log/bluemesh/watchdog.log"

ping_test() {
    local avg=$(ping -c 3 -W 2 -i 0.2 "$IP" 2>/dev/null | \
                grep 'time=' | \
                sed -n 's/.*time=\([0-9.]*\) ms.*/\1/p' | \
                awk '{sum+=$1; count++} END {if(count>0) print sum/count; else print 0}')
    echo "$avg"
}

while true; do
    latency=$(ping_test)
    if [[ "$latency" == "0" ]] || (( $(echo "$latency > $THRESHOLD" | bc -l) )); then
        echo "$(date): Latency $latency ms - Restarting service" >> "$LOG"
        systemctl restart bluemesh@default
    fi
    sleep "$INTERVAL"
done
EOF
    
    chmod +x "$script"
    
    # Create watchdog service
    local service_file="/etc/systemd/system/bluemesh-watchdog.service"
    cat > "$service_file" <<EOF
[Unit]
Description=BlueMesh Watchdog
After=network.target

[Service]
ExecStart=$script $ip $threshold $interval
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable bluemesh-watchdog
    systemctl start bluemesh-watchdog
    
    echo -e "${GREEN}✓ Watchdog started: $ip (threshold: ${threshold}ms, interval: ${interval}s)${RESET}"
    press_key
}

stop_watchdog() {
    echo
    if systemctl is-active --quiet bluemesh-watchdog 2>/dev/null; then
        systemctl stop bluemesh-watchdog
        systemctl disable bluemesh-watchdog
        rm -f /etc/systemd/system/bluemesh-watchdog.service
        rm -f /usr/local/bin/bluemesh-watchdog.sh
        systemctl daemon-reload
        echo -e "${GREEN}✓ Watchdog removed${RESET}"
    else
        echo -e "${YELLOW}⚠ Watchdog not found${RESET}"
    fi
    press_key
}

view_watchdog_logs() {
    if [[ -f /var/log/bluemesh/watchdog.log ]]; then
        tail -n 50 /var/log/bluemesh/watchdog.log | nl
    else
        echo -e "${YELLOW}⚠ No logs found${RESET}"
    fi
    press_key
}

# ============================================
# CRONJOB (from original BlueMesh)
# ============================================

configure_cron() {
    echo -e "${CYAN}ℹ Cronjob Configuration${RESET}"
    echo
    
    echo "  1) Add cronjob"
    echo "  2) Remove cronjob"
    echo "  3) Back"
    echo
    read -rp "  Choice: " choice
    
    case "$choice" in
        1) add_cron ;;
        2) remove_cron ;;
        *) return 0 ;;
    esac
}

add_cron() {
    echo
    echo "  Select restart interval:"
    echo "    1) 30 min  2) 1 hour  3) 2 hours"
    echo "    4) 4 hours  5) 6 hours  6) 12 hours  7) 24 hours"
    read -rp "  Choice: " choice
    
    local schedule
    case "$choice" in
        1) schedule="*/30 * * * *" ;;
        2) schedule="0 * * * *" ;;
        3) schedule="0 */2 * * *" ;;
        4) schedule="0 */4 * * *" ;;
        5) schedule="0 */6 * * *" ;;
        6) schedule="0 */12 * * *" ;;
        7) schedule="0 0 * * *" ;;
        *) echo -e "${RED}✗ Invalid${RESET}"; return 1 ;;
    esac
    
    local script="/usr/local/bin/bluemesh-restart.sh"
    cat > "$script" <<'EOF'
#!/bin/bash
pkill -9 easytier 2>/dev/null || true
systemctl restart bluemesh@default
EOF
    chmod +x "$script"
    
    (crontab -l 2>/dev/null | grep -v "#bluemesh") 2>/dev/null || true
    (crontab -l 2>/dev/null; echo "$schedule $script #bluemesh") | crontab -
    
    echo -e "${GREEN}✓ Cronjob added: $schedule${RESET}"
    press_key
}

remove_cron() {
    crontab -l 2>/dev/null | grep -v "#bluemesh" | crontab - 2>/dev/null || true
    echo -e "${GREEN}✓ Cronjob removed${RESET}"
    press_key
}

# ============================================
# CONFIRM FUNCTION
# ============================================

confirm() {
    local message="${1:-Are you sure?}"
    local default="${2:-N}"
    local prompt="[y/N]"
    [[ "$default" = "Y" ]] && prompt="[Y/n]"
    
    read -rp "  $message $prompt " response
    response=${response:-$default}
    [[ "$response" =~ ^[Yy]$ ]]
}

# ============================================
# MENU
# ============================================

draw_menu() {
    draw_banner
    
    # Status
    if is_installed; then
        echo -e "  ${GREEN}● Core: Installed${RESET}"
    else
        echo -e "  ${RED}● Core: Not Installed${RESET}"
    fi
    
    if service_running; then
        echo -e "  ${GREEN}● Service: Running${RESET}"
    else
        echo -e "  ${RED}● Service: Stopped${RESET}"
    fi
    echo
    
    echo "  1. Install Core"
    echo "  2. Configure Network"
    echo "  3. Display Peers"
    echo "  4. Display Routes"
    echo "  5. Peer Center"
    echo "  6. Show Network Secret"
    echo "  7. View Service Status"
    echo "  8. Restart Service"
    echo "  9. Watchdog Configuration"
    echo "  10. Cronjob Settings"
    echo "  11. Check for Updates"
    echo "  12. Remove Service"
    echo "  13. Remove Core"
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
            1) echo && install_core ;;
            2) echo && configure_network ;;
            3) display_peers ;;
            4) display_routes ;;
            5) peer_center ;;
            6) show_secret ;;
            7) view_service_status ;;
            8) restart_service ;;
            9) configure_watchdog ;;
            10) configure_cron ;;
            11) check_for_updates ;;
            12) remove_service ;;
            13) remove_core ;;
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
