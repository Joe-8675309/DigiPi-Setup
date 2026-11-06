#!/bin/bash
sudo remount
clear

echo "========================================"
echo " Welcome to DigiPi Configuration Setup"
echo " v261103a"
echo "========================================"
echo

##### Future work todo
#read -p "Enter WiFi Name: " wifiName
#echo
#if [[ -z "$wifiName" ]]; then
#    echo "[ERROR] Connection name cannot be empty."
#    exit 1
#fi
#read -s -p "Enter WiFi Password: " wifiPass

echo
echo
echo "========================================"
echo " Hotspot Disable?"
echo "========================================"
echo

while true; do
echo "Do you want to remove the hotspot?"
echo "Does not apply to zero2w."
    read -r -p "(Y/N): " hotspotYesNo

    case "$hotspotYesNo" in
        [Yy])
            #echo "[INFO] User selected YES."
            break
            ;;
        [Nn])
            echo "[INFO] User selected NO."
            break
            ;;
        *)
            echo "[ERROR] Invalid input. Please enter Y or N."
            ;;
    esac
done

if [[ "$hotspotYesNo" =~ ^[Yy]$ ]]; then

CONFIG="/etc/NetworkManager/system-connections/hotspot.nmconnection"

echo "[1/2] Checking hotspot configuration..."

if [ -f "$CONFIG" ]; then
    if sudo rm "$CONFIG"; then
        echo "[SUCCESS] Hotspot configuration removed."
    else
        echo "[ERROR] Failed to remove hotspot configuration."
        exit 1
    fi
else
    echo "[INFO] Hotspot configuration does not exist. Nothing to remove."
fi

echo "[2/2] Reloading NetworkManager connections..."

if sudo nmcli connection reload; then
    echo "[SUCCESS] NetworkManager connections reloaded."
else
    echo "[ERROR] Failed to reload NetworkManager connections."
    exit 1
fi

fi

echo
echo "========================================"
echo " Filesystem Read-Write"
echo "========================================"
echo

read -r -p "Would you like to make the root partition read/write (rw) instead of read-only (ro)? (Y/N): " rootRW

if [[ "$rootRW" =~ ^[Yy]$ ]]; then

    echo "[INFO] Updating root partition mount options..."

    # Create updated fstab using the root mount point
    if sudo awk '
    BEGIN { updated=0 }

    /^[[:space:]]*#/ { print; next }

    $2 == "/" {
        n = split($4, opts, ",")

        for (i = 1; i <= n; i++) {
            if (opts[i] == "ro") {
                opts[i] = "rw"
                updated = 1
            }
        }

        $4 = opts[1]

        for (i = 2; i <= n; i++) {
            $4 = $4 "," opts[i]
        }
    }

    { print }

    END {
        if (!updated) exit 1
    }
    ' /etc/fstab | sudo tee /etc/fstab.tmp > /dev/null; then

        if sudo cp /etc/fstab.tmp /etc/fstab; then
            sudo rm -f /etc/fstab.tmp
            echo "[SUCCESS] Root partition configured as read/write."
        else
            echo "[ERROR] Failed to update /etc/fstab."
            sudo rm -f /etc/fstab.tmp
            exit 1
        fi

    else
        echo "[ERROR] Could not find a root filesystem entry with the ro option."
        sudo rm -f /etc/fstab.tmp
        exit 1
    fi

    echo
    echo "[INFO] Updated root filesystem entry:"
    awk '$2 == "/" { print }' /etc/fstab

    echo
    echo "[INFO] Remounting root filesystem..."

    if sudo mount -o remount,rw /; then
        echo "[SUCCESS] Root filesystem remounted as read/write."
    else
        echo "[WARNING] Root filesystem remount failed."
    fi

    echo
    echo "[INFO] Current root filesystem status:"
    findmnt -no SOURCE,FSTYPE,OPTIONS /

else
    echo "[INFO] Root partition configuration left unchanged."
fi

echo
echo "========================================"
echo " Hostname Configuration"
echo "========================================"
echo

CURRENT_HOSTNAME=$(hostname)

echo "[INFO] Current hostname: $CURRENT_HOSTNAME"

read -r -p "Would you like to update the hostname? (Y/N): " updateHostname

if [[ "$updateHostname" =~ ^[Yy]$ ]]; then

    read -r -p "Enter new hostname: " setHostname

    if [[ -z "$setHostname" ]]; then
        echo "[ERROR] Hostname cannot be empty."
        exit 1
    fi

    echo "[INFO] Updating /etc/hosts"

    if sudo sed -i "s/127.0.1.1[[:space:]].*/127.0.1.1    $setHostname/" /etc/hosts; then
        echo "[SUCCESS] /etc/hosts updated."
    else
        echo "[ERROR] Failed to update /etc/hosts."
        exit 1
    fi

    echo "[INFO] Applying hostname..."

    if sudo hostnamectl set-hostname "$setHostname"; then
        echo "[SUCCESS] Hostname updated to: $setHostname"
    else
        echo "[ERROR] Failed to apply hostname."
        exit 1
    fi





