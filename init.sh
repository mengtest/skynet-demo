echo -e '\033[91m--install autoconf--\033[0m'
sudo apt-get install autoconf
echo -e '\033[91m--install readline--\033[0m'
sudo apt-get install libreadline-dev
echo -e '\033[91m--install python-setuptools--\033[0m'
sudo apt-get install python-setuptools
echo -e '\033[91m--link server file to skynet/--\033[0m'
echo -e "\033[91m--do make--\033[0m"
make
ln -fs $(pwd)/server $(pwd)/skynet/
echo "link ok"