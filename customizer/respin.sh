#!/bin/bash

# ===================
# TAI'S NOTES VERSION
# ===================
#
# This version is a dev version. Don't use in prod!
# =================================================
#
# FIXME - an issue with the proceudre in 14.04 results in loss of DNS
# at some point, need to add a line to link /etc/resolv.conf -> /run/resolvconf/resolv.conf
#
# FIXME - an issue with the default user creation exists - the default user is not created
# for the LiveCD preventing any useful demonstration of the capabilities, and installing from Live



# ==================

# respin script to make an installable livecd/dvd from an (XK)Ubuntu installed 
# and customized system
#
#
#  Created by Tony "Fragadelic" Brijeski
#  Copyright 2014 Adrenaline <adrenaline@azloco.com>, Sergio Mejia, Marcia "aicra" Wilbur <aicra@respin.org>
#  Copyright 2007-2012 Tony "Fragadelic" Brijeski <tb6517@yahoo.com>
#
#  Originally Created February 12th, 2007
#  Updated September 21, 20014
#
#
#  This version is only for Ubuntu's and variants of Lucid 10.04 and up
#
#
# Code cleanup with suggestions and code from Ivailo (a.k.a. SmiL3y)
#
# THESE DIRECTORIES MUST BE CHANGED 

# EDITS by Tai Kedzierski marked @TK
# NOTES by Tai Kedzierski marked TAIK

. /etc/respin/respin.version

# @TK checking to make sure script is running with root privileges
[[ $UID != 0 ]] && { echo "Need to be root or run with sudo. Exiting."; exit 1; }

#create respin-firstboot script if it doesn't exist and populate with at least removal of the ubiquity*.desktop file from users Desktop
# and fix for recovery mode

# @TK TODO - cleaned some up - but no idea WHAT this is doing....
if [[ -z $(grep "REM302" /etc/init.d/respin-firstboot) ]]; then
    cat > /etc/init.d/respin-firstboot <<FOO
#! /bin/sh
### BEGIN INIT INFO
# Provides:          respin-firstboot
# Required-Start:    \$remote_fs \$syslog \$all
# Required-Stop:
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Run firstboot items for respin after a remastered system has been installed
### END INIT INFO

PATH=/sbin:/usr/sbin:/bin:/usr/bin:/usr/local/bin:/usr/local/sbin

. /lib/init/vars.sh
. /lib/lsb/init-functions

