#!/usr/bin/env bash


MODE="$1"
DISK=$(lsblk -l -n | grep "$(lsblk -l | grep "/home" | awk '{print $1}' | cut -b-3)" | head -n1 | awk '{print $1}')



# Changing the language to english
change_language(){
	ENGLISH=$(grep "#en_US.UTF-8 UTF-8" /etc/locale.gen)
	awk -v initial="$ENGLISH" -v after="en_US.UTF-8 UTF-8" '{sub(initial, after); print}' /etc/locale.gen > copy.locale.gen
	rm /etc/locale.gen
	cp copy.locale.gen /etc/locale.gen
	rm copy.locale.gen
	locale-gen
	echo "LANG=en_US.UTF-8" > /etc/locale.conf
}


# Setting the hostname
set_hostname(){
	SYS_HOSTNAME=$(whiptail --title "Set Hostname" --inputbox "Please enter a hostname for the system." 10 60 3>&1 1>&2 2>&3 3>&1)
	echo "$SYS_HOSTNAME" > /etc/hostname
}


# Get user and password: script taken from Luke Smith
set_user() {
	NAME=$(whiptail --inputbox "Please enter a name for the user account." 10 60 3>&1 1>&2 2>&3 3>&1) || exit 1

	useradd -m -g wheel "$NAME" >/dev/null 2>&1
	usermod -a -G wheel "$NAME"
	printf "\n\nEnter password for %s\n\n" "$NAME"
	passwd $(echo "$NAME")

}



# Installing grub and creating configuration
grub(){

	if [[ $MODE == "UEFI" ]]; then

		pacman --noconfirm -S grub efibootmgr
		grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
		grub-mkconfig -o /boot/grub/grub.cfg

	elif [[ $MODE == "BIOS" ]]; then
		
		pacman --noconfirm -S grub 
		grub-install $(echo "/dev/$DISK")
		grub-mkconfig -o /boot/grub/grub.cfg
	else
		echo "An error occured at grub step. Exiting..."
		exit 1
	fi
}


# MAIN

main(){
	pacman-key --init
	wait
	pacman --noconfirm -Sy

	ln -sf /usr/share/zoneinfo/Europe/Bucharest /etc/localtime

	hwclock --systohc

	change_language

	set_hostname

	grub

	echo "%wheel ALL=(ALL:ALL) ALL" >> /etc/sudoers

	XDG_DEFAULTS=$(grep -iE "^enabled" /etc/xdg/user-dirs.conf)
    awk -v initial_XDG="$XDG_DEFAULTS" -v after_XDG="enabled=False" '{sub(initial_XDG, after_XDG); print}' /etc/xdg/user-dirs.conf > copy.xdg
    rm /etc/xdg/user-dirs.conf
    cp copy.xdg /etc/xdg/user-dirs.conf
    rm copy.xdg

	set_user


	systemctl start NetworkManager
	systemctl enable NetworkManager

	systemctl enable earlyoom

	ln -s /usr/bin/vim /usr/bin/vi

	printf "\n\nInstallation finished.\nType\`exit\` to get out of chroot and after that type\`shutdown now\`, take out the installation media and boot into the new system.\n\n"
}


main
