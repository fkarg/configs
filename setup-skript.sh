sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get install $(easy-reinstall-needed.txt)

# haskell-install
curl -sSL https://get.haskellstack.org/ | sh
stack setup

# rust-install
curl https://sh.rustup.rs -sSf | sh

# download uni-stuff
cd ~/Coding
git clone https://github.com/fkarg/uni-stuff




# move config files correctly
# set up auto-upstream changes
# cronjob for updating ~/Coding (with pull-all.sh)


reboot -P now
