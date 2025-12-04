#!/bin/bash

######################################################################
#  - Installation auf Datenträger  (02.12.2025) V.0.9999a
####################################################################### 

if [ $EUID -ne 0 ]
then
    echo "Dieses Skript muss als Root ausgeführt werden." 
    sleep 0.5
    exec sudo $0
fi

#######################################################################
#   Globale (modulüberschreitende) Werte/Variablen (EXPORT)

export TARGET_DEST=""
export FULL_DEV=""
export SFS_PATH=""

export red="\033[1;31m"
export green="\033[0;32m"
export blue="\033[1;34m"
export purple="\033[1;35m"
export reset="\033[0m"

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
# INSTALL-1 - LIVE-Installation 
########################################################################

install1() {

    ## Testen ob es ein LIVE-System ist 
    
    if  [ ! -d "/run/live/" ]; then 
        echo -e "$red Dies ist kein Live-System...$reset" 
        read n 
        menu 
        return 1 
    fi
    clear
    echo ""
    echo "=============================================================="
    echo -e " ${purple}       LIVE-System kopieren "
    echo -e "      (filesystem.sfs, vmlinuz, initrd) ${reset}"
    echo "=============================================================="
    lsblk
    echo "=============================================================="
    #echo ""
    
    # SICHERHEITS-CHECK: Gerätename einlesen & validieren 
    while true; do
        read -p "- Zielgerät wählen (sdb, sdc) : /dev/" STICK
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
    
    echo "=============================================================="
    read -p "- ALLE DATEN WERDEN GELÖSCHT! (ja/nein):" confirm
    if [ "$confirm" != "ja" ]; then
        echo -e "${red} ❌ Aktion abgebrochen. Rückkehr zum Hauptmenü mit <ENTER>"
        read n
        menu
        return 1
    fi
    #ls $MOUNT_EXT
    
    echo -e "${red}- Systemdateien werden kopiert, bitte warten...${reset}"
    
    # 1:1 Laufendes System (Speicher) auf Datenträger kopieren 
    
    dd if=/dev/sda of="${USB_DEV}" bs=1M count=4000 status=progress && sync
    test line_104
    
    echo -e "${purple}- Fertig - ${USB_DEV} ist bereit zum Testen! <ENTER> ${reset}"
    read n
    menu
}

########################################################################
# INSTALL-2 - VOLL-Installation 
########################################################################

