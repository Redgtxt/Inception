#!/bin/bash

# Read the passwords from the Docker secrets files
# Ensure that the variables are populated before attempting to connect to the database
DB_PASSWORD=$(cat /run/secrets/db_password)
WP_ADMIN_PASSWORD=$(cat /run/secrets/wp_admin_password)
WP_USER_PASSWORD=$(cat /run/secrets/wp_user_password)

# Since all containers start at the same time, we need to wait for the database to be ready before starting WordPress.
echo "Waiting for the connection to the database MariaDB..."
while ! mariadb -h mariadb -u${DB_USER} -p${DB_PASSWORD} -e "SELECT 1" &> /dev/null; do
    sleep 3
done
echo "Connected to the database MariaDB!"

if [ ! -f "wp-config.php" ]; then
    echo "Installing WordPress core..."
    wp core download --allow-root

    echo "Configuring connection to the database..."
    wp config create \
        --dbname=${DB_NAME} \
        --dbuser=${DB_USER} \
        --dbpass=${DB_PASSWORD} \
        --dbhost=mariadb \
        --allow-root

    echo "Installing WordPress and creating admin user..."
    wp core install \
        --url=${DOMAIN_NAME} \
        --title="Inception" \
        --admin_user=${WP_ADMIN_USER} \
        --admin_password=${WP_ADMIN_PASSWORD} \
        --admin_email=${WP_ADMIN_EMAIL} \
        --allow-root

    echo "Creating the visitor user..."
    wp user create \
        ${WP_USER} \
        ${WP_USER_EMAIL} \
        --role=author \
        --user_pass=${WP_USER_PASSWORD} \
        --allow-root

    echo "WordPress installation completed!"
else
    echo "WordPress is already installed."
fi

echo "Initing PHP-FPM..."
exec /usr/sbin/php-fpm8.2 -F