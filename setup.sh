#!/bin/bash

# Colors

GREEN='\033[0;32m'

YELLOW='\033[1;33m'

NC='\033[0m' # No Color

echo -e "${GREEN}Initing Enviromental Variables Config and Docker Secrets...${NC}"

# ==========================================

#  Generating .env

# ==========================================

echo -e "${YELLOW}>Generating env file srcs/.env...${NC}"

cat << EOF > srcs/.env

# ==========================================

# Global Configuration

# ==========================================

DOMAIN_NAME=hguerrei.42.fr
HOME_DIR=/home/redgtxt


# ==========================================

# Configuration of MariaDB (Only names, passwords in secrets)

# ==========================================

DB_NAME=wordpress_db

DB_USER=wp_user_normal

# ==========================================

# Configuration of WordPress

# ==========================================

WP_ADMIN_USER=Emperor

WP_ADMIN_EMAIL=Emperor@42lisboa.com

WP_USER=visitor

WP_USER_EMAIL=visitor@42lisboa.com

EOF

# ==========================================

#  Creating Docker Secrets

# ==========================================

echo -e "${YELLOW}Creating secrets folder and generating passwords...${NC}"

mkdir -p secrets

#Openssl generates random strong passwords with 12 caracters

openssl rand -base64 12 > secrets/db_password.txt

openssl rand -base64 12 > secrets/db_root_password.txt

openssl rand -base64 12 > secrets/wp_admin_password.txt

openssl rand -base64 12 > secrets/wp_user_password.txt

echo "Passwords were created successfully." > secrets/credentials.txt

echo -e "${GREEN}Done!Initial Setup is done .${NC}"
