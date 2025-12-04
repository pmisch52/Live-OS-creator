#!/bin/bash

#######################################################################
#
#        Live-OS erstellen   ( 4.12.2025 )  -  Version 0.9999c
#        cleanup, remaster, partition, installsys 
#
#######################################################################

if [ $EUID -ne 0 ]; then
   echo "This script must be run as root: "
   sudo $0
   #sleep 1
   exit 1
fi

#######################################################################
#   Logging
#   exec > >(tee -a "/tmp/logfile.txt") 2>&1
#

#######################################################################
#   Globale (modulüberschreitende) Werte (EXPORT)
# - Variablen, keine Konstanten, in allen Funktionen verfügbar,
# - brauchen nicht explizit eingebunden ("gesourced") werden

export FAT_LABEL="BOOT"
export EXT_LABEL="ROOT"
export EXTb_LABEL="STATE"

#export USB_DEV="/dev/sdb"

export MOUNT="/mnt2"
export MOUNT_FAT="/mnt2/usb-fat"
export MOUNT_EXT="/mnt2/usb-ext"

# Für remastersys 4.x:
export SFS_PATH="/home/remastersys/ISOTMP/live"
# Für remastersys 3.x:
#export SFS_PATH="/home/remastersys/remastersys/ISOTMP/live"

export USER="debian"
export HOME_DIR="/home/$USER"

export red="\033[1;31m"
export green="\033[0;32m"
export blue="\033[1;34m"
export purple="\033[1;35m"
export bold="\033[1m"
export reset="\033[0m"
export cyan='\033[1;36m'
export bgcyan="\033[46m"
export italic="\e[3m"
#export bg2="\e]11;#000000\a" # Background
#export bg="\e]11;#112233\a"

#######################################################################
#   FUNKTIONSPFADE ("Prototypen") 
# - werden nur bei Modularisierung benötigt  

#. ./remastersys-2.sh    # Remaster
#####################
#. ./modules/help.sh    # Anleitung Hilfe
#####################
#. ./modules/cleanup.sh # System säubern
#####################
#. ./modules/remaster.sh   # System remastern
#####################
#. ./modules/format.sh   # USB format GRUB
#####################
#. ./modules/installsys.sh  # USB install SFS vmlinuz
#####################

########################################################################
# Testfunktion 

test() {
	
    if [ $? -ne 0 ]; then
	echo " !!!!! "
        echo " >> ' $1 ' ist schief gelaufen ;-( <<"
        echo " !!!!! "
        read n
        menu
        return 1 
    fi
}

########################################################################
#       APP-STARTBILD
########################################################################

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
echo -e "${blue}$italic                  Version 0.9999 "
echo -e "                P.M. @ 27.11.2025"
echo -e "${red}___________________________________________________${reset}"
}

########################################################################
# Aufräumen 
########################################################################

