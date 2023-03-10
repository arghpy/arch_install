#!/usr/bin/env bash


MODE="$1"
DISK=$(lsblk -l -n | grep "$(lsblk -l | grep "/home" | awk '{print $1}' | cut -b-3)" | head -n1 | awk '{print $1}')

# Initializing keys, setting pacman and installing wget
get_keys(){
	P_DOWNLOADS=$(grep "ParallelDownloads" /etc/pacman.conf)
	P_SIGLEVEL=$(grep -iE "^SIGLEVEL" /etc/pacman.conf)
	awk -v initial_download="$P_DOWNLOADS" -v after_download="ParallelDownloads = 5" -v initial_siglevel="$P_SIGLEVEL" -v after_siglevel="SigLevel    = Never" '{sub(initial_download, after_download); sub(initial_siglevel, after_siglevel); print}' /etc/pacman.conf > copy.pacman
	rm /etc/pacman.conf
	cp copy.pacman /etc/pacman.conf
	rm copy.pacman
	pacman-key --init
	wait
	pacman --noconfirm -Sy archlinux-keyring
	pacman --noconfirm -S wget
}


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

    get_keys

	pacman-key --init
	wait
	pacman --noconfirm -Sy

	ln -sf /usr/share/zoneinfo/Europe/Bucharest /etc/localtime

	hwclock --systohc

	change_language

	set_hostname

	grub

	echo "%wheel ALL=(ALL:ALL) ALL" >> /etc/sudoers

	set_user

	systemctl start NetworkManager
	systemctl enable NetworkManager

	systemctl enable earlyoom

    systemctl enable sshd

	ln -s /usr/bin/vim /usr/bin/vi

	printf "\n\nInstallation finished.\nType\`exit\` to get out of chroot and after that type\`shutdown now\`, take out the installation media and boot into the new system.\n\n"
}


main
