#!/bin/bash

###################################################################
#  REMASTERSYS
#  Under the GNU GPL2 License   
#  Copyright (C) 2021-2023 Daniel "Nerun" Rodrigues 
#  Copyright (C) 2007-2013 Tony "Fragadelic" Brijeski   
#  Full copyright notice: /usr/share/doc/remastersys/copyright  
###################################################################

if [ '$1' != "allow" ]; then  
    echo "Darf nicht direkt aufgerufen werden."
    read n
    exit 1
fi

# SYSTEM LOCALIZATION
# Target to file:
# /usr/share/locale/(language code)/LC_MESSAGES/remastersys.mo

TEXTDOMAIN=remastersys

WORKDIR="/home/remastersys"

LIVEUSER="$(echo $LIVEUSER | awk '{print tolower ($0)}')"

LIVEUSER_FULL_NAME="$LIVEUSER session user"

SQUASHFSOPTS="-no-recovery -always-use-fragments -b 1M -comp zstd"

remastersyslogo(){
    #clear
    vers=$"ad-PM-2025"
echo -e "  ___ ___ __  __   _   ___ _____ ___ ___  _____   _____ \n | _ \ __|  \/  | /_\ / __|_   _| __| _ \/ __\ \ / / __| \n |   / _|| |\/| |/ _ \\\\\__ \ | | | _||   /\__ \\\\\ V /\__ \\ \n |_|_\___|_|  |_/_/ \_\___/ |_| |___|_|_\|___/ |_| |___/ \n  $vers $VERSION $fEND";
}

options=$" - Creating the CD File System only."
remastersyslogo
#echo -e " >> BACKUP MODE SELECTED <<"
 
# Function log_msg extracted from PinguyBuilder v5.2 with a few changes.
# https://sourceforge.net/projects/pinguy-os/files/ISO_Builder/
# Added log_msg to reduce size. Code provided by Ivailo (a.k.a. SmiL3y)
log_msg() {
    echo -e "$1" >> $WORKDIR/remastersys.log
}

# STEP 1 - Create the CD tree in $WORKDIR/ISOTMP

echo $"Checking if the $WORKDIR folder has already been created."