cleanup() {
	clear
	echo "============================================================="
    echo -e " (1) ${purple}Bereinige den Home-Ordner ($HOME_DIR)...${reset}"
    echo -e "     Wichtige Browser-/Desktop-Einstellungen bleiben erhalten."
    sleep .3

    # Führe die Löschbefehle als USER aus:
sudo -u $USER bash << EOF
#rm -rf "$HOME_DIR/.cache/spotify/Default/Cache"  2>/dev/null
#rm -rf "$HOME_DIR/.cache/spotify/Browser/*/Cache"  2>/dev/null
#rm -rf "$HOME_DIR/.cache/spotify/Data"  2>/dev/null
#rm -rf "$HOME_DIR/.cache/spotify/Storage/*"  2>/dev/null
#rm -rf "$HOME_DIR/.cache/spotify/Users/*/primary.ldb/*"  2>/dev/null

rm -rf "$HOME_DIR/.cache/chromium/Default/Cache"  2>/dev/null
rm -rf "$HOME_DIR/.cache/chromium/Default/Code Cache"  2>/dev/null
rm -rf "$HOME_DIR/.config/chromium/optimization_guide_model_store" 2>/dev/null
rm -rf "$HOME_DIR/.config/chromium/GrShaderCache" 2>/dev/null
rm -rf "$HOME_DIR/.config/chromium/Dictionaries" 2>/dev/null
rm -rf "$HOME_DIR/.config/chromium/Default/*Cache" 2>/dev/null
rm -rf "$HOME_DIR/.config/chromium/BrowserMetrics" 2>/dev/null
rm -rf "$HOME_DIR/.config/chromium/DeferredBrowserMetrics" 2>/dev/null
rm -rf "$HOME_DIR/.config/chromium/Default/Service Worker" 2>/dev/null
rm -rf "$HOME_DIR/.config/chromium/Default/File System" 2>/dev/null
rm -rf "$HOME_DIR/.config/chromium/Default/IndexedDB" 2>/dev/null
rm -rf "$HOME_DIR/.config/chromium/WasmTtsEngine/" 2>/dev/null
rm -rf "$HOME_DIR/.config/chromium/OnDeviceHeadSuggestModel/*" 2>/dev/null

## ACHTUNG Browser PWAs - nicht löschen !
rm -rf "$HOME_DIR/.config/chromium/Default/WebStorage" 2>/dev/null

rm -rf "$HOME_DIR/.config/chromium/Default/Cache" 2>/dev/null
rm -rf "$HOME_DIR/.config/chromium/Default/Code Cache/" 2>/dev/null
rm -rf "$HOME_DIR/.config/chromium/Default/GPUCache/" 2>/dev/null
rm -rf "$HOME_DIR/.config/chromium/Default/Service Worker/CacheStorage" 
rm -rf "$HOME_DIR/.config/chromium/Default/IndexedDB/" 2>/dev/null
rm -rf "$HOME_DIR/.config/chromium/Default/Extensions/" 2>/dev/null

rm -rf "$HOME_DIR/.config/chromium/component_crx_cache" 2>/dev/null
rm -rf "$HOME_DIR/.config/chromium/screen_ai" 2>/dev/null
rm -rf "$HOME_DIR/.config/chromium/GrShaderCache/" 2>/dev/null

#rm -rf $HOME_DIR/.openoffice

rm  $HOME_DIR/.xsession* 2>/dev/null
rm -rf $HOME_DIR/.cache/thumbnails 2>/dev/null 
rm -rf $HOME_DIR/.cache/fontconfig 2>/dev/null
rm -rf $HOME_DIR/.cache/rclone/* 2>/dev/null
rm -rf $HOME_DIR/.cache/mesa_shader_cache/* 2>/dev/null

#rm -rf ./.local/share/recently-used.* 2>/dev/null

# Allgemeine User-Caches und Historie
rm -rf "$HOME_DIR/.cache/thumbnails/*" 2>/dev/null
rm -rf "$HOME_DIR/.bash_history" 2>/dev/null
history -c # Löscht die aktuelle Shell-History
EOF
    echo "     Browser- und User-Caches bereinigt."

    #apt clean
    journalctl --vacuum-size=50M 2>/dev/null 
    umount /home/STATE                             # <== ??
    umount /opt/openoffice 2>/dev/null
    umount /media/debian/* 2>/dev/null
    
    echo -e "${red}     Grösse $HOME_DIR: `du -s /home/debian | cut -f 1` kB ${reset}"
    echo -e "============================================================="
    echo -e "${purple}     Cleanup abgeschlossen ${reset}  <ENTER>"
    read n
    menu
}

########################################################################
# Remaster
########################################################################

remaster() {
    clear
    clear
    echo "=============================================================="
    echo -e "  (2) ${purple} R E M A S T E R S Y S  - ${reset}"
    echo -e "       leicht modifiziert und angepasst "
    echo -e "       Dank an die Entwickler ! "
    echo -e "=============================================================="
    
    if [ -d "/run/live/rootfs/" ] 
        then 
        echo "- Geht nicht von einem Live-System !" 
        read n
        menu
    fi
                   
    if [ -d "$SFS_PATH" ]; then
        echo -e "${red}  LIVE-Dateien sind schon vorhanden: ${reset}"
        #ls $SFS_PATH/*
        read -p "  Dateien löschen ? (ja/nein)" confirm
            if [ "$confirm" != "ja" ]; then
                echo -e "${red}  ❌ Aktion abgebrochen <ENTER> ${reset}"
                read n
                menu
                return 1
            fi
        #remastersys clean # Dateien löschen
        rm -f $SFS_PATH/*
    fi
    
    ################################
    # Original Remastersys aufrufen
    # remastersys backup cdfs 
    ################################
    # oder meine Kopie aufrufen
    . ./remastersys.sh allow   
    ####################################################################

    # Mountpunkt wieder einhängen, wurde bei cleanup ausgehängt
    mount -o loop /opt/OO4.sfs /opt/openoffice 2>/dev/null || true
	mount /dev/disk/by-label/STATE /mnt/STATE
    echo -e "${purple}- LIVE-Dateien erstellt ${reset} <ENTER> "
    read n
    menu
}
    
########################################################################
# format() - USB Stick partitionieren   
#            und Bootfähig machen (GRUB)
########################################################################

format() {
    clear
    echo ""
    echo "=============================================================="
    echo -e "   (3) ${purple} USB-Stick partitionieren, "
    echo -e "        formatieren, GRUB einrichten ${reset}"
    echo -e "     ${blue}   BOOT - ROOT - STATE ${reset}"
    echo "=============================================================="
    lsblk
    echo "=============================================================="
    echo ""

    # SICHERHEITS-CHECK - Gerätename validieren ------------------------
    while true; do
        read -p "- Welches ist der Stick? (sdb, sdc) : /dev/" STICK
        USB_DEV="/dev/"$STICK
        # Prüfen, ob das Gerät existiert und ein Blockgerät ist
        if [ -b "$USB_DEV" ]; then
            break # Gerät ist gültig, Schleife verlassen
        else
            echo -e "${red} FEHLER: Das Gerät $USB_DEV existiert nicht oder ist kein Blockgerät.${reset}"
            echo " Bitte geben Sie einen gültigen Gerätenamen OHNE '/dev/' ein "
            read -p " oder 'q' zum Abbrechen : " confirm
            if [ "$confirm" == "q" ]; then
                #echo -e "${red} ❌ Aktion abgebrochen. Rückkehr zum Hauptmenü  <ENTER>"
                #read n
                menu
                #return 1
            fi
        fi
    done

    # Vorab-Unmount (um Mountfehler beim Sicherheits-Check zu vermeiden)
    umount "${USB_DEV}"?* 2>/dev/null # || echo "Fehler Zeile 288"
    echo -e "${red}- Sicher, dass $USB_DEV der USB-Stick ist ? ${reset}"
    read -p "- ALLE DATEN WERDEN GELÖSCHT! (ja/nein): " confirm

    if [ "$confirm" != "ja" ]; then
        echo -e "${red} ❌ Aktion abgebrochen - <ENTER> ${reset}"
        read n
        menu
        return 1 
    fi

    ### PARTITIONIERUNG ################################################
    
    echo "=============================================================="
    echo "- Starte Partitionierung..."
    
    # Unmount aller Partitionen (falls noch gemountet)
    umount ${USB_DEV}?* 2>/dev/null || echo "Zeile 306"
    
    # Partitionstabelle löschen 
    dd if=/dev/zero of=${USB_DEV} bs=512 count=1 conv=notrunc

    # Neue Partitionstabelle (MBR) erstellen
    # PART=gpt
    PART=msdos 
    parted --script $USB_DEV mklabel $PART 
    test line_314
    
    ####################################################################
    # - Partionieren und formatieren 
    
    SIZE1="257"  # BOOT
    SIZE2="3000" # ROOT
    SIZE3="500"  # STATE
    
    echo ""
    echo "============================="
    echo -e "   Neue Partitionen:" 
    echo -e "   BOOT:  ${SIZE1} "
    echo -e "   ROOT:  ${SIZE2} "
    echo -e "   STATE: $SIZE3 "
    echo "============================="
    echo -e "$red OK? (j/n) $reset"
    read -p " " confirm
    
    if [ "$confirm" != "j" ]; then
        echo -e "${red} ❌ Aktion abgebrochen - <ENTER> ${reset}"
        read n
        menu
        return 1  
    fi
    
    # Umrechnen für Parted :
    SIZE01=$SIZE1"MiB"
    SIZE02=$SIZE2"MiB"
    SIZE03=$((SIZE2+SIZE3))"MiB"
    
    #echo "$SIZE01   $SIZE02   $SIZE03"
    
    # Partition 1: FAT16, BOOT
    parted --script $USB_DEV mkpart primary fat16 1MiB $SIZE01
    parted --script $USB_DEV set 1 boot on

    # Partition 2: ext2, ROOT
    parted --script $USB_DEV mkpart primary ext2 $SIZE01 $SIZE02

    # Partition 3: ext4, STATE
    parted --script $USB_DEV mkpart primary ext4 $SIZE02 $SIZE03

    # Formatieren (MKFS Befehle müssen zum Dateisystem der Partition passen)
    #mkfs.vfat -F32 -n "$FAT_LABEL" "${USB_DEV}1"
    mkfs.fat -F16 -n "$FAT_LABEL" "${USB_DEV}1"
	test line_360

    mkfs.ext2 -L "$EXT_LABEL" "${USB_DEV}2"  # ROOT als EXT2
    mkfs.ext4 -L "$EXTb_LABEL" "${USB_DEV}3" # STATE als EXT4 
    sync
    # Mountpunkte erstellen 
    mkdir -p "$MOUNT" "$MOUNT_FAT" "$MOUNT_EXT"
    sync
    # Partitionen mounten
    mount "${USB_DEV}1" "$MOUNT_FAT"
    mount "${USB_DEV}2" "$MOUNT_EXT"
    test line_373
    sync
    # Verzeichnisse erstellen (GRUB und Live-OS Struktur)
    mkdir -p $MOUNT_FAT/boot/grub
    mkdir -p $MOUNT_EXT/live
    sync
    
    ####################################################################
    # - GRUB installieren 

    echo -e "${red}- GRUB wird auf ${USB_DEV} installiert ... ${reset}"
    grub-mkconfig -o $MOUNT_FAT/boot/grub/grub.cfg
    grub-install --target=i386-pc --boot-directory="$MOUNT_FAT/boot" "$USB_DEV" --force
	test line_386

    # grub.cfg erzeugen 

cat > "$MOUNT_FAT/boot/grub/grub.cfg" <<EOF
if loadfont /boot/grub/font.pf2
then
  set gfxmode=auto
  insmod efi_gop
  insmod efi_uga
  insmod gfxterm
  terminal_output gfxterm
fi
set timeout=1

# Auto-detect squashfs module ###############
if insmod squash4; then
    true
elif insmod squashfs; then
    true
else
    echo "Kein SquashFS-Modul gefunden!"
fi

menuentry "LiveOS" {
  #insmod squashfs
  #insmod squash4
  insmod ext2
  search --no-floppy --set=root --label ROOT
  echo 'vmlinuz'
  linux /live/vmlinuz boot=live ro quiet loglevel=0 components config audit=0 nosplash fsck.mode=skip 
  echo 'initrd'
  initrd /live/initrd.img
  echo 'please wait...'
}
EOF
    # WICHTIG: Unmounten MUSS am Ende fehlerfrei erfolgen
    umount $MOUNT_FAT || echo "Fehler 409"
    umount $MOUNT_EXT || echo "Fehler 410"
    
    # System wieder in den Ausgangszustand zurückbringen:
    mount -o loop /opt/OO4.sfs /opt/openoffice 2>/dev/null || true
    mount /dev/disk/by-label/STATE /home/STATE 2>/dev/null || true 
    
    # Signalisiert Erfolg
    echo -e "${purple} ✅ ${USB_DEV} ist partitioniert und bootfähig (GRUB)${reset}"
    echo -e "${red} Weiter mit Menupunkt (4): Installieren -  <ENTER> ${reset}"
    read n
    menu 
}

#######################################################################
#       Systemdateien auf USB-Stick kopieren: 
#       filesystem.squashfs, vmlinuz, initrd
#######################################################################

installsys() {
    clear
    echo ""
    echo "=============================================================="
    echo -e " (4) ${purple} Systemdateien auf ext. Datenträger kopieren"
    echo -e "      (filesystem.sfs, vmlinuz, initrd) ${reset}"
    
    echo "=============================================================="
    
    if [ ! -d ${SFS_PATH} ]; then
        echo -e "${red} FEHLER: Systemdateien existieren noch nicht. "
        echo -e " Bitte Menupunt 2 (SFS erstellen) ausführen! <ENTER>${reset}"
        read n
        umount "$MOUNT_EXT" 2>/dev/null 
        menu
        return 1 
    fi
    lsblk
    echo "=============================================================="
    #echo ""
    
    # SICHERHEITS-CHECK: Gerätename einlesen & validieren 
    while true; do
        read -p "- Welches ist der Stick? (sdb, sdc) : /dev/" STICK
        USB_DEV="/dev/"$STICK
        # Prüfen, ob das Gerät existiert und ein Blockgerät ist
        if [ -b "$USB_DEV" ]; then
            break # Gerät ist gültig, Schleife verlassen
        else
            #umount "$MOUNT_EXT" #2>/dev/null 
            echo -e "${red} FEHLER: Das Gerät $USB_DEV existiert nicht oder ist kein Blockgerät.${reset}"
            echo -e " Bitte geben Sie einen gültigen Gerätenamen OHNE '/dev/' ein "
            read -p " oder 'q' zum Abbrechen : " confirm
            
            if [ "$confirm" == "q" ]; then
                echo -e "${red} ❌ Aktion abgebrochen. Rückkehr zum Hauptmenü  <ENTER>"
                #umount "$MOUNT_EXT" #2>/dev/null 
                read n
                menu
                return 1
            fi
        fi
    done
    umount "$MOUNT_EXT" 2>/dev/null # || echo "Fehler 489"
    mount "${USB_DEV}2" "$MOUNT_EXT" || echo "Fehler 490"
    
    echo "  ${USB_DEV}2 ==> $MOUNT_EXT gemountet"
    echo "=============================================================="
    read -p "- ALLE DATEN WERDEN GELÖSCHT! (ja/nein):" confirm
    if [ "$confirm" != "ja" ]; then
        echo -e "${red} ❌ Aktion abgebrochen. Rückkehr zum Hauptmenü mit <ENTER>"
        read n
        menu
        return 1
    fi
    
     echo -e "${red}- Systemdateien werden kopiert, bitte warten...${reset}"
    
    # Alte Dateien löschen 
    rm $MOUNT_EXT/live/* 2>/dev/null # || echo "Fehler 504"
    sync 
    
    # LIVE-Dateien von RemasterSys auf Datenträger kopieren
    rsync -avh --progress $SFS_PATH/*  $MOUNT_EXT/live  
    test line_492
        
    echo -e "${red}- CACHE muss geleert werden, dauert noch ein bisschen ;-) ${reset}"
    sync
    umount "$MOUNT_EXT" -f -l 2>/dev/null
    umount "${USB_DEV}2" -f -l 2>/dev/null
    umount "$MOUNT" -f -l 2>/dev/null 
    rmdir $MOUNT_EXT/live 2>/dev/null || true 
    mount -o loop /opt/OO4.sfs /opt/openoffice 2>/dev/null || true
    #mount /dev/disk/by-label/STATE /home/STATE  2>/dev/null || true 
    test line_502
    sync
    echo " "
    echo -e "${purple}- Fertig - ${USB_DEV} ist bereit zum Testen! <ENTER> ${reset}"
    read n
    menu
}

#######################################################################
# help() 

help() {
    less ./help.txt
    menu
}

########################################################################
# Aufräumen & Exit

exitus() {
    tput cnorm 
    echo -e "${reset}" 
    #mount /dev/disk/by-label/STATE /home/STATE #2>/dev/null
    mount -o loop /opt/OO4.sfs /opt/openoffice 2>/dev/null 
    sync
    exit 
}
########################################################################
# MENU    

menu() {
    clear
    start # Eingangsbild anzeigen 
    echo -e "${reset}" 
    #echo -e "${bg}"     # blauer Hintergrund
    tput civis # hide cursor

    echo "    0) ANLEITUNG - bitte lesen           (help.sh)"
    #echo 
    echo "   ----------------------------------------------"
    echo -e " $cyan  LiveOS erzeugen: $reset "
    #echo 
    echo "    1) - System & Home säubern        (cleanup.sh)"
    echo "    2) - SquashFS erstellen          (remaster.sh)"
    #echo 
    echo "   ----------------------------------------------"
    #echo
    echo -e " $cyan  LiveOS installieren: $reset-> USB   "
    echo "    3) - Partition, Format, GRUB       (format.sh)"
    echo "    4) - Installieren              (installsys.sh)"
    #echo 
    echo "   ----------------------------------------------"
    echo "    q) - Quit ..."
    echo -e "${red}___________________________________________________${reset}"
    echo -e "$cyan"
    read -p  "    > " n
    echo -e "$reset"
    
    case $n in 
        0) help;;
        1) cleanup;;
        2) remaster;;
        3) format;;
        4) installsys;;
        q) exitus;; 
        *) echo -e " $italic      ungültige Eingabe $reset" && sleep .6 && clear && menu;;
    esac
}
menu
