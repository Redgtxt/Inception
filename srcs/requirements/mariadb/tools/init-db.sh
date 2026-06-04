#!/bin/bash

#Checks if BD directory already exists
if [ -d "/var/lib/mysql/$DB_NAME" ]
then
    echo "Database '$DB_NAME' already exists.Starting normally..."
else
    echo "First Start detected.Configurating MariaDB..."

    #start mariadb temporarily in background so we can enject sql comands
    service mariadb start

    #Wait 2 seconds to make sure the service can receive comands
    sleep 2

    mysql -u root << EOF
    CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`;
    CREATE USER IF NOT EXISTS \`${DB_USER}\`@'%' IDENTIFIED BY '${DB_PASSWORD}';
    GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO \`${DB_USER}\`@'%';
    ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';
    FLUSH PRIVILEGES
EOF

    echo "Database and users created with sucess!"

    #Let's shutdown service temp
    mysqladmin -u root -p"${DB_ROOT_PASSWORD}" shutdown

    #wait 1 second to make sure everything went nicely
    sleep 1
fi 

#exec will replace the script with the process mysqld_safe
#In that way MariaDB is now running in the foregound
echo "Starting MariaDB in foreground..."
exec mysqld_safe