echo "[INFO] Updating website HTML..."

HEADER="/var/www/html/header.php"

if [[ ! -f "$HEADER" ]]; then
    echo "[ERROR] Header file not found: $HEADER"
    exit 1
fi

# Backup original header
sudo cp "$HEADER" "${HEADER}.bak"

# Update browser tab title
if sudo sed -i "s|<title>[^<]*</title>|<title>${setHostname}</title>|" "$HEADER"; then
    echo "[SUCCESS] Browser title updated."
else
    echo "[ERROR] Failed to update browser title."
    exit 1
fi

# Update visible website heading
if sudo sed -i "s|<strong>[^<]*</a></strong>|<strong>${setHostname}</a></strong>|" "$HEADER"; then
    echo "[SUCCESS] Website heading updated."
else
    echo "[ERROR] Failed to update website heading."
    exit 1
fi


else
    echo "[INFO] Hostname unchanged."
fi

echo
echo "========================================"
echo " APRS-IS / Internet Gateway Configuration"
echo "========================================"
echo

echo "[INFO] Disabling APRS-IS prevents DigiPi from automatically forwarding"
echo "       received RF APRS packets and internet beacons to aprs.fi."
echo "       This can significantly reduce network usage on metered or"
echo "       low-bandwidth connections. Local RF APRS reception and"
echo "       transmission will continue to operate normally."
echo
read -r -p "Would you like to disable IGSERVER, IGLOGIN and PBEACON? (Y/N): " RESPONSE

if [[ "$RESPONSE" =~ ^[Yy]$ ]]; then

    CONFIG="/home/pi/direwolf.tnc.conf"

    if [[ ! -f "$CONFIG" ]]; then
        echo "[ERROR] Direwolf configuration not found."
        exit 1
    fi

    echo "[INFO] Creating configuration backup..."

    if ! sudo cp "$CONFIG" "${CONFIG}.bak"; then
        echo "[ERROR] Failed to create backup."
        exit 1
    fi

    echo "[INFO] Disabling APRS-IS and internet beaconing..."

    if sudo sed -i -E \
        '/^[[:space:]]*(IGSERVER|IGLOGIN|PBEACON)([[:space:]]|$)/s/^/# DISABLED: /' \
        "$CONFIG"; then

        echo "[SUCCESS] IGSERVER disabled."
        echo "[SUCCESS] IGLOGIN disabled."
        echo "[SUCCESS] PBEACON disabled."

    else
        echo "[ERROR] Failed to update Direwolf configuration."
        exit 1
    fi

#    echo "[INFO] Updated configuration:"
#    grep -E 'IGSERVER|IGLOGIN|PBEACON' "$CONFIG"

#    echo "[SUCCESS] APRS internet gateway settings disabled."

else
    echo "[INFO] APRS-IS configuration left unchanged."
fi


echo "========================================"
echo " Static IP Configuration - eth0"
echo "========================================"
echo

echo "[INFO] A static IP will be added to eth0."
echo "       This will be IN ADDITION to any DHCP address"
echo "       received from the network."
echo ""
echo "[WARNING] DigiPi may have multiple IP addresses."
echo "          Ensure the static IP is not already in use"
echo "          by another device on your network."
echo ""
echo "[INFO] IP address must use CIDR notation."
echo "       Example: 192.168.10.100/24"
echo ""

read -r -p "Would you like to configure a static IP? (Y/N): " RESPONSE

if [[ "$RESPONSE" =~ ^[Yy]$ ]]; then

    DEFAULT_IP="192.168.1.50/24"

    while true; do
        read -r -p "Enter static IP [$DEFAULT_IP]: " STATIC_IP

        STATIC_IP=${STATIC_IP:-$DEFAULT_IP}

        # Validate IPv4 address and CIDR notation
        if python3 -c '
import ipaddress, sys
try:
    ipaddress.IPv4Interface(sys.argv[1])
except ValueError:
    sys.exit(1)