do_start() {
	# First task - reactivate networking
	ln -s /run/resolvconf/resolv.conf /etc/resolv.conf
	#REM302
	if [[ "\$(cat /proc/cmdline | grep casper)" = "" ]]; then
		[[ "\$VERBOSE" != no ]] && log_begin_msg "Running respin-firstboot"
		sleep 60 && update-rc.d -f respin-firstboot remove) &
		#sed -i -e 's/root:x:/root:!:/g' /etc/shadow
		rm -rf /home/*/Desktop/ubiquity*.desktop
		#Place your custom commands below this line

		#Place your custom commands above this line
		ES=\$?
		[[ "\$VERBOSE" != no ]] && log_end_msg \$ES
		return \$ES
	else # Live CD
		passwd << EOPASS
partimus
partimus
EOPASS
		useradd -m partimus
		echo -e "partimus\\tALL=(ALL:ALL) ALL" >> /etc/sudoers
	fi
}

case "\$1" in
    start)
        do_start
        ;;
    restart|reload|force-reload)
        echo "Error: argument '\$1' not supported" >&2
        exit 3
        ;;
    stop)
        ;;
    *)
        echo "Usage: \$0 start|stop" >&2
        exit 3
        ;;
esac

FOO

fi


# load the respin.conf file 
RESPCONF=/etc/respin.conf
. $RESPCONF # @TK

# if the respin.conf file is incorrect or missing, make sure to set defaults

# @TK ---------------- CONFIG start
#If somebody removed the username from the configuration file
[[ -z "$LIVEUSER" ]] &&  LIVEUSER="custom"


#make sure live user is all lowercase
# @TK TESTTHIS - also make sure the live user has only valid chars...!
LIVEUSER="$(echo $LIVEUSER | awk '{print tolower ($0)}' | sed 's/[^a-z0-9_]+/_/g')"

if [[ -z "$WORKDIR" ]]; then
    BASEWORKDIR="/home/respin"
    WORKDIR="/home/respin/respin"
else
    BASEWORKDIR="$WORKDIR"
    WORKDIR="$WORKDIR/respin"
fi

if [[ ! -d "$WORKDIR" ]]; then
    mkdir -p "$WORKDIR"
fi

if [[ -f "$WORKDIR/respin.log" ]]; then
    rm -f "$WORKDIR/respin.log" &> /dev/null
fi

touch "$WORKDIR/respin.log"

log_msg() {
    echo "$(date +'%F %T') : $1" | tee -a "$WORKDIR/respin.log" # @TK - only one place
}

# ===================================================
log_msg "\n\n!!! Using dev version\n\n"
cat <<EOM
=======================================

  -- DEV VERSION --

This is a development version!

Please be aware that there may be a good many
bugs left from making changes from the stable
release.

Any issues with the resulting media
or the effect of the script on your system

==>> is your sole responsibility! <<==

If it is not your intention to be testing
development versions of the software, please
download a stable release.

See http://remastersys.org for more information

=======================================
EOM

read -p "Proceed all the same? y/N>" CONTINUERES
[[ $CONTINUERES != 'y' ]] && [[ $CONTINUERES != 'Y' ]] && exit 1
# ===================================================


[[ -z "$LIVECDLABEL" ]] && LIVECDLABEL="Custom Live CD"
[[ ${#LIVECDLABEL} -gt 32 ]] && { echo "CD Label too long - greater than 32 chars: '$LIVECDLABEL'"; exit 1; } # @TK

CDBOOTTYPE="ISOLINUX"

[[ -z "$LIVECDURL" ]] && LIVECDURL="http://remastersys.org/"

if [[ "$SQUASHFSOPTS" = "" ]]; then
    SQUASHFSOPTS="-no-recovery -always-use-fragments -b 1M -no-duplicates"
fi

if [[ "$BACKUPSHOWINSTALL" = "0" ]] || [[ "$BACKUPSHOWINSTALL" = "1" ]]; then
    echo
else
    BACKUPSHOWINSTALL="1"
fi

if [[ "$2" = "cdfs" ]]; then
    log_msg "Creating the cd filesystem only"
elif [[ "$2" = "iso" ]]; then
    log_msg "Creating the iso file only"
elif [[ "$2" = "" ]]; then
    echo " "
else
    CUSTOMISO="$2"
fi

if [[ "$3" != "" ]]; then
    CUSTOMISO="$3"
fi

if [[ "$CUSTOMISO" = "" ]]; then
    CUSTOMISO="custom$1.iso"
fi

case $1  in

    backup)
        log_msg "System Backup Mode Selected"
        ;;

    clean)
        echo "Removing the build directory now..."
        rm -rf "$WORKDIR"
        echo "Done...Exiting"
        exit 0
        ;;

    dist)
        log_msg "Distribution Mode Selected"
        ;;


    *)
       cat <<EOHELP
Usage of respin $REMASTERSYSVERSION is as follows:
 
   sudo respin backup|clean|dist [cdfs|iso] [filename.iso]
 
Configuration file is located at $RESPCONF
 
Examples:
 
   sudo respin backup   (to make a livecd/dvd backup of your system)
 
   sudo respin backup custom.iso
                             (to make a livecd/dvd backup and call the iso custom.iso)"  
 
   sudo respin clean    (to clean up temporary files of respin)
 
   sudo respin dist     (to make a distributable livecd/dvd of your system)
 
   sudo respin dist cdfs
                             (to make a distributable livecd/dvd filesystem only)
 
   sudo respin dist iso custom.iso
                             (to make a distributable iso named custom.iso but only
                              if the cdfs is already present)
 
   cdfs and iso options should only be used if you wish to modify something on the
   cd before the iso is created.  An example of this would be to modify the isolinux
   portion of the livecd/dvd
EOHELP
        exit 1
        ;;
esac

cdfs (){ 

log_msg "Enabling respin-firstboot"
chmod 755 /etc/init.d/respin-firstboot
update-rc.d respin-firstboot defaults

log_msg "Checking filesystem type of the Working Folder"
DIRTYPE=$(df -T -P "$WORKDIR" | grep "^\/dev" | awk '{print $2}')
log_msg "$WORKDIR is on a $DIRTYPE filesystem"

    #removing popularity-contest as it causes a problem when installing with ubiquity
    log_msg "Making sure popularity contest is not installed"
    apt-get -y -q remove popularity-contest &> /dev/null

    # check whether system is gnome or kde based to load the correct ubiquity frontend

    if [[ $(ps axf | grep startkde | grep -v grep) != "" ]] || [[ $(ps axf | grep kwin | grep -v grep) != "" ]]; then
        log_msg "Installing the Ubiquity KDE frontend"
        apt-get -y -q install ubiquity-frontend-kde &> /dev/null
        apt-get -y -q remove ubiquity-frontend-gtk &> /dev/null
    else
        log_msg "Installing the Ubiquity GTK frontend"
        apt-get -y -q install ubiquity-frontend-gtk &> /dev/null
        apt-get -y -q remove ubiquity-frontend-kde &> /dev/null
    fi

    # Check if they are using lightdm and if it is setup properly for the live default session
    [[ -n $(grep lightdm /etc/X11/default-display-manager) ]] &&
    [[ ! -f /etc/lightdm/lightdm.conf ]] &&
    [[ ! -f /usr/share/xsessions/ubuntu.desktop ]] && {
    	log_msg "Lightdm not setup properly. You must set your default desktop with lightdm prior to remastering"
    	exit 1
    }

    # prevent the installer from changing the apt sources.list

    if [[ ! -f "/usr/share/ubiquity/apt-setup.saved" ]]; then
        cp /usr/share/ubiquity/apt-setup /usr/share/ubiquity/apt-setup.saved
    fi

    sleep 1

    # Step 3 - Create the CD tree in "$WORKDIR"/ISOTMP
    log_msg "Checking if the $WORKDIR folder has been created"
    if [[ -d "$WORKDIR/dummysys" ]]; then 
        rm -rf "$WORKDIR"/dummysys/var/*
        rm -rf "$WORKDIR"/dummysys/etc/*
        rm -rf "$WORKDIR"/dummysys/run/*
        rm -rf "$WORKDIR"/ISOTMP/{isolinux,grub,.disk}
    else
        log_msg "Creating "$WORKDIR" folder tree"
        mkdir -p "$WORKDIR"/ISOTMP/{casper,preseed}
        mkdir -p "$WORKDIR"/dummysys/{dev,etc,proc,tmp,sys,mnt,media/cdrom,var}
        if [[ -d /run ]]; then
            mkdir -p "$WORKDIR"/dummysys/run
        fi
        chmod ug+rwx,o+rwt "$WORKDIR"/dummysys/tmp

    fi

    log_msg "Creating $WORKDIR/ISOTMP folder tree"
    mkdir -p "$WORKDIR"/ISOTMP/{isolinux,install,.disk}

    log_msg "Copying /var and /etc to temp area and excluding extra files  ... this will take a while so be patient"

    if [[ "$EXCLUDES" != "" ]]; then
        for addvar in $EXCLUDES ; do
            VAREXCLUDES="$VAREXCLUDES --exclude='$addvar' "
        done
    fi

    rsync --exclude='*.log.*' --exclude='*.pid' --exclude='*.bak' --exclude='*.[0-9].gz' --exclude='*.deb' --exclude='kdecache*' $VAREXCLUDES -a /var/. "$WORKDIR"/dummysys/var/.
    rsync $VAREXCLUDES -a /etc/. "$WORKDIR"/dummysys/etc/.

    log_msg "Cleaning up files not needed for the live in "$WORKDIR"/dummysys"
    rm -f "$WORKDIR"/dummysys/etc/X11/xorg.conf*
    rm -f "$WORKDIR"/dummysys/etc/{resolv.conf,hosts,hostname,timezone,mtab*,fstab}
    rm -f "$WORKDIR"/dummysys/etc/udev/rules.d/70-persistent*
    rm -f "$WORKDIR"/dummysys/etc/cups/ssl/{server.crt,server.key}
    rm -f "$WORKDIR"/dummysys/etc/ssh/{ssh_host_rsa_key,ssh_host_rsa_key.pub}
    rm -f "$WORKDIR"/dummysys/etc/ssh/{ssh_host_dsa_key,ssh_host_dsa_key.pub}
    rm -f "$WORKDIR"/dummysys/var/lib/dbus/machine-id
    find "$WORKDIR"/dummysys/var/log/ "$WORKDIR"/dummysys/var/lock/ "$WORKDIR"/dummysys/var/backups/ "$WORKDIR"/dummysys/var/tmp/ "$WORKDIR"/dummysys/var/crash/ "$WORKDIR"/dummysys/var/lib/ubiquity/ -type f -exec rm -f {} \;

    if [[ "$1" = "dist" ]]; then

        rm -f "$WORKDIR"/dummysys/etc/{group,passwd,shadow,shadow-,gshadow,gshadow-}
        rm -f "$WORKDIR"/dummysys/etc/wicd/{wired-settings.conf,wireless-settings.conf}
        rm -rf "$WORKDIR"/dummysys/etc/NetworkManager/system-connections/*
        rm -f "$WORKDIR"/dummysys/etc/printcap
        rm -f "$WORKDIR"/dummysys/etc/cups/printers.conf
        touch "$WORKDIR"/dummysys/etc/printcap
        touch "$WORKDIR"/dummysys/etc/cups/printers.conf
        rm -rf "$WORKDIR"/dummysys/var/cache/gdm/*
        rm -rf "$WORKDIR"/dummysys/var/lib/sudo/*
        rm -rf "$WORKDIR"/dummysys/var/lib/AccountsService/users/*
	rm -rf "$WORKDIR"/dummysys/var/lib/kdm/*
        rm -rf "$WORKDIR"/dummysys/var/run/console/*
        rm -f "$WORKDIR"/dummysys/etc/gdm/gdm.conf-custom
        rm -f "$WORKDIR"/dummysys/etc/gdm/custom.conf
	if [[ ! -d /run ]]; then
		find "$WORKDIR"/dummysys/var/run/ "$WORKDIR"/dummysys/var/mail/ "$WORKDIR"/dummysys/var/spool/ -type f -exec rm -f {} \;
	else
		find "$WORKDIR"/dummysys/var/mail/ "$WORKDIR"/dummysys/var/spool/ -type f -exec rm -f {} \;
		unlink "$WORKDIR"/dummysys/var/run
		cd "$WORKDIR"/dummysys/var
		ln -sf ../run run
	fi
        for i in dpkg.log lastlog mail.log syslog auth.log daemon.log faillog lpr.log mail.warn user.log boot debug mail.err messages wtmp bootstrap.log dmesg kern.log mail.info
        do
            touch "$WORKDIR"/dummysys/var/log/${i}
        done

        log_msg "Cleaning up passwd, group, shadow and gshadow files for the live system"
        grep '^[^:]*:[^:]*:[0-9]:' 			/etc/passwd >  "$WORKDIR"/dummysys/etc/passwd
        grep '^[^:]*:[^:]*:[0-9][0-9]:'			/etc/passwd >> "$WORKDIR"/dummysys/etc/passwd
        grep '^[^:]*:[^:]*:[0-9][0-9][0-9]:'		/etc/passwd >> "$WORKDIR"/dummysys/etc/passwd
        grep '^[^:]*:[^:]*:[3-9][0-9][0-9][0-9][0-9]:'	/etc/passwd >> "$WORKDIR"/dummysys/etc/passwd

        grep '^[^:]*:[^:]*:[0-9]:'			/etc/group >  "$WORKDIR"/dummysys/etc/group
        grep '^[^:]*:[^:]*:[0-9][0-9]:'			/etc/group >> "$WORKDIR"/dummysys/etc/group
        grep '^[^:]*:[^:]*:[0-9][0-9][0-9]:'		/etc/group >> "$WORKDIR"/dummysys/etc/group
        grep '^[^:]*:[^:]*:[3-9][0-9][0-9][0-9][0-9]:'	/etc/group >> "$WORKDIR"/dummysys/etc/group

        grep '^[^:]*:[^:]*:[5-9][0-9][0-9]:'		/etc/passwd | awk -F ":" '{print $1}'> "$WORKDIR"/tmpusers1
        grep '^[^:]*:[^:]*:[1-9][0-9][0-9][0-9]:'	/etc/passwd | awk -F ":" '{print $1}'> "$WORKDIR"/tmpusers2
        grep '^[^:]*:[^:]*:[1-2][0-9][0-9][0-9][0-9]:'	/etc/passwd | awk -F ":" '{print $1}'> "$WORKDIR"/tmpusers3

        cat "$WORKDIR"/tmpusers1 "$WORKDIR"/tmpusers2 "$WORKDIR"/tmpusers3 > "$WORKDIR"/tmpusers
        rm -f "$WORKDIR"/tmpusers[0-9] &> /dev/null

        #cp /etc/shadow "$WORKDIR"/dummysys/etc/shadow
        #cp /etc/gshadow "$WORKDIR"/dummysys/etc/gshadow

        cat "$WORKDIR"/tmpusers | while read LINE ;do
		# TAIK - hold on .... what...??
		# echo single line and pipe to xargs....??
		# to new files every time?
		# separate calls for sepaprate patterns??

            echo "$LINE" | xargs -i sed -e 's/,{}$//g'  "$WORKDIR"/dummysys/etc/group > 	"$WORKDIR"/dummysys/etc/group.new1
            echo "$LINE" | xargs -i sed -e 's/,{},/,/g' "$WORKDIR"/dummysys/etc/group.new1 > 	"$WORKDIR"/dummysys/etc/group.new2
            echo "$LINE" | xargs -i sed -e 's/:{}$/:/g' "$WORKDIR"/dummysys/etc/group.new2 > 	"$WORKDIR"/dummysys/etc/group.new3
            echo "$LINE" | xargs -i sed -e 's/:{},/:/g' "$WORKDIR"/dummysys/etc/group.new3 > 	"$WORKDIR"/dummysys/etc/group

            # /etc/shadow and /etc/gshadow needed for rescue mode boot root access - removed due to user creation issues for live boot

           # echo $LINE | xargs -i sed -e '/^{}:/d' "$WORKDIR"/dummysys/etc/shadow > "$WORKDIR"/dummysys/etc/shadow.new
            #sed -i -e 's/root:x:/root:!:/g' "$WORKDIR"/dummysys/etc/shadow.new
            #mv "$WORKDIR"/dummysys/etc/shadow.new "$WORKDIR"/dummysys/etc/shadow

            #echo $LINE | xargs -i sed -e '/^{}:/d' "$WORKDIR"/dummysys/etc/gshadow > "$WORKDIR"/dummysys/etc/gshadow.new1
            #echo $LINE | xargs -i sed -e 's/,{}$//g' "$WORKDIR"/dummysys/etc/gshadow.new1 > "$WORKDIR"/dummysys/etc/gshadow.new2
            #echo $LINE | xargs -i sed -e 's/,{},/,/g' "$WORKDIR"/dummysys/etc/gshadow.new2 > "$WORKDIR"/dummysys/etc/gshadow.new3
            #echo $LINE | xargs -i sed -e 's/:{}$/:/g' "$WORKDIR"/dummysys/etc/gshadow.new3 > "$WORKDIR"/dummysys/etc/gshadow.new4
            #echo $LINE | xargs -i sed -e 's/:{},/:/g' "$WORKDIR"/dummysys/etc/gshadow.new4 > "$WORKDIR"/dummysys/etc/gshadow

            rm -f "$WORKDIR"/dummysys/etc/group.new* &> /dev/null

        done

    fi


    # make sure the adduser and autologin functions of casper as set according to the mode
    log_msg "Making sure adduser and autologin functions of casper are set properly"
    [[ "$1" = "dist" ]] && [[ ! -d "$WORKDIR"/dummysys/home ]] && mkdir "$WORKDIR"/dummysys/home
    [[ "$1" = "dist" ]] && chmod 755 "/usr/share/initramfs-tools/scripts/casper-bottom/*adduser" "/usr/share/initramfs-tools/scripts/casper-bottom/*autologin"
    [[ "$1" = "backup" ]] && [[ -d "$WORKDIR"/dummysys/home ]] && rm -rf "$WORKDIR"/dummysys/home
    [[ "$1" = "backup" ]] && chmod 644 "/usr/share/initramfs-tools/scripts/casper-bottom/*adduser" "/usr/share/initramfs-tools/scripts/casper-bottom/*autologin"

    # copy over some of the necessary stuff for the livecd

    #copy any preseed files
    cp /etc/respin/preseed/* "$WORKDIR"/ISOTMP/preseed/

    #BOOT Type is isolinux
    log_msg "Copying memtest86+ for the live system"
    cp /boot/memtest86+.bin "$WORKDIR"/ISOTMP/install/memtest

    # check and see if they have a custom isolinux already setup. eg. they copied over 
    # the isolinux folder from their original livecd or made a custom one for their distro

    if [[ ! -f /etc/respin/customisolinux/isolinux.cfg ]]; then 
        log_msg "Creating isolinux setup for the live system"
        find /usr -name 'isolinux.bin' -exec cp {} "$WORKDIR"/ISOTMP/isolinux/ \;
        #find fix for vesamenu.32 provided by Krasimir S. Stefanov <lokiisyourmaster@gmail.com>
        VESAMENU=$(find /usr -print0 | grep -FzZ "syslinux/vesamenu.c32")
        cp $VESAMENU "$WORKDIR"/ISOTMP/isolinux/ 
        # setup isolinux for the livecd
        VERSION=$(lsb_release -r | awk '{print $2}' | awk -F "." '{print $1}') # TAIK - not used??
        sed -e 's/__LIVECDLABEL__/'"$LIVECDLABEL"'/g' /etc/respin/isolinux/isolinux.cfg.vesamenu > \
        "$WORKDIR"/ISOTMP/isolinux/isolinux.cfg
        cp /etc/respin/isolinux/splash.png "$WORKDIR"/ISOTMP/isolinux/splash.png
    else
        log_msg "Copying your custom isolinux setup to the live system"
        cp /etc/respin/customisolinux/* "$WORKDIR"/ISOTMP/isolinux/ &> /dev/null

    fi

    log_msg "Checking the ARCH of the system and setting the README.diskdefines file"
    ARCH=$(archdetect | awk -F "/" '{print $1}')

    cat > "$WORKDIR"/ISOTMP/README.diskdefines <<FOO
#define DISKNAME  $LIVECDLABEL
#define TYPE  binary
#define TYPEbinary  1
#define ARCH  $ARCH
#define ARCH$ARCH  1
#define DISKNUM  1
#define DISKNUM1  1
#define TOTALNUM  0
#define TOTALNUM0  1
FOO
    cp "$WORKDIR"/ISOTMP/README.diskdefines "$WORKDIR"/ISOTMP/casper/README.diskdefines

    sleep 1

    # Step 4 - Make the filesystem.manifest and filesystem.manifest-desktop
    log_msg "Creating filesystem.manifest and filesystem.manifest-desktop"
    dpkg-query -W --showformat='${Package} ${Version}\n' > "$WORKDIR"/ISOTMP/casper/filesystem.manifest

    cp "$WORKDIR"/ISOTMP/casper/filesystem.manifest "$WORKDIR"/ISOTMP/casper/filesystem.manifest-desktop
    # Suggested by lkjoel from Ubuntu Forums - Joel Leclerc to remove the frontend so the Install menu item is not on the installed system
    sed -i '/ubiquity-frontend/d' "$WORKDIR"/ISOTMP/casper/filesystem.manifest-desktop

    sleep 1

    # Step 5 - Prepare casper.conf depending on whether this is a backup or dist

    if [[ "$1" = "backup" ]]; then
        BACKUPEXCLUDES=""
        log_msg "Excluding folder from the backup that will cause issues"

        for bi in $(ls /home); do
            if [[ -d /home/$bi/.gvfs ]]; then
                BACKUPEXCLUDES="$BACKUPEXCLUDES /home/$bi/.gvfs "
            fi
            if [[ -d /home/$bi/.cache ]]; then
                BACKUPEXCLUDES="$BACKUPEXCLUDES /home/$bi/.cache "
            fi
            if [[ -d /home/$bi/.thumbnails ]]; then
                BACKUPEXCLUDES="$BACKUPEXCLUDES /home/$bi/.thumbnails "
            fi
            if [[ -d /home/$bi/.local/share/gvfs-metadata ]]; then
                BACKUPEXCLUDES="$BACKUPEXCLUDES /home/$bi/.local/share/gvfs-metadata "
            fi
            if [[ -d /home/$bi/.local/gvfs-metadata ]]; then
                BACKUPEXCLUDES="$BACKUPEXCLUDES /home/$bi/.local/gvfs-metadata "
            fi
            if [[ -d /home/$bi/.local/share/Trash ]]; then
                BACKUPEXCLUDES="$BACKUPEXCLUDES /home/$bi/.local/share/Trash "
            fi
        done
	## @TK - someone tried to redefine LIVEUSER to be current user. This conflicts with the config file. Correcting section
	## @TK - .... and we do not need to know about current user. Deactivating section

        #CURUSER="`who -u | grep -v root | cut -d " " -f1| uniq`"
        #if [[ "`who -u | grep -v root | cut -d " " -f1| uniq | wc -l`" != "1" ]]; then
        #    CURUSER="`grep '^[^:]*:[^:]*:1000:' /etc/passwd | awk -F ":" '{ print $1 }'`"
        #fi
        #if [[ "$CURUSER" = "" ]]; then
        #    log_msg "Can't determine which user to use. Please logoff all users except for your main user and try again. Exiting."
        #    exit 1
        #fi
        
	LIVEHOME="$WORKDIR/dummysys/home/$LIVEUSER" # @TK - I presume....
        if [[ "$BACKUPSHOWINSTALL" = "1" ]]; then
            # copy the install icon to the sudo users desktop
            log_msg "Copying the install icon to the desktop of $LIVEUSER"
            UBIQUITYDESKTOP=$(find /usr -name ubiquity*.desktop)
            install -d -o $LIVEUSER -g $LIVEUSER "$LIVEHOME/Desktop" &> /dev/null
            install -D -o $LIVEUSER -g $LIVEUSER "$UBIQUITYDESKTOP" "$LIVEHOME/Desktop/" &> /dev/null
            sed -i "s/RELEASE/$LIVECDLABEL/" "/$LIVEHOME/Desktop/$(basename $UBIQUITYDESKTOP)" &> /dev/null
        fi
	# =========================================================== /

    fi
    log_msg "Creating the casper.conf file."
    # Added FLAVOUR= as the new casper live boot will make it the first word from the Live CD Name if FLAVOUR is not set
    cat > /etc/casper.conf <<FOO
# This file should go in /etc/casper.conf
# Supported variables are:
# USERNAME, USERFULLNAME, HOST, BUILD_SYSTEM

export USERNAME="$LIVEUSER"
export USERFULLNAME="Live session user"
export HOST="$LIVEUSER"
export BUILD_SYSTEM="Ubuntu"
export FLAVOUR="$LIVEUSER"
FOO
    cp /etc/casper.conf "$WORKDIR/dummysys/etc/"

    sleep 1


    # if the mode is dist then renumber the uid's for any user with a uid greater than 1000
    # and make the passwdrestore file so the uid's are restored before the script finishes
    # if this is not done, the livecd user will not be created properly
    log_msg "Checking and setting user-setup-apply for the live system"
    if [[ "$1" = "dist" ]]; then

        # make sure user-setup-apply is present in case backup mode was last used

        if [[ -f /usr/lib/ubiquity/user-setup/user-setup-apply.orig ]]; then
            cp /usr/lib/ubiquity/user-setup/user-setup-apply.orig /usr/lib/ubiquity/user-setup/user-setup-apply
        fi

    else

        # since this is backup mode, prevent user-setup-apply from running during install
        if [[ ! -f /usr/lib/ubiquity/user-setup/user-setup-apply.orig ]]; then
            mv /usr/lib/ubiquity/user-setup/user-setup-apply /usr/lib/ubiquity/user-setup/user-setup-apply.orig
        fi
        echo "exit 0"> /usr/lib/ubiquity/user-setup/user-setup-apply
        chmod 755 /usr/lib/ubiquity/user-setup/user-setup-apply

    fi


    sleep 1

    log_msg "Setting up casper and ubiquity options for $1 mode"

    rm -f /usr/share/ubiquity/apt-setup &> /dev/null
    echo "#do nothing" > /usr/share/ubiquity/apt-setup
    chmod 755 /usr/share/ubiquity/apt-setup

    # make a new initial ramdisk including the casper scripts
    log_msg "Creating a new initial ramdisk for the live system"
    mkinitramfs -o /boot/initrd.img-$(uname -r) $(uname -r)

    log_msg "Copying your kernel and initrd for the livecd"
    cp /boot/vmlinuz-$(uname -r) "$WORKDIR"/ISOTMP/casper/vmlinuz
    cp /boot/initrd.img-$(uname -r) "$WORKDIR"/ISOTMP/casper/initrd.gz
    if [[ ! -f "$WORKDIR"/ISOTMP/casper/vmlinuz ]]; then
        log_msg "Missing valid kernel. Exiting"
        exit 1
    fi
    if [[ ! -f "$WORKDIR"/ISOTMP/casper/initrd.gz ]]; then
        log_msg "Missing valid initial ramdisk. Exiting"
        exit 1
    fi

    # Step 6 - Make filesystem.squashfs

    if [[ -f "$WORKDIR"/ISOTMP/casper/filesystem.squashfs ]]; then
        rm -f "$WORKDIR"/ISOTMP/casper/filesystem.squashfs &> /dev/null
    fi

    log_msg "Creating filesystem.squashfs   ... this will take a while so be patient"

    log_msg "Adding stage 1 files/folders that the livecd requires"

    # add the blank folders and trimmed down /var to the cd filesystem

    mksquashfs "$WORKDIR"/dummysys/ "$WORKDIR"/ISOTMP/casper/filesystem.squashfs $SQUASHFSOPTS 2> /dev/null
    SQUASHFSSIZEDUMMYSYS=$(ls -s "$WORKDIR"/ISOTMP/casper/filesystem.squashfs | awk -F " " '{print $1}')

    sleep 1

    log_msg "Adding stage 2 files/folders that the livecd requires"

    # add the rest of the system depending on the mode selected

    if [[ "$1" = "backup" ]]; then
        mksquashfs / "$WORKDIR"/ISOTMP/casper/filesystem.squashfs $SQUASHFSOPTS -e "root/.thumbnails" "root/.cache root/.bash_history" "root/.local/share/Trash" Cache "boot/grub" dev etc lost+found media mnt proc run sys tmp var "$BASEWORKDIR" $EXCLUDES $BACKUPEXCLUDES 2> /dev/null
        SQUASHFSSIZEBACKUP=$(ls -s "$WORKDIR"/ISOTMP/casper/filesystem.squashfs | awk -F " " '{print $1}')
        if [[ "$SQUASHFSSIZEBACKUP" -le "$SQUASHFSSIZEDUMMYSYS" ]]; then
            log_msg "Something is wrong. The final squashfs file is not larger than the stage 1 size. Exiting"
            exit 1
        fi

    else
        mksquashfs / "$WORKDIR"/ISOTMP/casper/filesystem.squashfs $SQUASHFSOPTS -e "root/.thumbnails root/.cache" "root/.bash_history" "root/.local/share/Trash" "Cache" "boot/grub" dev etc home lost+found media mnt proc run sys tmp var "$BASEWORKDIR" $EXCLUDES 2> /dev/null
        SQUASHFSSIZEDIST=$(ls -s "$WORKDIR"/ISOTMP/casper/filesystem.squashfs | awk -F " " '{print $1}')

        if [[ "$SQUASHFSSIZEDIST" -le "$SQUASHFSSIZEDUMMYSYS" ]]; then
            log_msg "Something is wrong. The final squashfs file is not larger than the stage 1 size and it should be. Exiting"
            exit 1
        fi

    fi

    sleep 1

    #add some stuff the log in case of problems so I can troubleshoot it easier
    echo "Updating the respin.log"
    echo "------------------------------------------------------" >>"$WORKDIR"/respin.log
    echo "Mount information" >>"$WORKDIR"/respin.log
    mount >>"$WORKDIR"/respin.log
    echo "------------------------------------------------------" >>"$WORKDIR"/respin.log
    echo "Disk size information" >>"$WORKDIR"/respin.log
    df -h >>"$WORKDIR"/respin.log
    echo "------------------------------------------------------" >>"$WORKDIR"/respin.log
    echo "Casper Script info" >>"$WORKDIR"/respin.log
    ls -l /usr/share/initramfs-tools/scripts/casper-bottom/ >>"$WORKDIR"/respin.log
    echo "------------------------------------------------------" >>"$WORKDIR"/respin.log
    echo "/etc/respin.conf info" >>"$WORKDIR"/respin.log
    cat /etc/respin.conf >>"$WORKDIR"/respin.log
    echo "------------------------------------------------------" >>"$WORKDIR"/respin.log
    echo "/etc/casper.conf info" >>"$WORKDIR"/respin.log
    cat /etc/casper.conf >>"$WORKDIR"/respin.log
    echo "------------------------------------------------------" >>"$WORKDIR"/respin.log
    echo "/etc/passwd info" >>"$WORKDIR"/respin.log
    cat "$WORKDIR"/dummysys/etc/passwd >>"$WORKDIR"/respin.log
    echo "------------------------------------------------------" >>"$WORKDIR"/respin.log
    echo "/etc/group info" >>"$WORKDIR"/respin.log
    cat "$WORKDIR"/dummysys/etc/group >>"$WORKDIR"/respin.log
    echo "------------------------------------------------------" >>"$WORKDIR"/respin.log
    echo "/etc/X11/default-display-manager info" >>"$WORKDIR"/respin.log
    cat "$WORKDIR"/dummysys/etc/X11/default-display-manager >>"$WORKDIR"/respin.log
    echo "------------------------------------------------------" >>"$WORKDIR"/respin.log
    echo "/etc/skel info" >>"$WORKDIR"/respin.log
    find /etc/skel >>"$WORKDIR"/respin.log
    echo "------------------------------------------------------" >>"$WORKDIR"/respin.log
    echo "lsb-release info" >>"$WORKDIR"/respin.log
    cat "$WORKDIR"/dummysys/etc/lsb-release >>"$WORKDIR"/respin.log
    echo "------------------------------------------------------" >>"$WORKDIR"/respin.log
    echo "respin version info" >>"$WORKDIR"/respin.log
    cat "$WORKDIR"/dummysys/etc/respin/respin.version >>"$WORKDIR"/respin.log
    echo "------------------------------------------------------" >>"$WORKDIR"/respin.log
    echo "ISOTMP info" >>"$WORKDIR"/respin.log
    ls -Rl "$WORKDIR"/ISOTMP >>"$WORKDIR"/respin.log
    echo "------------------------------------------------------" >>"$WORKDIR"/respin.log
    echo "$WORKDIR/tmpusers info" >>"$WORKDIR"/respin.log
    cat "$WORKDIR"/tmpusers >>"$WORKDIR"/respin.log
    echo "------------------------------------------------------" >>"$WORKDIR"/respin.log
    echo "Command-line options = $@" >>"$WORKDIR"/respin.log
    echo "------------------------------------------------------" >>"$WORKDIR"/respin.log


    # cleanup the install icons as they aren't needed on the current system

    if [[ "$1" = "backup" ]]; then
        log_msg "Cleaning up the install icon from the user desktops"
        rm -rf /home/*/Desktop/ubiquity*.desktop &> /dev/null
    fi

    #remove frontend from the system so the Install menu item does not appear.
    log_msg "Removing the ubiquity frontend as it has been included and is not needed on the normal system"
    apt-get -y -q remove ubiquity-frontend-kde &> /dev/null
    apt-get -y -q remove ubiquity-frontend-gtk &> /dev/null


    sleep 1

    #checking the size of the compressed filesystem to ensure it meets the iso9660 spec for a single file" 
    SQUASHFSSIZE=$(ls -s "$WORKDIR"/ISOTMP/casper/filesystem.squashfs | awk -F " " '{print $1}')
    if [[ "$SQUASHFSSIZE" -gt "3999999" ]]; then
        log_msg "The compressed filesystem is larger than genisoimage allows for a single file. You must try to reduce the amount of data you are backing up and try again."
        exit 1
    fi

    #add filesystem size for lucid
    log_msg "Calculating the installed filesystem size for the installer"

    unsquashfs -lls "$WORKDIR"/ISOTMP/casper/filesystem.squashfs | grep -v " inodes " | grep -v "unsquashfs:" | awk '{print $3}' | grep -v "," > /tmp/size.tmp

    for i in $(cat /tmp/size.tmp); do a=$(($a+$i)); done
    echo $a > "$WORKDIR"/ISOTMP/casper/filesystem.size

    log_msg "Removing respin-firstboot from system startup"
    update-rc.d -f respin-firstboot remove
    chmod 644 /etc/init.d/respin-firstboot

}

