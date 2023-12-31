#!/usr/bin/env bash
# script to bootstrap setting up a mac with ansible

set -e

export ANSIBLE_HOME=${XDG_CONFIG_HOME:-$HOME/.config}/ansible/

# Because Git submodule commands cannot operate without a work tree, they must
# be run from within $HOME (assuming this is the root of your dotfiles)
cd "$HOME"

is_mac() {
	if [[ "$OSTYPE" == darwin* ]]; then
		return 0
	else
		return 1
	fi
}

is_linux() {
	if [[ $"OSTYPE" == linux* ]]; then
		return 0
	else
		return 1
	fi
}

is_debian() {
	if [ -f /etc/debian_version ]; then
		return 0
	else
		return 1
	fi
}

is_fedora() {
	if is_linux && uname -a | grep -q Fedora; then
		return 0
	else
		return 1
	fi
}

is_arch() {
	# if [ -f "/etc/arch-release" ]; then
	if is_linux && uname -a | grep -Eq 'manjaro|antergos|arch'; then
		return 0
	else
		return 1
	fi
}

is_crostini() {
	if [ -d /etc/systemd/user/sommelier@0.service.d ]; then
		return 0
	else
		return 1
	fi
}

##############################
# Colors
##############################
end="\033[0m"
black="\033[0;30m"
blackb="\033[1;30m"
white="\033[0;37m"
whiteb="\033[1;37m"
red="\033[0;31m"
redb="\033[1;31m"
green="\033[0;32m"
greenb="\033[1;32m"
yellow="\033[0;33m"
yellowb="\033[1;33m"
blue="\033[0;34m"
blueb="\033[1;34m"
purple="\033[0;35m"
purpleb="\033[1;35m"
cyan="\033[0;36m"
cyanb="\033[1;36m"

black() {
	echo -e "${black}${1}${end}"
}

blackb() {
	echo -e "${blackb}${1}${end}"
}

white() {
	echo -e "${white}${1}${end}"
}

whiteb() {
	echo -e "${whiteb}${1}${end}"
}

red() {
	echo -e "${red}${1}${end}"
}

redb() {
	echo -e "${redb}${1}${end}"
}

green() {
	echo -e "${green}${1}${end}"
}

greenb() {
	echo -e "${greenb}${1}${end}"
}

yellow() {
	echo -e "${yellow}${1}${end}"
}

yellowb() {
	echo -e "${yellowb}${1}${end}"
}

blue() {
	echo -e "${blue}${1}${end}"
}

blueb() {
	echo -e "${blueb}${1}${end}"
}

purple() {
	echo -e "${purple}${1}${end}"
}

purpleb() {
	echo -e "${purpleb}${1}${end}"
}

cyan() {
	echo -e "${cyan}${1}${end}"
}

cyanb() {
	echo -e "${cyanb}${1}${end}"
}

# Print
column() {
	printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
}

prompt_install() {
	local RETVALUE=0

	read -rp "Install $1? [y/n]" yn

	case $yn in
	[Yy]*) RETVALUE=0 ;;
	*) RETVALUE=1 ;;
	esac

	return $RETVALUE
}

##############################
# Caffeinate machine.
##############################
caffeinate_machine() {
	pid=$(pgrep -x caffeinate)

	if [[ -n "$pid" ]]; then
		echo "Machine is already caffeinated!"
	else
		caffeinate -s -u -d -i -t 3153600000 >/dev/null &
		echo "Machine caffeinated."
	fi
}

# Sober machine.
sober_machine() {
	pid=$(pgrep -x caffeinate)

	if [[ -n "$pid" ]]; then
		killall caffeinate
		whiteb "Machine is now sober!"
	else
		whiteb "Machine is already sober!"
	fi
}

setup_github() {
	# Generate SSH Key and Deploy to Github
	read -rp "Please add your github token with admin:public_key" github_token
	TOKEN=$github_token

	# Add SSH Key to the local ssh-agent"
	ssh-keygen -q -b 4096 -t rsa -N "" -f ~/.ssh/github_rsa

	PUBKEY=$(cat ~/.ssh/github_rsa.pub)
	TITLE=$(hostname)

	RESPONSE=$(curl -s -H "Authorization: token ${TOKEN}" \
		-X POST --data-binary "{\"title\":\"${TITLE}\",\"key\":\"${PUBKEY}\"}" \
		https://api.github.com/user/keys)

	KEYID=$(echo $RESPONSE |
		grep -o '\"id.*' |
		grep -o "[0-9]*" |
		grep -m 1 "[0-9]*")

	white "Public key deployed to remote service"

	eval "$(ssh-agent -s)"
	ssh-add ~/.ssh/github_rsa

	white "Added SSH key to the ssh-agent"
}

install_brew_deps() {
	white "Downloading homebrew"
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	eval "$(/opt/homebrew/bin/brew shellenv)"
	brew analytics off
	brew install ansible yadm
	rm -rf ~/.ansible
}

mac_install_basics() {
	# Installs basic system settings.
	read -rp "What is this machine's label (Example: \"Eric's Mac Studio\")? " mac_os_label
	if [[ -z "$mac_os_label" ]]; then
		red "ERROR: Invalid MacOS label."
		exit 1
	fi

	read -p "What is this machine's name (Example: \"Erics-Mac-Studio\")? " mac_os_name
	if [[ -z "$mac_os_name" ]]; then
		red "ERROR: Invalid MacOS name."
		exit 1
	fi

	read -p "Delete all files in $HOME/Documents (y/n)? " documents
	if [[ "$documents" == "y" ]]; then
		rm -rf $HOME/Documents/*
		yellow "Documents deleted."
	fi

	read -p "Delete all files in $HOME/Downloads (y/n)? " downloads
	if [[ "$downloads" == "y" ]]; then
		rm -rf $HOME/Downloads/*
		yellow "Downloads deleted."
	fi

	read -p "Delete all files in $HOME/.Trash (y/n)? " trash
	if [[ "$trash" == "y" ]]; then
		osascript -e 'tell app "Finder" to empty'
		yellow "Trash deleted."
	fi

	read -p "Change /usr/local ownership to $USER:staff (y/n)? " ownership
	if [[ "$ownership" == "y" ]]; then
		sudo chown -R "$USER":staff /usr/local
		yellow "Ownership changed."
	fi

	yellowb "Setting system label and name..."
	sudo scutil --set ComputerName $mac_os_label
	sudo scutil --set HostName $mac_os_name
	sudo scutil --set LocalHostName $mac_os_name
	sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.smb.server NetBIOSName -string $mac_os_name
	green "Basic system settings has been changed."
}

mac_install() {
	mac_install_basics
	column
	install_brew_deps

	column
	whiteb "==========================================="
	cyanb "Setting up your mac"
	whiteb "==========================================="

	blueb "Installing Xcode CLI tools...\n"
	xcode-select --install

	whiteb "💡 CMD+TAB to view and accept Xcode license window."
	read -p "Have you completed the Xcode CLI tools install (y/n)? " xcode_response
	if [[ "$xcode_response" != "y" ]]; then
		redb "ERROR: Xcode CLI tools must be installed before proceeding.\n"
		exit 1
	fi

	if [[ "$(/usr/bin/arch)" == "arm64" ]]; then
		softwareupdate --install-rosetta --agree-to-license
	fi

	greenb "Xcode CLI Tools was installed successfully."

}

caffeinate_machine

setup_github

if is_mac; then
	mac_install
fi

# Continue with your remaining commands
yadm clone git@github.com:ericraio/dotfiles.git
