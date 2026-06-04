#vamos usar a penultima versao
FROM debian:bookworm

#Lets install PHP-FPM, extension for MYSQL to work with PHP,Curl and unzip to be able to download and extract wordpress
#And MariaDB client to be able to connect to the database server
RUN apt-get update && apt-get install -y \
    php-fpm \
    php-mysql \
    curl \
    mariadb-client \
    && rm -rf /var/lib/apt/lists/*

#Download WP-CLI,give perms and move to the bin to be able to use it from anywhere
RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x wp-cli.phar \
    && mv wp-cli.phar /usr/local/bin/wp

#PHP-FPM needs to listen to the 9000 port to be able to comunicate with Nginx
RUN sed -i 's|^listen = .*|listen = 9000|' /etc/php/8.2/fpm/pool.d/www.conf

#Create folder where the PHP sotrees the file PID 
RUN mkdir -p /run/php

#Defines the folder where the wordpress files will be stored
WORKDIR /var/www/html

#Copy the script to the container
COPY ./tools/init-wp.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/init-wp.sh

#Port where the services will comunicate
EXPOSE 9000

#Define the scipt has the main comando when the container starts
ENTRYPOINT [ "/usr/local/bin/init-wp.sh" ]