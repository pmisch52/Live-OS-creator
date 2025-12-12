#!/bin/bash
# Live-OS Tool für Debian 8.11 (Jessie) – Version 0.9999g
# 100% kompatibel: alte parted, kein wipefs, kein mkfs.fat-Problem
set -euo pipefail
IFS=$'\n\t'

if (( EUID != 0 )); then
    echo "This script must be run as root"
    sudo "$0" "$@"
    exit
fi

export FAT_LABEL="BOOT"
export EXT_LABEL="ROOT"
export EXTb_LABEL="STATE"
export MOUNT="/mnt2"
export MOUNT_FAT="/mnt2/usb-fat"
export MOUNT_EXT="/mnt2/usb-ext"
export SFS_PATH="/home/remastersys/ISOTMP/live"
export USER="debian"
export HOME_DIR="/home/$USER"

red="\033[1;31m"
green="\033[0;32m"
export blue="\033[1;34m"
purple="\033[1;35m"
cyan="\033[1;36m"
export reset="\033[0m"
italic="\e[3m"

check() {
    if [ $? -ne 0 ]; then
        echo -e "${red}FEHLER: $1 fehlgeschlagen!${reset}"
        read -p "ENTER → Menü" && menu
    fi
}

start() {

echo -e "${red}___________________________________________________${purple}"
cat << "EOF"
                       ___     __   __          
          |    | \  / |__  __ /  \ /__`         
          |___ |  \/  |___    \__/ .__/         
     __                       __  ___  ___      
    |__)  /\  |  | |__/  /\  /__`  |  |__  |\ | 
    |__) /~~\ \__/ |  \ /~~\ .__/  |  |___ | \| 
                                            
EOF
echo -e "${blue}$italic                  Version 0.9999f "
echo -e "                P.M. - 12.12.2025"
echo -e "${red}___________________________________________________${reset}"
}

cleanup() {
    clear
    echo "=============================================================="
    echo -e " (1) ${purple}System & Home säubern${reset}"
    echo "=============================================================="
    sudo -u "$USER" bash -c "
        rm -rf $HOME_DIR/.cache/* $HOME_DIR/.bash_history $HOME_DIR/.xsession* 2>/dev/null
        find $HOME_DIR/.config -name '*Cache*' -exec rm -rf {} + 2>/dev/null || true
        history -c
    "
    apt-get clean &>/dev/null || apt clean
    journalctl --vacuum-size=50M &>/dev/null || true
    echo -e "${purple}Größe: $(du -sh "$HOME_DIR")${reset}"
    echo -e "${green}Cleanup fertig!${reset}"
    read -p "ENTER → Menü" && menu
}

remaster() {
    clear
    echo "=============================================================="
    echo -e " (2) ${purple}SquashFS erstellen${reset}"
    echo "=============================================================="
    if ls "$SFS_PATH"/* &>/dev/null; then
        read -p "Alte Dateien löschen? (ja/nein): " c
        [[ "$c" == "ja" ]] && rm -rf "$SFS_PATH"/*
    fi
    ./remastersys-1 allow #|| check "Remastersys"
    echo -e "${green}   SquashFS fertig!${reset}"
    read -p "   ENTER → Menü" && menu
}

format() {
    clear
    echo "=============================================================="
    echo -e " (3) ${purple}USB-Stick partitionieren + GRUB (Debian 8.11)${reset}"
    lsblk
    echo "=============================================================="

    while true; do
        read -p "Gerät (z.B. sdb)? /dev/" STICK
        USB_DEV="/dev/$STICK"
        if [[ "$STICK" == "q" ]]; then
			echo "Abbruch !"
			sleep 1
			menu  # Ruft die Menü-Funktion erneut auf
		fi
        [ -b "$USB_DEV" ] && break
        echo -e "${red}Nicht gefunden!${reset}"
    done

    echo -e "${red}ALLES auf $USB_DEV wird GELÖSCHT!${reset}"
    read -p "Wirklich? (ja/NEIN): " confirm
    [[ "$confirm" != "ja" ]] && echo "Abgebrochen" && sleep 2 && menu

    mount | grep "^${USB_DEV}" | awk '{print $1}' | xargs -r umount || true
    sync

    echo "→ Lösche alte Daten..."
    dd if=/dev/zero of="$USB_DEV" bs=512 count=2048 status=none
    sync

    echo "→ Neue Partitionstabelle..."
    parted -s "$USB_DEV" mklabel msdos
    parted -s "$USB_DEV" mkpart primary fat16 1MiB 514MiB
    parted -s "$USB_DEV" set 1 boot on
    parted -s "$USB_DEV" mkpart primary ext4 514MiB 3514MiB
    parted -s "$USB_DEV" mkpart primary ext4 3514MiB 4014MiB

    echo "→ Warte auf Partitionen..."
    partprobe "$USB_DEV" 2>/dev/null || true
    sleep 2
    c=0
    while [ $c -lt 12 ] && [ ! -b "${USB_DEV}1" ]; do
        sleep 1; c=$((c+1))
    done
    [ ! -b "${USB_DEV}1" ] && echo 1 > /sys/block/${USB_DEV##*/}/device/rescan 2>/dev/null || true
    sleep 3

    [ ! -b "${USB_DEV}1" ] && echo -e "${red}Partitionen nicht erkannt – Stick raus & rein & nochmal versuchen${reset}" && read -p "ENTER" && menu

    echo "→ Formatiere..."
    mkfs.vfat -F 16 -n BOOT "${USB_DEV}1"
    mkfs.ext4 -F -L ROOT "${USB_DEV}2"
    mkfs.ext4 -F -L STATE "${USB_DEV}3"

    mkdir -p "$MOUNT_FAT" "$MOUNT_EXT"
    mount "${USB_DEV}1" "$MOUNT_FAT"
    mount "${USB_DEV}2" "$MOUNT_EXT"
    mkdir -p "$MOUNT_FAT/boot/grub" "$MOUNT_EXT/live"

    echo "→ GRUB installieren..."
    grub-install --target=i386-pc --boot-directory="$MOUNT_FAT/boot" --force "$USB_DEV"

    cat > "$MOUNT_FAT/boot/grub/grub.cfg" <<EOF
