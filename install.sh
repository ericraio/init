#!/usr/bin/env bash
# script to bootstrap setting up a mac with ansible

set -ex

export ANSIBLE_HOME=${XDG_CONFIG_HOME:-$HOME/.config}/ansible/

# Because Git submodule commands cannot operate without a work tree, they must
# be run from within $HOME (assuming this is the root of your dotfiles)
cd "$HOME"

function is_mac {
	if [[ "$OSTYPE" == darwin* ]]; then
		return 0
	else
		return 1
	fi
}

function is_linux {
	if [[ "$OSTYPE" == linux* ]]; then
		return 0
	else
		return 1
	fi
}

function uninstall {
	echo "WARNING : This will remove homebrew and all applications installed through it"
	echo -n "are you sure you want to do that? [y/n] : "
	read -r confirmation

	if [ "$confirmation" == "y" ]; then
		/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/uninstall)"
		exit 0
	else
		echo "keeping everything intact"
		exit 0
	fi
}

if [ "$1" == "uninstall" ]; then
	uninstall
fi

if is_mac; then
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
 	eval "$(/opt/homebrew/bin/brew shellenv)"
	brew analytics off
	brew install ansible yadm
	rm -rf ~/.ansible
fi

echo "==========================================="
echo "Setting up your mac"
echo "==========================================="

yadm clone git@github.com:ericraio/dotfiles.git