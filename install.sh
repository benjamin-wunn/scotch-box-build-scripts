#!/bin/bash

# /*=================================
# =            VARIABLES            =
# =================================*/

INSTALL_NGINX_INSTEAD_OF_APACHE=0

SHELLPACKAGES="nfs-common debconf-utils build-essential tcl software-properties-common tmus nano htop python-software-properties git vim ifupdown libenchant-dev ldap-utils curl imagemagick"

PHPVERSION="7.3"
INSTALLCOMPOSER=1

INSTALLMARIADB=1
MARIADBLVERSION="10.4"

INSTALLPOSTRESQL=0

INSTALLSQLITE=0

INSTALLMONGODB=0
MONGODBVERSION=""

INSTALLWPCLI=1
INSTALLDRUSH=0

INSTALLNODEJS=1
NODEJSVERSION="12.4.0"
NODEJSGLOBALPACKAGES="terser gulp-cli grunt-cli bower yo browser-sync browserify pm2 webpack @pingy/cli autoprefixer caniuse-cmd codesandbox eslint eslint-config-standard eslint-plugin-import eslint-plugin-node eslint-plugin-promise eslint-plugin-standard node-sass sass stylelint stylelint-config-standard"

INSTALLRUBY=1
RUBYVERSION="2.6.3"

INSTALLGOLANG=0

INSTALLNGROK=1
INSTALLBEANSTALKD=1
INSTALLREDIS=1
INSTALLMEMCACHED=1
INSTALLMAILHOG=0

INSTALLFISH=1

reboot_webserver_helper() {
    if [ $INSTALL_NGINX_INSTEAD_OF_APACHE != 1 ]; then
        sudo service apache2 restart
    fi

    if [ $INSTALL_NGINX_INSTEAD_OF_APACHE == 1 ]; then
        sudo systemctl restart php${PHPVERSION}-fpm
        sudo systemctl restart nginx
    fi
}

# /*=========================================
# =            CORE / BASE STUFF            =
# =========================================*/
sudo apt-get update

# The following is "sudo apt-get -y upgrade" without any prompts
sudo DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" upgrade
sudo DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" dist-upgrade

sudo apt-get install -y ${SHELLPACKAGES}

# /*======================================
# =            INSTALL APACHE/NGINX            =
# ======================================*/
if [ $INSTALL_NGINX_INSTEAD_OF_APACHE = 0 ]; then
    # Install Apache
    sudo add-apt-repository -y ppa:ondrej/apache2 # Super Latest Version
    sudo apt-get update
    sudo apt-get install -y apache2

    # Remove "html" and add public
    mv /var/www/html /var/www/public

    # Clean VHOST with full permissions
    MY_WEB_CONFIG='<VirtualHost *:80>
        ServerAdmin webmaster@localhost
        DocumentRoot /var/www/public
        ErrorLog ${APACHE_LOG_DIR}/error.log
        CustomLog ${APACHE_LOG_DIR}/access.log combined
        <Directory "/var/www/public">
            Options Indexes FollowSymLinks
            AllowOverride all
            Require all granted
        </Directory>
    </VirtualHost>'
    echo "$MY_WEB_CONFIG" | sudo tee /etc/apache2/sites-available/000-default.conf

    # Squash annoying FQDN warning
    echo "ServerName scotchbox" | sudo tee /etc/apache2/conf-available/servername.conf
    sudo a2enconf servername

    # Enabled missing h5bp modules (https://github.com/h5bp/server-configs-apache)
    sudo a2enmod expires
    sudo a2enmod headers
    sudo a2enmod include
    sudo a2enmod rewrite

    sudo service apache2 restart
else
    # Install Nginx
    sudo add-apt-repository -y ppa:ondrej/nginx-mainline # Super Latest Version
    sudo apt-get update
    sudo apt-get install -y nginx
    sudo systemctl enable nginx

    # Remove "html" and add public
    mv /var/www/html /var/www/public

    # Make sure your web server knows you did this...
    MY_WEB_CONFIG='server {
        listen 80 default_server;
        listen [::]:80 default_server;

        root /var/www/public;
        index index.html index.htm index.nginx-debian.html;

        server_name _;

        location = /favicon.ico { access_log off; log_not_found off; }
        location = /robots.txt  { access_log off; log_not_found off; }

        location / {
            try_files $uri $uri/ /index.php?$query_string;
        }
    }'
    echo "$MY_WEB_CONFIG" | sudo tee /etc/nginx/sites-available/default

    sudo systemctl restart nginx

