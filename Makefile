#Variables
COMPOSE_FILE = srcs/docker-compose.yml
DATA_DIR = /home/redgtxt/data

#Names of the folders
DB_DIR = $(DATA_DIR)/mariadb
WP_DIR = $(DATA_DIR)/wordpress
ENV_FILE = srcs/.env

all: up

# Runs the setup script only if the .env file doesn't exist yet
setup:
	@if [ ! -f $(ENV_FILE) ]; then \
		bash setup.sh; \
	fi

#Create folders if don't exist and launch the containers to the background
#Added 'setup' as a dependency before running docker compose
up: setup
	@mkdir -p $(DB_DIR)
	@mkdir -p $(WP_DIR)
	docker compose -f $(COMPOSE_FILE) up -d --build

#Shutdown the containers and removes the containers and the networks that they were using
down:
	docker compose -f $(COMPOSE_FILE) down

#Stop the containers without removing them
stop:
	docker compose -f $(COMPOSE_FILE) stop

#Starts the containers that were stopped
start:
	docker compose -f $(COMPOSE_FILE) start

#Deep clean for the containers, removes images, networks and volumes
clean: down
	docker system prune -af --volumes

#Execute clean and erases the folders, .env and secrets from the machine
fclean: clean
	@sudo rm -rf $(DATA_DIR)
	@rm -rf $(ENV_FILE)
	@rm -rf secrets

re: fclean all

.PHONY: all setup up down stop start clean fclean re