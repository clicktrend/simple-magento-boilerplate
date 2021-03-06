#!/usr/bin/env bash
export DEBIAN_FRONTEND=noninteractive

# /tmp has to be world-writable, but sometimes isn't by default.
chmod 0777 /tmp

# copy ssh key
cp -r /vagrant/.ssh/* /home/vagrant/.ssh/
chmod 0600 /home/vagrant/.ssh/*
chown vagrant:vagrant /home/vagrant/.ssh/*

# PHP 5.5 from PPA
apt-get update
apt-get install -y python-software-properties
add-apt-repository -y ppa:ondrej/php5
apt-get update

# Required packages
apt-get -q -y install mysql-server
apt-get install -y apache2 libnss-mdns curl git libssl0.9.8 sendmail language-pack-de-base
apt-get install -y php5-dev libapache2-mod-php5 php5-cli php5-curl php5-mcrypt php5-gd php5-mysql php-pear php5-tidy

# Zend Debug
chmod +x /vagrant/bin/vagrant-zenddebugger.sh
/vagrant/bin/vagrant-zenddebugger.sh
cp /vagrant/conf/php/zend_debugger.ini /etc/php5/mods-available/
php5enmod zend_debugger/30

# Install Ruby 2.2 via RVM
gpg --keyserver hkp://keys.gnupg.net --recv-keys D39DC0E3
curl -s -L get.rvm.io | bash -s stable
source /usr/local/rvm/scripts/rvm
rvm requirements
rvm install 2.2.0
rvm --default use 2.2.0

# Mailcatcher to test emails (needs latest Ruby)
#apt-get install -y libsqlite3-dev
gem install mailcatcher
# start mailcatcher if not already running on port 1025
# allow all ips, see https://github.com/sj26/mailcatcher/issues/89
nc -z -w5 localhost 1025 || mailcatcher --ip=0.0.0.0
cp /vagrant/conf/php/mailcatcher.ini /etc/php5/apache2/conf.d/

#Set up Git interface: use colors, add "git tree" command
git config --global color.ui true
git config --global alias.tree "log --oneline --decorate --all --graph"

# Composer
curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer

# Modman
curl -s -o /usr/local/bin/modman https://raw.githubusercontent.com/colinmollenhour/modman/master/modman
chmod +x /usr/local/bin/modman

# n98-magerun
curl -s -o /usr/local/bin/n98-magerun https://raw.githubusercontent.com/netz98/n98-magerun/master/n98-magerun.phar
chmod +x /usr/local/bin/n98-magerun

# Magento installation script, installs project in /home/vagrant
# /home/vagrant/src already exists due to rsync shared folder
chown -R vagrant:vagrant /home/vagrant
sudo -u vagrant -H sh -c "sh /vagrant/bin/vagrant-magento.sh"
# make Magento directories writable as needed and add www-data user to vagrant group
chmod -R 0777 /home/vagrant/www/var /home/vagrant/www/app/etc /home/vagrant/www/media
usermod -a -G vagrant www-data
usermod -a -G www-data vagrant

# zend debug dummy file
cp /vagrant/conf/php/dummy.php /home/vagrant/www/

# MySQL configuration, cannot be linked because MySQL refuses to load world-writable configuration
cp -f /vagrant/conf/my.cnf /etc/mysql/my.cnf
service mysql restart
# Allow access from host
mysql -uroot -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%'; FLUSH PRIVILEGES;"

# Set locale
ln -fs /vagrant/conf/locale /etc/default/locale

# Publish; Note that document root /home/vagrant/www is on the native virtual filesystem, the linked modules will be in an rsync'ed shared folder (one direction: host=>guest)
ln -fs /vagrant/conf/vhost.conf /etc/apache2/sites-available/vhost.conf
a2dissite 000-default
a2ensite vhost.conf
a2enmod proxy
a2enmod rewrite
service apache2 reload