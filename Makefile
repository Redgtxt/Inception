#Variables
COMPOSE_FILE = srcs/docker-compose.yml
DATA_DIR = /home/redgtxt/data

#Names of the folders
DB_DIR = $(DATA_DIR)/mariadb
WP_DIR = $(DATA_DIR)/wordpress

all: up

#Create folders if don't existe and launch the containers to the background
up:
	@mkdir -p $(DB_DIR)
	@mkdir -p $(WP_DIR)
	docker compose -f $(COMPOSE_FILE) up -d --build

#Shutdown the containers and removes the remove the containers and the networks that they were using
down:
	docker compose -f $(COMPOSE_FILE) down

#Stop the containers without removing them
stop:
	docker compose -f $(COMPOSE_FILE) stop

#Starts the containers that were stopped
start:
	docker compose -f $(COMPOSE_FILE) start

#Deep clean for the containers, removes images,networks and volumes
clean: down
	docker system prune -af --volumes

#Execute clean and erases the folders from the machine
fclean: clean
	@sudo rm -rf $(DATA_DIR)

re: fclean all

.PHONY: all up down stop start clean fclean re