' "$STATIC_IP"; then
            break
        else
            echo "[ERROR] Invalid IPv4 CIDR address."
            echo "[INFO] Example: 192.168.1.50/24"
        fi
    done

    echo
    echo "[INFO] Selected static IP: $STATIC_IP"

    echo
    echo "[INFO] Checking cron installation..."

    # Install cron if it is not already installed
    if ! command -v crontab >/dev/null 2>&1; then
        echo "[INFO] Cron is not installed. Installing..."

        sudo apt-get update

        if ! sudo apt-get install -y cron; then
            echo "[ERROR] Failed to install cron."
            exit 1
        fi
    fi

    echo "[INFO] Enabling cron service..."

    if ! sudo systemctl enable --now cron; then
        echo "[ERROR] Failed to enable or start cron."
        exit 1
    fi

    CRON_ENTRY="* * * * * /sbin/ip addr replace $STATIC_IP dev eth0 2>/dev/null"
    CRON_FILE=$(mktemp)

    trap 'rm -f "$CRON_FILE"' EXIT

    echo "[INFO] Updating root crontab..."

    # Read existing crontab, allowing an empty crontab
    sudo crontab -l > "$CRON_FILE" 2>/dev/null || true

    # Remove previous DigiPi static IP configuration
    sed -i '/# DIGIPI_STATIC_ETH0/d' "$CRON_FILE"
    sed -i '\|/sbin/ip addr \(add\|replace\) .* dev eth0|d' "$CRON_FILE"

    # Add new static IP configuration
    {
        echo "# DIGIPI_STATIC_ETH0"
        echo "$CRON_ENTRY"
    } >> "$CRON_FILE"

    if sudo crontab "$CRON_FILE"; then
        echo "[SUCCESS] Static IP added to root crontab."
        echo "[INFO] Address: $STATIC_IP"
        echo "[INFO] Interface: eth0"
        echo "[INFO] Address will be applied by cron within one minute."
    else
        echo "[ERROR] Failed to update root crontab."
        exit 1
    fi

    echo
    echo "[INFO] Verifying cron configuration..."
    sudo crontab -l

else
    echo "[INFO] Static IP configuration skipped."
fi


echo
echo "========================================"
echo " PAT Persistent Email Configuration"
echo "========================================"

PAT_SCRIPT="/home/pi/pat.sh"
MAILBOX="/home/pi/local/share/pat/mailbox"

echo ""
echo "[INFO] Persistent email storage preserves"
echo "       your PAT emails between reboots."
echo ""
echo "[WARNING] This requires the root filesystem"
echo "          to be mounted read/write (rw)."
echo ""

read -r -p "Would you like to make emails persistent? (Y/N): " RESPONSE

if [[ "$RESPONSE" =~ ^[Yy]$ ]]; then

    # Check root filesystem
    ROOT_MODE=$(findmnt -n -o OPTIONS /)

    if [[ ",$ROOT_MODE," != *",rw,"* ]]; then
        echo "[ERROR] Root filesystem is mounted read-only."
        echo "[INFO] Enable rw mode and run this configuration again."
        exit 1
    fi

    echo "[SUCCESS] Root filesystem is writable."

    # Verify PAT script
    if [[ ! -f "$PAT_SCRIPT" ]]; then
        echo "[ERROR] PAT script not found: $PAT_SCRIPT"
        exit 1
    fi

    # Check for existing configuration
    if grep -qF 'DIGIPI_PAT_MAILBOX' "$PAT_SCRIPT"; then
        echo "[INFO] PAT mailbox configuration already exists."
#        exit 0
    fi

    # Create persistent mailbox directory
    echo "[INFO] Creating persistent mailbox directory..."

    if ! sudo mkdir -p "$MAILBOX"; then
        echo "[ERROR] Could not create persistent mailbox."
        exit 1
    fi

    # Preserve temporary mailbox contents
    echo "[INFO] Preserving temporary emails..."

    if sudo test -d /run/.local/share/pat/mailbox &&
       ! sudo test -L /run/.local/share/pat/mailbox; then

        sudo rsync -avh --ignore-existing \
            /run/.local/share/pat/mailbox/ "$MAILBOX/" || exit 1
    fi

    # Preserve existing local mailbox contents
    echo "[INFO] Preserving existing local emails..."

    if sudo test -d /home/pi/.local/share/pat/mailbox &&
       ! sudo test -L /home/pi/.local/share/pat/mailbox; then

        sudo rsync -avh --ignore-existing \
            /home/pi/.local/share/pat/mailbox/ "$MAILBOX/" || exit 1
    fi

    # Backup PAT script
    echo "[INFO] Backing up PAT script..."

    if ! sudo cp "$PAT_SCRIPT" "${PAT_SCRIPT}.bak"; then
        echo "[ERROR] Failed to back up PAT script."
        exit 1
    fi

    # Insert mailbox configuration
    echo "[INFO] Updating PAT startup script..."

    sudo sed -i '/\/usr\/bin\/pat http/i\
# DIGIPI_PAT_MAILBOX\
mkdir -p /run/.local/share/pat\
mkdir -p /home/pi/.local/share/pat\
ln -sfn /home/pi/local/share/pat/mailbox /run/.local/share/pat/mailbox\
ln -sfn /home/pi/local/share/pat/mailbox /home/pi/.local/share/pat/mailbox\
' "$PAT_SCRIPT"

    if ! grep -qF 'DIGIPI_PAT_MAILBOX' "$PAT_SCRIPT"; then
        echo "[ERROR] Failed to update PAT script."
        exit 1
    fi

else
    echo "[INFO] PAT configuration left unchanged."
fi


echo
echo "========================================"
echo " COMPLETED"
echo "========================================"


