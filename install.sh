#!/bin/bash
set -e

SH_PATH=$(cd $(dirname $0) && pwd)
cd $SH_PATH

echo -e "\e[31m--- Basic Setup ---\e[m"
sudo apt update && sudo DEBIAN_FRONTEND=noninteractive apt install -y wget curl git build-essential sudo

# Configuration files
wget https://raw.githubusercontent.com/iwashiira/sig-beginners-pwn-public/main/.gdbinit -O $HOME/.gdbinit
wget https://raw.githubusercontent.com/iwashiira/sig-beginners-pwn-public/main/.bashrc -O $HOME/.bashrc
sudo wget https://raw.githubusercontent.com/iwashiira/sig-beginners-pwn-public/main/manage_aslr.sh -O /usr/local/bin/aslr
sudo chmod +x /usr/local/bin/aslr

# Neovim (Latest Stable)
echo -e "\e[31m--- Neovim installation ---\e[m"
wget https://github.com/neovim/neovim/releases/download/stable/nvim-linux-x86_64.tar.gz -O /tmp/nvim-linux64.tar.gz
sudo tar xzf /tmp/nvim-linux64.tar.gz -C /usr/local --strip-components=1
rm /tmp/nvim-linux64.tar.gz

echo -e "\e[31m--- Docker installation ---\e[m"
if ! command -v docker &> /dev/null; then
    for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do sudo apt-get remove -y $pkg || true; done

    sudo apt update && sudo DEBIAN_FRONTEND=noninteractive apt install -y ca-certificates
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt update
    sudo DEBIAN_FRONTEND=noninteractive apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
else
    echo -e "\e[33mDocker is already installed. Skipping installation.\e[m"
fi

echo -e "\e[31m--- Dependencies installation ---\e[m"
sudo apt update && sudo DEBIAN_FRONTEND=noninteractive apt install -y \
    libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev \
    llvm make zip unzip libncurses5-dev libncursesw5-dev xz-utils tk-dev \
    libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev libyaml-dev \
    python3 python3-dev python3-pip gcc tree git pkg-config netcat-openbsd patchelf \
    ruby ruby-dev

python3 -m pip install -U pip

echo -e "\e[31m--- Cargo & Rust Tools ---\e[m"
if ! command -v cargo &> /dev/null; then
    curl https://sh.rustup.rs -sSf | sh -s -- -y
    source "$HOME/.cargo/env"
    if ! grep -q 'source "$HOME/.cargo/env"' "$HOME/.bashrc"; then
        echo 'source "$HOME/.cargo/env"' >> "$HOME/.bashrc"
    fi
fi
cargo install ropr

echo -e "\e[31m--- Node.js installation (nvm) ---\e[m"
NVM_VERSION=$(curl -s https://api.github.com/repos/nvm-sh/nvm/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm install 20

echo -e "\e[31m--- Pwnable Tools ---\e[m"

# checksec (tar.gzを展開するように修正。API制限時はBash版へフォールバック)
echo "Installing checksec..."
CHECKSEC_URL=$(curl -s https://api.github.com/repos/slimm609/checksec/releases/latest | grep browser_download_url | grep 'linux_amd64.tar.gz' | cut -d '"' -f 4 | head -n 1)
if [ -n "$CHECKSEC_URL" ]; then
    wget "$CHECKSEC_URL" -O /tmp/checksec.tar.gz
    tar xzf /tmp/checksec.tar.gz -C /tmp
    sudo install /tmp/checksec /usr/local/bin/checksec
else
    echo -e "\e[33mFailed to get checksec URL. Falling back to bash version...\e[m"
    sudo wget -q https://raw.githubusercontent.com/slimm609/checksec.sh/master/checksec -O /usr/local/bin/checksec
    sudo chmod +x /usr/local/bin/checksec
fi


# python libraries
python3 -m pip install pwntools pathlib2 ptrlib --break-system-packages || python3 -m pip install pwntools pathlib2 ptrlib

# ruby tools
sudo gem install one_gadget seccomp-tools

# Directory for Tools
PWNDIR="$HOME/pwn"
TOOLS_DIR="$PWNDIR/Tools"
mkdir -p "$TOOLS_DIR"

# pwndbg
echo -e "\e[33mInstalling pwndbg... (This may take a few minutes as it builds a Python venv)\e[m"
if [ ! -d "$TOOLS_DIR/pwndbg" ]; then
    git clone https://github.com/pwndbg/pwndbg "$TOOLS_DIR/pwndbg"
    cd "$TOOLS_DIR/pwndbg" && DEBIAN_FRONTEND=noninteractive ./setup.sh
else
    cd "$TOOLS_DIR/pwndbg" && git pull && DEBIAN_FRONTEND=noninteractive ./setup.sh
fi

# bata24/gef
wget -q https://raw.githubusercontent.com/bata24/gef/dev/install-uv.sh -O- | sudo DEBIAN_FRONTEND=noninteractive sh

# Root setup for convenience
sudo mkdir -p /root/pwn
sudo ln -sf "$TOOLS_DIR" /root/pwn/Tools
sudo cp "$HOME/.gdbinit" /root/

echo -e "\e[34m--- All tools installed successfully ---\e[m"
echo -e "\e[33mPlease restart your terminal or run 'source ~/.bashrc' to apply path changes.\e[m"