install2() {
    
    clear
    echo ""
    echo "=============================================="
    echo -e "${purple}  - Vollversion installieren - ${reset}"
    echo "=============================================="
    echo ""
    lsblk    
    echo ""
    echo "=============================================="
    
    # Gerätenamen ohne Ziffer abfragen (z.B. sda)
    echo -e "${purple}- Zielgerät wählen (${red}sda, sdb)${reset}"
    read -p "  /dev/" FDISK_DEV
    FULL_DEV="/dev/$FDISK_DEV"
    
    # Sicherheitsprüfung Gerät
    if [ ! -b "$FULL_DEV" ]; then
        echo -e "${red} - FEHLER: Gerät $FULL_DEV existiert nicht. Abbruch! <ENTER>${reset}"
        read n
        #clear
        menu
        return 1
    fi
    echo -e "${red}- Bestätigung: Alle Daten auf $FULL_DEV werden gelöscht!"
    read -p "  (JA/nein in Großbuchstaben):" final_confirm
    if [ "$final_confirm" != "JA" ]; then
        echo -e "${red}❌ Partitionierung abgebrochen. <ENTER>${reset}"
        read n
        menu
        return 1
    fi
    
    # Alle Partitionen unmounten
    echo -e "${blue}Unmounte alle Partitionen auf $FULL_DEV...${reset}"
    umount "${FULL_DEV}"?* -f -l
    #test line_155
    
    # Alte Partitionstabelle löschen 
    #echo "dd if=/dev/zero of=${FULL_DEV} bs=512 count=10"
    dd if=/dev/zero of=${FULL_DEV} bs=512 count=10
    
    # Neue Partitionstabelle erstellen 
    PART=msdos
    #PART=gpt
    echo -e "${blue} Erstelle ${PART}-Partitionstabelle ${reset}"
    parted --script "$FULL_DEV" mklabel $PART || { 
        echo -e "${red} FEHLER: Partitionstabelle konnte nicht erstellt werden.${reset}" 
        read n
        menu
        return 1; 
    }
    
    ####################################################################
    # Partitionierung
      
    size1="60%"
    size2="40%"
    size3=""
    size4="100%"
    
    echo -e "$blue===================================="
    echo -e "    <<  Partionierung  >>  "
    echo -e " P1 (ROOT) : $size1"
    echo -e " P2 (STATE): $size2"
    read -p " Korrekt ? (j/n)" confirm 
    
    if [ "$confirm" != "j" ]; then
		size1="10000MiB"
		size2="1OOO1MiB"
		size3="5000MiB"
		size4="15001MiB"
        echo "P1 (ROOT) : $size1"
        echo "P2 (STATE): $size3"
        echo "Neue Einteilung übernehmen <Enter>"
        read n 		
    fi
    
    # Root-Partition erstellen (EXT4) 
    echo -e "${blue} Erstelle ROOT-Partition - ${size1} ${reset}"
    parted --script "$FULL_DEV" mkpart primary ext4 1MiB $size1 || { 
        echo -e "${red} FEHLER: Root-Partition konnte nicht erstellt werden.${reset}"
        read n 
        menu
        return 1
    }
    
    # STATE-Partition erstellen (EXT4) 
    echo -e "${blue} Erstelle STATE-Partition - $size2 {reset}"
    parted --script "$FULL_DEV" mkpart primary ext4 $size1 $size4 || { 
        echo -e "${red} FEHLER: STATE-Partition konnte nicht erstellt werden.${reset}"
        read n 
        menu
        return 1
    }
   
    # Formatieren und Label setzen (ROOT)
    echo -e "${blue} Formatiere Partition 1 als EXT4 mit LABEL=ROOT${reset}"
    mkfs.ext4 -L "ROOT" "${FULL_DEV}1" || {
        echo -e "${red} FEHLER: Formatierung fehlgeschlagen.${reset}"
        read n
        menu
        return 1
    }
    
    # Formatieren und Label setzen (STATE)
    echo -e "${blue} Formatiere Partition 2 als EXT4 mit LABEL=STATE${reset}"
    mkfs.ext4 -L "STATE" "${FULL_DEV}2" || {
        echo -e "${red} FEHLER: Formatierung fehlgeschlagen.${reset}"
        read n
        menu
        return 1
    }
 
    mount "${FULL_DEV}1" /mnt 
    test line_212
    
    echo -e "${purple}- Partitionierung und Formatierung erfolgreich abgeschlossen.${reset}"
    echo -e "${red}  Starte Kopierprozess... Bitte warten Sie, es kann dauern!${reset}"
   
    rsync -aAXv --delete \
    --exclude=/cdrom \
    --exclude=/cow \
    --exclude=/dev/* \
    --exclude=/proc/* \
    --exclude=/sys/* \
    --exclude=/tmp/* \
    --exclude=/var/cache/* \
    --exclude=/var/log/* \
    --exclude=/var/tmp/* \
    --exclude=/mnt/* \
    --exclude=/media/* \
    --exclude=/opt/openoffice/* \
    --exclude=/rofs \
    --exclude=/run/live/* \
    --exclude=/usr/lib/live/mount/* \
    --exclude=/home/remastersys \
    --exclude=/home/*.sblive \
    --exclude=/home/STATE/* \
    --exclude=/home/*.iso \
    --exclude=/home/*.img \
    --exclude=/home/*/.cache \
    --exclude=/home/*/Bilder/* \
    --exclude=/home/*/Downloads/* \
    --exclude=/home/*/Dokumente/* \
    --exclude=/home/*/Projekte/* \
    --exclude=/home/*/Schreibtisch/* \
    / /mnt
    
    test line_263
    sync
    
    # Mountpoints vorbereiten (Bind-Mounts)
    mount -o bind /dev /mnt/dev
    mount -o bind /dev/shm /mnt/dev/shm
    mount -t devpts pts /mnt/dev/pts
    mount -t proc /proc /mnt/proc
    mount -t sysfs /sys /mnt/sys
    mount -o bind /run /mnt/run
    
    # Nötige Systemdateien kopieren
    cp -L /etc/resolv.conf /mnt/etc/
    cp /proc/mounts /mnt/etc/mtab 2>/dev/null
    
    ########################################
    #  AUTOMATISIERTE CHROOT INSTALLATION ---
    # Erstellen des SETUP-Skripts im Zielsystem (/mnt/tmp/setup.sh)

    cat > /mnt/tmp/setup.sh <<'EOF'
#!/bin/bash
echo "--- Starte GRUB Konfiguration ---"
/usr/bin/chsh root -s /bin/bash       # Shell auf /bin/bash setzen
echo ""
lsblk
echo "===================================================" 
echo "GRUB-device ist das Gerät mit / ( zB sda ) OHNE Ziffer"
read -p "/dev/" response
bootdevice=/dev/$response
echo "==> GRUB wird auf ${bootdevice} installiert. Bitte warten..."
/usr/sbin/grub-mkconfig -o /boot/grub/grub.cfg 2>/dev/null
/usr/sbin/grub-install --target=i386-pc --recheck ${bootdevice} --removable --force
########################################################################
# experimentelle grub.cfg :
cat > "/boot/grub/grub.cfg" <<EOT
if loadfont /boot/grub/font.pf2
then
  set gfxmode=auto
  insmod efi_gop
  insmod efi_uga
  insmod gfxterm
  terminal_output gfxterm
fi
set timeout=1

menuentry "LiveOS fullinstall" {
  insmod ext2
  search --no-floppy --set=root --label ROOT
  echo 'vmlinuz'
  linux /vmlinuz root=LABEL=ROOT ro quiet loglevel=0 nosplash fsck.mode=skip noeject
  echo 'initrd'
  initrd /initrd.img
  echo 'please wait...'
}
EOT
########################################################################

echo "==> Fertig mit GRUB und FSTAB."

exit 0 # Beendet die Chroot-Sitzung
EOF
    # Ausführbar machen und im CHROOT starten
    chmod +x /mnt/tmp/setup.sh 
    sync
    echo -e "${purple} << CHROOT gestartet für GRUB-Installation >> ${reset}"
    chroot /mnt /tmp/setup.sh  
	sync
    # Aufräumen (nachdem der Benutzer die chroot-Sitzung beendet hat)
    umount /mnt -f -l     
    test line_333

    # Signalisiert Erfolg
    echo " "
    echo -e "${purple}✅ LIVE-Installation erfolgreich abgeschlossen. "
    echo -e " Ihr System ist bereit zum Testen! <ENTER> ${reset}"
    read n
    menu 
}

########################################################################
# HAUPTMENU  
########################################################################

menu() {
    clear 
    echo ""
    echo -e "${blue}============================================${reset}"
    echo ""
    echo -e "####### ${purple}      OS - Installation   $reset   ####### "
    echo ""
    echo -e "${blue}============================================${reset}"
    echo ""
    echo "   1) LIVE-Version 'sfs' "
    echo ""
    echo "   2) VOLL-Version ' / ' "
    echo " "
    echo "   q) Quit ..."
    echo -e "${blue}____________________________________________${reset}"
    echo " "

    read -p "    Wahl : " n # Wahl einlesen 

    case $n in # Funktionen aufrufen 
        1) install1;;
        2) install2;;
        q) exit;; #  cursor_on & exit
        *) echo "Ungültige Eingabe." && sleep 1 && menu;;
    esac
}

#######################################################################
# HAUPTAUFRUF DES SKRIPTS
#######################################################################

menu  # Aufruf MENU