fi

# /*===================================
# =            INSTALL PHP            =
# ===================================*/

# Install PHP
sudo add-apt-repository -y ppa:ondrej/php
sudo apt-get update
sudo apt-get install -y php${PHPVERSION}

# Make PHP and NGINX/Apache friends
if [ $INSTALL_NGINX_INSTEAD_OF_APACHE == 1 ]; then

    # FPM STUFF
    sudo apt-get install -y php${PHPVERSION}-fpm
    sudo systemctl enable php${PHPVERSION}-fpm
    sudo systemctl start php${PHPVERSION}-fpm

    # Fix path FPM setting
    echo 'cgi.fix_pathinfo = 0' | sudo tee -a /etc/php/${PHPVERSION}/fpm/conf.d/user.ini
    sudo systemctl restart php${PHPVERSION}-fpm

    # Add index.php to readable file types and enable PHP FPM since PHP alone won't work
    MY_WEB_CONFIG='server {
        listen 80 default_server;
        listen [::]:80 default_server;

        root /var/www/public;
        index index.php index.html index.htm index.nginx-debian.html;

        server_name _;

        location = /favicon.ico { access_log off; log_not_found off; }
        location = /robots.txt  { access_log off; log_not_found off; }

        location / {
            try_files $uri $uri/ /index.php?$query_string;
        }

        location ~ \.php$ {
            include snippets/fastcgi-php.conf;
            fastcgi_pass unix:/run/php/php'+${PHPVERSION}+'-fpm.sock;
        }

        location ~ /\.ht {
            deny all;
        }
    }'
    echo "$MY_WEB_CONFIG" | sudo tee /etc/nginx/sites-available/default

    sudo systemctl restart nginx

else

    sudo apt-get install -y libapache2-mod-php

    # Add index.php to readable file types
    MAKE_PHP_PRIORITY='<IfModule mod_dir.c>
        DirectoryIndex index.php index.html index.cgi index.pl index.xhtml index.htm
    </IfModule>'
    echo "$MAKE_PHP_PRIORITY" | sudo tee /etc/apache2/mods-enabled/dir.conf

    sudo service apache2 restart

fi


# /*===================================
# =            PHP MODULES            =
# ===================================*/

sudo apt-get install -y php${PHPVERSION}-common php${PHPVERSION}-dev php${PHPVERSION}-bcmath php${PHPVERSION}-bz2 php${PHPVERSION}-cgi php${PHPVERSION}-cli php${PHPVERSION}-fpm php${PHPVERSION}-gd php${PHPVERSION}-imap php${PHPVERSION}-intl php${PHPVERSION}-json php${PHPVERSION}-mbstring php${PHPVERSION}-odbc php-pear php${PHPVERSION}-pspell php${PHPVERSION}-tidy php${PHPVERSION}-xmlrpc php${PHPVERSION}-zip php${PHPVERSION}-enchant php${PHPVERSION}-ldap php${PHPVERSION}-curl php${PHPVERSION}-imagick

# /*===========================================
# =            CUSTOM PHP SETTINGS            =
# ===========================================*/
if [ $INSTALL_NGINX_INSTEAD_OF_APACHE == 1 ]; then
    PHP_USER_INI_PATH=/etc/php/${PHPVERSION}/fpm/conf.d/user.ini
else
    PHP_USER_INI_PATH=/etc/php/${PHPVERSION}/apache2/conf.d/user.ini
fi

echo 'display_startup_errors = On' | sudo tee -a $PHP_USER_INI_PATH
echo 'display_errors = On' | sudo tee -a $PHP_USER_INI_PATH
echo 'error_reporting = E_ALL' | sudo tee -a $PHP_USER_INI_PATH
echo 'short_open_tag = On' | sudo tee -a $PHP_USER_INI_PATH

reboot_webserver_helper

# Disable PHP Zend OPcache
echo 'opache.enable = 0' | sudo tee -a $PHP_USER_INI_PATH