set timeout=3
menuentry "Debian LiveOS" {
    search --no-floppy --set=root --label ROOT
    echo "linux booting..."
    linux /live/vmlinuz boot=live config components quiet loglevel=0 audit=0 
    echo "vmlinuz started..."
    initrd /live/initrd.img
    echo "please wait.."
}
EOF

    umount "$MOUNT_FAT" "$MOUNT_EXT"
    sync
    echo -e "${green}FERTIG! $USB_DEV ist bootfähig!${reset}"
    read -p "ENTER → Menü" && menu
}

installsys() {
    clear
    echo "=============================================================="
    echo -e " (4) ${purple}Live-System kopieren${reset}"
    echo "=============================================================="
    lsblk
    read -p "Gerät (z.B. sdb)? /dev/" STICK
    USB_DEV="/dev/$STICK"
    mount "${USB_DEV}2" "$MOUNT_EXT" || { echo "Mount fehlgeschlagen"; read -p "ENTER" && menu; }
    read -p "Alles auf ROOT löschen? (ja/nein): " c
    [[ "$c" != "ja" ]] && umount "$MOUNT_EXT" && menu
    rm -rf "$MOUNT_EXT/live/"*
    
    rsync -avh --progress "$SFS_PATH/" "$MOUNT_EXT/live/"
    
    sync
    umount "$MOUNT_EXT"
    echo -e "${green}FERTIG! Stick ist startklar!${reset}"
    read -p "ENTER → Menü" && menu
}

menu() {
    clear
    start
    echo ""
    echo "   1) Cleanup "
    echo "   2) Remaster   "
    echo "   3) USB format + GRUB"
    echo "   4) System kopieren   "
    echo "   q) Beenden"
    echo -e "${red}___________________________________________________${reset}"
    echo ""
    read -p " > " n
    case "$n" in
        1) cleanup ;;
        2) remaster ;;
        3) format ;;
        4) installsys ;;
        q) echo -e "      ${cyan}Ciao !${reset}"; exit 0 ;;
        *) sleep 1; menu ;;
    esac
}

menu