if [ -d "$WORKDIR" ]; then
    rm -rf $WORKDIR/dummysys/var/*
    rm -rf $WORKDIR/dummysys/etc/*
else
    mkdir -p $WORKDIR/ISOTMP/live
    mkdir -p $WORKDIR/ISOTMP/install
    mkdir -p $WORKDIR/ISOTMP/preseed
    mkdir -p $WORKDIR/dummysys/dev
    mkdir -p $WORKDIR/dummysys/etc/live
    mkdir -p $WORKDIR/dummysys/proc
    mkdir -p $WORKDIR/dummysys/tmp
    mkdir -p $WORKDIR/dummysys/sys
    mkdir -p $WORKDIR/dummysys/mnt
    mkdir -p $WORKDIR/dummysys/media
    mkdir -p $WORKDIR/dummysys/run
    mkdir -p $WORKDIR/dummysys/var
    chmod ug+rwx,o+rwt $WORKDIR/dummysys/tmp
fi

echo -e $"\nCopying /var and /etc to temporary area and deleting extra files."

if [ "$EXCLUDES" != "" ]; then
    for addvar in $EXCLUDES ; do
        VAREXCLUDES="$VAREXCLUDES --exclude='$addvar' "
    done
fi

# if KDE, copy the adept_notifier_auto.desktop to /etc/remastersys so
# the installer can put it back as live-initramfs removes it altogether
if [ -f /usr/share/autostart/adept_notifier_auto.desktop ]; then
    cp /usr/share/autostart/adept_notifier_auto.desktop /etc/remastersys/
fi

# copy trackerd stuff as live-initramfs disables it
if [ -f /etc/xdg/autostart/tracker-applet.desktop ]; then
    cp /etc/xdg/autostart/tracker-applet.desktop /etc/remastersys
fi

if [ -f /etc/xdg/autostart/trackerd.desktop ]; then
    cp /etc/xdg/autostart/trackerd.desktop.xdg /etc/remastersys
fi

if [ -f /usr/share/autostart/trackerd.desktop ]; then
    cp /usr/share/autostart/trackerd.desktop.share /etc/remastersys
fi

#cleanup leftover live script if it exists
if [ -f /etc/profile.d/zz-live.sh ]; then
    rm -f /etc/profile.d/zz-live.sh
fi

rsync --exclude='*.log.*' --exclude='*.pid' --exclude='*.bak' --exclude='*.[0-9].gz' --exclude='*.deb' $VAREXCLUDES-a /var/. $WORKDIR/dummysys/var/.
rsync $VAREXCLUDES-a /etc/. $WORKDIR/dummysys/etc/.

rm -f $WORKDIR/dummysys/etc/mtab
rm -f $WORKDIR/dummysys/etc/fstab
rm -f $WORKDIR/dummysys/etc/udev/rules.d/70-persistent*
ls $WORKDIR/dummysys/var/lib/apt/lists | grep -v ".gpg" | grep -v "lock" | grep -v "partial" | grep -v "auxfiles" | xargs -i rm $WORKDIR/dummysys/var/lib/apt/lists/{} ;

# bootloader localization
local EnterOrTab=$"Press ENTER to choose or TAB to edit a menu entry"
local LiveCD=$"Live CD"
local LiveCDFailSafe=$"(fail safe)"
local ChainBoot=$"Boot from hard disk"
local MemTest=$"Memory Test (Memtest86)"
local MemTestPlus=$"Memory Test (Memtest86+)"

# BOOT Type selected is GRUB
  
cp /etc/remastersys/isolinux/memtest86.bin $WORKDIR/ISOTMP/
cp /etc/remastersys/isolinux/memtest86+x64.bin $WORKDIR/ISOTMP/
mkdir -p $WORKDIR/ISOTMP/boot/grub
mkdir -p $WORKDIR/ISOTMP/usr/share/grub
cp -a /boot/grub/* $WORKDIR/ISOTMP/boot/grub/
cp -a /usr/share/grub/* $WORKDIR/ISOTMP/usr/share/grub/
cp /etc/remastersys/grub/grub.cfg $WORKDIR/ISOTMP/boot/grub/grub.cfg
cp /etc/remastersys/splash.png $WORKDIR/ISOTMP/boot/grub/grub.png

grubcfg="$WORKDIR/ISOTMP/boot/grub/grub.cfg"
langshort=$(locale | grep -w 'LANG' | cut -d= -f2 | cut -d. -f1) # pt_BR not pt_BR.UTF-8

# grub.cfg translation
sed -i -e 's/__LANGUAGE__/'"$langshort"'/g' "$grubcfg"
sed -i -e 's/__LIVECDLABEL__/'"$LIVECDLABEL"'/g' "$grubcfg"
sed -i -e 's/__LIVECDFAILSAFE__/'"$LIVECDLABEL $LiveCDFailSafe"'/g' "$grubcfg"
sed -i -e 's/__CHAINBOOT__/'"$ChainBoot"'/g' "$grubcfg"
sed -i -e 's/__MEMTEST__/'"$MemTest"'/g' "$grubcfg"
sed -i -e 's/__MEMTESTPLUS__/'"$MemTestPlus"'/g' "$grubcfg"

if [ ! -d /etc/plymouth ]; then
    sed -i -e 's/splash//g' $WORKDIR/ISOTMP/boot/grub/grub.cfg
fi

sleep 1

# STEP 2 - Prepare live.conf #######################################

LIVEUSER="$(grep '^[^:]*:[^:]*:1000:' /etc/passwd | awk -F ":" '{ print $1 }')"
LIVEUSER_FULL_NAME="$(getent passwd $LIVEUSER | cut -d ':' -f 5 | cut -d ',' -f 1)"

if [ ! -d /etc/live ]; then
    mkdir -p /etc/live
fi

echo "export LIVE_USERNAME=\"$LIVEUSER\"" > /etc/live/config.conf
echo "export LIVE_USER_FULLNAME=\"$LIVEUSER_FULL_NAME\"" >> /etc/live/config.conf
echo "export LIVE_HOSTNAME=\"$LIVEUSER\"" >> /etc/live/config.conf
echo "export LIVE_USER_DEFAULT_GROUPS=\"audio,cdrom,dialout,floppy,video,plugdev,netdev,powerdev,adm,sudo\"" >> /etc/live/config.conf
lang=$(locale | grep -w 'LANG' | cut -d= -f2) # like "pt_BR.UTF-8"
echo "export LIVE_LOCALES=\"$lang\"" >> /etc/live/config.conf
timezone=$(cat /etc/timezone) # like "America/Sao_Paulo"
echo "export LIVE_TIMEZONE=\"$timezone\"" >> /etc/live/config.conf

echo "export LIVE_NOCONFIGS=\"user-setup,sudo,locales,locales-all,tzdata,gdm,gdm3,kdm,lightdm,lxdm,nodm,slim,xinit,keyboard-configuration,gnome-panel-data,gnome-power-manager,gnome-screensaver,kde-services,debian-installer-launcher,login\"" >> /etc/live/config.conf

cp /etc/live/config.conf $WORKDIR/dummysys/etc/live/

sleep 1

echo -e $"\nSetting up Live CD options (initramfs.conf)"

# /etc/initramfs.conf für LIVE erzeugen 
# zuerst alte sichern:
mv /etc/initramfs-tools/initramfs.conf  /etc/initramfs-tools/initramfs.bak 
# dann neue erstellen:
cat > "/etc/initramfs-tools/initramfs.conf" <<EOF
MODULES=most
BUSYBOX=auto
KEYMAP=n
COMPRESS=zstd
DEVICE=
NFSROOT=auto
RUNSIZE=10%
FSTYPE=auto
EOF
# make a new initial ramdisk including the live scripts
update-initramfs -t -c -k $(uname -r)
    
# initramfs wiederherstellen
mv /etc/initramfs-tools/initramfs.bak  /etc/initramfs-tools/initramfs.conf

echo -e $"\nCopying your kernel and initrd to the Live CD."
cp /boot/vmlinuz-$(uname -r) $WORKDIR/ISOTMP/live/vmlinuz
cp /boot/initrd.img-$(uname -r) $WORKDIR/ISOTMP/live/initrd.img

# STEP 3 - Make filesystem.squashfs

if [ -f $WORKDIR/remastersys.log ]; then
    rm -f $WORKDIR/remastersys.log
    touch $WORKDIR/remastersys.log
fi

if [ -f $WORKDIR/ISOTMP/live/filesystem.squashfs ]; then
    rm -f $WORKDIR/ISOTMP/live/filesystem.squashfs
fi

echo -e $"\nCreating filesystem.squashfs. It will take a while, so be patient...\n"

REALFOLDERS=""

for d in $(ls -d $WORKDIR/dummysys/*); do
    REALFOLDERS="$REALFOLDERS $d"
done
   
for d in $(ls / | grep -v etc | grep -v run | grep -v tmp | grep -v sys | grep -v var \
| grep -v dev | grep -v media | grep -v mnt | grep -v lost+found | grep -v proc); do
    REALFOLDERS="$REALFOLDERS /$d"
done

time mksquashfs $REALFOLDERS $WORKDIR/ISOTMP/live/filesystem.squashfs -no-duplicates $SQUASHFSOPTS -e \
root/.thumbnails \
root/.cache \
root/.bash_history \
root/.lesshst \
root/.nano_history \
boot/grub \
$WORKDIR $EXCLUDES 2>>$WORKDIR/remastersys.log

sleep 1

#add some stuff to the log in case of problems so I can troubleshoot it easier
stripe="------------------------------------------------------"
log_msg "$stripe\nMount information:"
mount >> $WORKDIR/remastersys.log
log_msg "$stripe\ndf information:"
df -h 2>&1 | grep -v "df:" >> $WORKDIR/remastersys.log
log_msg "$stripe\n/etc/remastersys.conf info:"
cat /etc/remastersys.conf >> $WORKDIR/remastersys.log
log_msg "$stripe\n/etc/live/config.conf info:"
cat /etc/live/config.conf >> $WORKDIR/remastersys.log
log_msg "$stripe\n/etc/passwd info:"
cat $WORKDIR/dummysys/etc/passwd >> $WORKDIR/remastersys.log
log_msg "$stripe\n/etc/group info:"
cat $WORKDIR/dummysys/etc/group >> $WORKDIR/remastersys.log
log_msg "$stripe\n/etc/skel info:"
find /etc/skel/ >> $WORKDIR/remastersys.log
log_msg "$stripe\n/etc/X11/default-display-manager info:"
cat /etc/X11/default-display-manager >> $WORKDIR/remastersys.log
log_msg "$stripe\nVersion info: $VERSION"
log_msg "$stripe\nCommand-line options: $@\n$stripe"

sleep 1

return 0