# Absolutely Force Zend OPcache off...
if [ $INSTALL_NGINX_INSTEAD_OF_APACHE == 1 ]; then
    sudo sed -i s,\;opcache.enable=0,opcache.enable=0,g /etc/php/${PHPVERSION}/fpm/php.ini
else
    sudo sed -i s,\;opcache.enable=0,opcache.enable=0,g /etc/php/${PHPVERSION}/apache2/php.ini
fi

reboot_webserver_helper

# /*================================
# =            PHP UNIT            =
# ================================*/
sudo wget https://phar.phpunit.de/phpunit-6.1.phar
sudo chmod +x phpunit-6.1.phar
sudo mv phpunit-6.1.phar /usr/local/bin/phpunit
reboot_webserver_helper

# /*=============================
# =            MYSQL            =
# =============================*/
if [ $INSTALLMARIADB == 1 ]; then
    sudo apt-get remove -y mysql-server
    sudo apt-get remove -y mariadb-server

    sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password password root'
    sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password_again password root'

    sudo apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xF1656F24C74CD1D8
    sudo add-apt-repository 'deb [arch=amd64] http://mirror.zol.co.zw/mariadb/repo/'${MARIADBLVERSION}'/ubuntu bionic main'

    sudo apt-get install -y mariadb-server mariadb-client
    sudo mysqladmin -uroot -proot create scotchbox
    sudo apt-get install -y php${PHPVERSION}-mysql
    reboot_webserver_helper
fi

# /*=================================
# =            PostreSQL            =
# =================================*/
if [ $INSTALLPOSTRESQL == 1 ]; then
    sudo apt-get install -y postgresql postgresql-contrib
    echo "CREATE ROLE root WITH LOGIN ENCRYPTED PASSWORD 'root';" | sudo -i -u postgres psql
    sudo -i -u postgres createdb --owner=root scotchbox
    sudo apt-get install -y php${PHPVERSION}-pgsql
    reboot_webserver_helper
fi

# /*==============================
# =            SQLITE            =
# ===============================*/
if [ $INSTALLSQLITE == 1 ]; then
    sudo apt-get install -y sqlite
    sudo apt-get install -y php${PHPVERSION}-sqlite3
    reboot_webserver_helper
fi

# /*===============================
# =            MONGODB            =
# ===============================*/
if [ $INSTALLMONGODB == 1 ]; then
    sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv EA312927
    echo "deb http://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/3.2 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-3.2.list
    sudo apt-get update
    sudo apt-get install -y mongodb-org

    sudo tee /lib/systemd/system/mongod.service < \[Unit\]\n Description=High-performance, schema-free document-oriented database\n\nAfter=network.target\nDocumentation=https://docs.mongodb.org/manual\n\[Service\]\nUser=mongodb\nGroup=mongodb\nExecStart=/usr/bin/mongod --quiet --config /etc/mongod.conf\n\n\[Install\]\nWantedBy=multi-user.target

    sudo systemctl enable mongod
    sudo service mongod start

    # Enable it for PHP
    sudo pecl install mongodb
    sudo apt-get install -y php${PHPVERSION}-mongodb

    reboot_webserver_helper
fi

# /*================================
# =            COMPOSER            =
# ================================*/
if [ $INSTALLCOMPOSER == 1 ]; then
    php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
    php composer-setup.php --quiet
    rm composer-setup.php
    sudo mv composer.phar /usr/local/bin/composer
    sudo chmod 755 /usr/local/bin/composer
fi

# /*==================================
# =            BEANSTALKD            =
# ==================================*/
if [ $INSTALLBEANSTALKD == 1 ]; then
    sudo apt-get install -y beanstalkd
fi

# /*==============================
# =            WP-CLI            =
# ==============================*/
if [ $INSTALLWPCLI == 1 ]; then
    curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
    sudo chmod +x wp-cli.phar
    sudo mv wp-cli.phar /usr/local/bin/wp
fi
# /*=============================
# =            DRUSH            =
# =============================*/
if [ $INSTALLDRUSH == 1 ]; then
    wget -O drush.phar https://github.com/drush-ops/drush-launcher/releases/download/0.5.1/drush.phar
    sudo chmod +x drush.phar
    sudo mv drush.phar /usr/local/bin/drush
