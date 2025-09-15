#!/usr/bin/env bash


function step_begin() {
	printf "      $1\n"
}

function step_end() {
	if [ $1 -eq 0 ]; then
		printf "[ \e[32mX\e[0m ] $2\n"
	else
		printf "[ \e[31mX\e[0m ] $2\n"
	fi
}


printf "WARNING: On top of installing Calzone, this script will create a new user for calzone,\n"
printf "start the systemd service for it, and set up autologin for a user named cal on tty1\n\n"
printf "If this is not what you are expecting, you should edit this script and remove the\n"
printf "relevant parts\n"

read -n 1 -r -p "Are you OK with this? [y/N] " user_confirmation
printf "\n"

if [ "${user_confirmation}" != "y" ] && [ "${user_confirmation}" != "Y" ]; then
    exit
fi


step_begin "Compiling calzone ui"
make -C ui
step_end $? "Compiled calzone ui"
step_begin "Installing calzone ui"
sudo make -C ui install
step_end $? "Installed calzone ui"


step_begin "Compiling calzone server"
pushd server
go build -o ./calzone
popd
step_end $? "Compiled calzone server"
step_begin "Installing calzone server"
sudo cp ./server/calzone /usr/local/bin/
sudo chown root:root /usr/local/bin/calzone
sudo chmod 755 /usr/local/bin/calzone
sudo setcap CAP_NET_BIND_SERVICE=+eip /usr/local/bin/calzone

sudo mkdir -p /usr/local/share/calzone
sudo cp -r ./websource /usr/local/share/calzone/
sudo chown root:root /usr/local/share/calzone
sudo chmod 755 /usr/local/share/calzone
step_end $? "Installed calzone server"


step_begin "Creating calzone user"
if ! id calzone > /dev/null 2>&1; then
	sudo useradd --system -s /usr/sbin/nologin -U calzone -G video
fi
step_end $? "Created calzone user"


step_begin "Creating events directory"
sudo mkdir -p /var/lib/calzone
sudo chown -R calzone:calzone /var/lib/calzone
sudo chmod 700 -R /var/lib/calzone
step_end $? "Created events directory"


step_begin "Setting up autostart"
sudo cp autologin.conf /etc/systemd/system/getty@tty1.service.d/
sudo chown root:root /etc/systemd/system/getty@tty1.service.d/autologin.conf
sudo chmod 644 /etc/systemd/system/getty@tty1.service.d/autologin.conf
step_end $? "Set up autostart"

step_begin "Starting calzone server service"
sudo cp calzone.service /etc/systemd/system/
sudo chown root:root /etc/systemd/system/calzone.service
sudo chmod 644 /etc/systemd/system/calzone.service
sudo systemctl enable --now calzone
step_end $? "Started calzone server service"


printf "Finished installing\n"
printf "You may want to add this line to /etc/sudoers so you can run calzone_ui as calzone without a password:\n"
printf "$(id -u --name) ALL=(calzone:calzone) NOPASSWD: /usr/local/bin/calzone_ui\n\n"
if [ -f /etc/sudoers.d/010_pi-nopasswd ]; then
	printf "I also recommend deleting the /etc/sudoers.d/010_pi-nopasswd file to require a password to use sudo\n\n"
fi

printf "It may also be a good idea to install and enable ufw. Just make sure to allow 22/tcp for ssh and 80/tcp for HTTP\n\n"

printf "Finally, you might want to add this to the end of your .bashrc so that calzone_ui autostarts when logging into tty1:\n"
printf "alias hide_cursor='printf \"\\\\e[?25l\"'\n"
printf "alias show_cursor='printf \"\\\\e[?25h\"'\n\n\n"

printf "if [ \"\$(tty)\" = '/dev/tty1' ] && [ -f /usr/local/bin/calzone_ui ]; then\n"
printf "    hide_cursor\n"
printf "    sudo -u calzone -g calzone /usr/local/bin/calzone_ui > /dev/null 2>&1\n"
printf "    clear\n"
printf "    show_cursor\n"
printf "fi\n"