iso (){

    CREATEISO=$(which mkisofs)
    if [[ "$CREATEISO" = "" ]]; then
        CREATEISO=$(which genisoimage)
    fi

    # check to see if the cd filesystem exists

    if [[ ! -f "$WORKDIR/ISOTMP/casper/filesystem.squashfs" ]]; then
        log_msg "The filesystem.squashfs filesystem is missing.  Either there was a problem creating the compressed filesystem or you are trying to run sudo respin dist iso before sudo respin dist cdfs"
        exit 1
    fi

    SQUASHFSSIZE=$(ls -s "$WORKDIR"/ISOTMP/casper/filesystem.squashfs | awk -F " " '{print $1}')
    if [[ "$SQUASHFSSIZE" -gt "3999999" ]]; then
        log_msg "The compressed filesystem is larger than genisoimage allows for a single file. You must try to reduce the amount of data you are backing up and try again."
        exit 1
    fi

    #Step 6.5 - Added by Tim Farley. Make ISO compatible with Ubuntu Startup Disk Creator (Karmic).
    log_msg "Making disk compatible with Ubuntu Startup Disk Creator."
    . /etc/lsb-release
    touch "$WORKDIR"/ISOTMP/ubuntu
    touch "$WORKDIR"/ISOTMP/.disk/base_installable
    echo "full_cd/single" > "$WORKDIR"/ISOTMP/.disk/cd_type
    ARCH=$(archdetect | awk -F "/" '{print $1}')
    # starting with 12.04 need to have correct ubuntu version or startup disk creator uses syslinux-legacy which won't work
    DISKINFONAME=$(echo $LIVECDLABEL | awk '{print $1}')
    echo $DISKINFONAME $DISTRIB_RELEASE - Release $ARCH > "$WORKDIR"/ISOTMP/.disk/info
    echo $LIVECDURL > "$WORKDIR"/ISOTMP/.disk/release_notes_url

    # Step 7 - Make md5sum.txt for the files on the livecd - this is used during the
    # checking function of the livecd
    log_msg "Creating md5sum.txt for the livecd/dvd"
    cd "$WORKDIR"/ISOTMP && find . -type f -print0 | xargs -0 md5sum > md5sum.txt

    #isolinux mode

    # remove files that change and cause problems with checking the disk
    sed -e '/isolinux/d' -e '/md5sum/d' -i  md5sum.txt

    sleep 1

    # Step 8 - Make the ISO file
    log_msg "Creating $CUSTOMISO in "$WORKDIR""
    $CREATEISO -iso-level 3 -quiet -r -V "$LIVECDLABEL" -cache-inodes -J -l -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -o "$WORKDIR"/$CUSTOMISO "$WORKDIR/ISOTMP" 2>>"$WORKDIR"/respin.log 1>>"$WORKDIR"/respin.log
    if [[ ! -f "$WORKDIR"/$CUSTOMISO ]]; then
        log_msg "The iso was not created. There was a problem. Exiting"
        exit 1
    fi
    
    # create the md5 sum file so the user doesn't have to - this is good so the iso
    # file can later be tested to ensure it hasn't become corrupted

    log_msg "Creating $CUSTOMISO.md5 in "$WORKDIR""

    cd "$WORKDIR"
    md5sum $CUSTOMISO > $CUSTOMISO.md5

    sleep 1

    ISOSIZE=$(ls -hs "$WORKDIR/$CUSTOMISO" | awk '{print $1}')

    log_msg "$WORKDIR/$CUSTOMISO which is $ISOSIZE in size is ready to be burned or tested in a virtual machine."

}
# ===================================
# MAIN
# ===================================

# check to see if either iso or cdfs options have been invoked and proceed accordingly

if [[ "$2" = "iso" ]]; then
    iso $@
elif [[ "$2" = "cdfs" ]]; then
    cdfs $@
else
    cdfs $@
    iso $@
fi




exit 0