fi

# /*=============================
# =            NGROK            =
# =============================*/
if [ $INSTALLNGROK == 1 ]; then
    sudo apt-get install -y ngrok-client
fi

# /*==============================
# =            NODEJS            =
# ==============================*/
if [ $INSTALLNODEJS == 1 ]; then
    sudo apt-get install -y nodejs
    sudo apt-get install -y npm

    wget -qO- https://raw.github.com/creationix/nvm/master/install.sh | bash
    source ~/.nvm/nvm.sh
    nvm install ${NODEJSVERSION}
    sudo npm install -g ${NODEJSGLOBALPACKAGES}

    curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
    echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
    sudo apt-get update
    sudo apt-get install -y yarn
fi

# /*============================
# =            RUBY            =
# ============================*/
if [ $INSTALLRUBY == 1 ]; then
    sudo apt-get install -y ruby
    sudo apt-get install -y ruby-dev

    gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3
    curl -sSL https://get.rvm.io | bash -s stable
    source ~/.rvm/scripts/rvm
    rvm install ${RUBYVERSION}
    rvm use ${RUBYVERSION}
fi

# /*=============================
# =            REDIS            =
# =============================*/
if [ $INSTALLREDIS == 1 ]; then
    sudo apt-get install -y redis-server
    sudo apt-get install -y php${PHPVERSION}-redis
    reboot_webserver_helper
fi

# /*=================================
# =            MEMCACHED            =
# =================================*/
if [ $MEMCACHED == 1 ]; then
    sudo apt-get install -y memcached
    sudo apt-get install -y php${PHPVERSION}-memcached
    reboot_webserver_helper
fi

# /*==============================
# =            GOLANG            =
# ==============================*/
if [ $INSTALLGOLANG == 1 ]; then
    sudo add-apt-repository -y ppa:longsleep/golang-backports
    sudo apt-get update
    sudo apt-get install -y golang-go
fi

# /*===============================
# =            MAILHOG            =
# ===============================*/
if [ $INSTALLMAILHOG == 1 ]; then
    sudo wget --quiet -O ~/mailhog https://github.com/mailhog/MailHog/releases/download/v1.0.0/MailHog_linux_amd64
    sudo chmod +x ~/mailhog

    # Enable and Turn on
    sudo tee /etc/systemd/system/mailhog.service < \[Unit\]\nDescription=MailHog Service\nAfter=network.service vagrant.mount\n\[Service\]\nType=simple\nExecStart=/usr/bin/env /home/vagrant/mailhog > /dev/null 2>&1 &\n\[Install\]\nWantedBy=multi-user.target
    sudo systemctl enable mailhog
    sudo systemctl start mailhog

    # Install Sendmail replacement for MailHog
    sudo go get github.com/mailhog/mhsendmail
    sudo ln ~/go/bin/mhsendmail /usr/bin/mhsendmail
    sudo ln ~/go/bin/mhsendmail /usr/bin/sendmail
    sudo ln ~/go/bin/mhsendmail /usr/bin/mail

    # Make it work with PHP
    if [ $INSTALL_NGINX_INSTEAD_OF_APACHE == 1 ]; then
        echo 'sendmail_path = /usr/bin/mhsendmail' | sudo tee -a /etc/php/${PHPVERSION}/fpm/conf.d/user.ini
    else
        echo 'sendmail_path = /usr/bin/mhsendmail' | sudo tee -a /etc/php/${PHPVERSION}/apache2/conf.d/user.ini
    fi

    reboot_webserver_helper
fi

# /*===============================
# =             FISH             =
# ===============================*/
if [ $INSTALLFISH == 1 ]; then
    sudo apt-get install -y fish
    curl -L https://get.oh-my.fish | fish
    omf install bobthefish
    omf theme bobthefish
    chsh -s /usr/bin/fish
fi

# /*===================================================
# =            FINAL GOOD MEASURE, WHY NOT            =
# ===================================================*/
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" upgrade
reboot_webserver_helper

# /*====================================
# =            YOU ARE DONE            =
# ====================================*/
echo 'shell script finished'
