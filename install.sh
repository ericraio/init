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

# Generate SSH Key and Deploy to Github

echo "Please add your github token with admin:public_key"
read -r github_token
TOKEN=$github_token

ssh-keygen -q -b 4096 -t rsa -N "" -f ~/.ssh/github_rsa

PUBKEY=`cat ~/.ssh/github_rsa.pub`
TITLE=`hostname`

RESPONSE=`curl -s -H "Authorization: token ${TOKEN}" \
  -X POST --data-binary "{\"title\":\"${TITLE}\",\"key\":\"${PUBKEY}\"}" \
  https://api.github.com/user/keys`

KEYID=`echo $RESPONSE \
  | grep -o '\"id.*' \
  | grep -o "[0-9]*" \
  | grep -m 1 "[0-9]*"`

echo "Public key deployed to remote service"

# Add SSH Key to the local ssh-agent"

eval "$(ssh-agent -s)"
ssh-add ~/.ssh/github_rsa

echo "Added SSH key to the ssh-agent"

# Test the SSH connection

#ssh -n -T git@github.com

# Check the exit status of the SSH command
#if [ $? -eq 0 ]; then
#else
#    echo "SSH connection failed."
#fi

echo "==========================================="
echo "Setting up your mac"
echo "==========================================="

# Continue with your remaining commands
yadm clone git@github.com:ericraio/dotfiles.git
