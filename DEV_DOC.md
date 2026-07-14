> *This project has been created as part of the 42 curriculum by hguerrei.*

# Developer Documentation - Inception

## Overview
This document provides technical details regarding the architecture, configuration, and deployment of the Inception infrastructure. It is designed for developers, maintainers, and evaluators who need to understand the internal workings of the Docker containers, networking, and data persistence strategies implemented in this project.

---

## 1. Architecture & Network Design

The infrastructure is built using Docker Compose and consists of three isolated services communicating over a custom Docker bridge network. 

### Container Flow
1. **NGINX (Entrypoint):** Acts as the reverse proxy. It listens exclusively on port 443 (HTTPS) and handles all incoming web traffic.
2. **WordPress (Application):** Runs PHP-FPM. It does not expose any ports to the host machine. It receives FastCGI requests from NGINX on port 9000.
3. **MariaDB (Database):** Stores all WordPress site data and user credentials. It is isolated from the host and NGINX, communicating only with the WordPress container on port 3306.

### Networking Mode: Docker Bridge vs. Host
The project utilizes a custom **Docker Bridge Network** (typically named `inception`). 
* **Why Bridge?** It establishes a secure, private DNS resolution layer where containers can discover each other by their service names (e.g., `fastcgi_pass wordpress:9000;`). It ensures strict isolation; the host machine cannot directly query the database, nor can external actors.
* **Why not Host?** Host networking bypasses Docker's isolation, mapping container ports directly to the host's interfaces. This violates the project's security constraints, which dictate that only NGINX should be accessible from the outside.

---

## 2. Service Configurations

Each service is built from the penultimate stable version of Debian using a custom `Dockerfile`. No pre-configured images (like `nginx:latest` or `wordpress:fpm`) are used.

### NGINX (`/srcs/requirements/nginx`)
* **TLS Encryption:** Configured to strictly accept **TLSv1.2 and TLSv1.3**. SSL certificates are self-signed and generated during the image build process using OpenSSL.
* **Configuration:** The `nginx.conf` is copied into the image. It routes PHP requests to the WordPress container using `try_files` and `fastcgi_pass wordpress:9000`. 
* **Permissions:** Runs worker processes as the `www-data` user to safely serve files from `/var/www/html`.

### WordPress (`/srcs/requirements/wordpress`)
* **Core Technologies:** Installs `php-fpm` and `php-mysql`. 
* **Initialization (`init-wp.sh`):** Uses WP-CLI to automate the setup process. Upon container startup, the script:
  1. Waits for the MariaDB database to be ready.
  2. Downloads the WordPress core files.
  3. Generates the `wp-config.php` file dynamically.
  4. Installs WordPress and creates the Administrator and standard user.
  5. Adjusts file ownership (`chown -R www-data:www-data /var/www/html`) to prevent `403 Forbidden` errors in NGINX.
  6. Starts the PHP-FPM daemon in the foreground.

### MariaDB (`/srcs/requirements/mariadb`)
* **Daemon:** Uses `mariadbd` (not `mysqld_safe` for backgrounding, to keep the container alive).
* **Setup:** A shell script intercepts the startup process to create the database, assign root privileges, and create the WordPress user using SQL commands passed during runtime.

---

## 3. Data Persistence & Volumes

To prevent data loss when containers are stopped or removed, the project implements **Docker Volumes** bound to specific directories on the host machine.

* **WordPress Volume:** Mounted at `/var/www/html` in the container and physically stored at `/home/hguerrei/data/wordpress` on the host. This ensures themes, plugins, and uploaded media are retained.
* **Database Volume:** Mounted at `/var/lib/mysql` in the container and physically stored at `/home/hguerrei/data/mariadb`. This preserves all SQL tables and user data.

---

## 4. Security Implementation

### Docker Secrets vs. Environment Variables
The project strictly separates standard configuration from sensitive credentials.

* **`.env` File:** Used for standard environment variables like `DOMAIN_NAME` and basic configuration toggles.
* **Docker Secrets:** For highly sensitive data (like database root passwords). Docker Secrets mount credentials into the container's temporary memory (`/run/secrets/`), ensuring they are never exposed in system-wide environment variables or image layers.

### Port Exposure
The `docker-compose.yml` file explicitly defines `ports` only for the NGINX service:
```yaml
ports:
  - "443:443"
```
WordPress (9000) and MariaDB (3306) are only reachable from other containers on the `inception` Docker network — they are never published to the host.

---

## 5. Setting Up the Environment From Scratch

1. **Prerequisites:** Docker Engine and the Docker Compose plugin installed on the VM, and a user with permission to run `docker`.
2. **Configuration files:** Nothing needs to be created by hand. Running `make` (see below) triggers `setup.sh`, which:
   * Generates `srcs/.env` with non-sensitive configuration (`DOMAIN_NAME`, `HOME_DIR`, database/user names). The login used for `DOMAIN_NAME`/`HOME_DIR` is taken automatically from `whoami`, so the same scripts work unmodified on any machine/user.
   * Creates the `secrets/` folder at the repository root and generates random passwords with `openssl rand -base64 12` into `db_password.txt`, `db_root_password.txt`, `wp_admin_password.txt`, `wp_user_password.txt`.
3. Both `srcs/.env` and `secrets/` are listed in `.gitignore` and must never be committed.
4. If you need to regenerate credentials, delete `srcs/.env` and re-run `make` (or run `bash setup.sh` directly) — the setup step is skipped automatically once `srcs/.env` already exists.

---

## 6. Build, Launch and Manage the Project

All operations go through the root `Makefile`, which wraps Docker Compose (`srcs/docker-compose.yml`):

| Command | What it does |
|---|---|
| `make` / `make up` | Runs `setup.sh` if needed, creates the host data directories, then `docker compose up -d --build` (builds all three images and starts the containers). |
| `make down` | `docker compose down` — stops and removes the containers and the `inception` network. |
| `make stop` / `make start` | `docker compose stop` / `start` — pause/resume containers without removing them. |
| `make clean` | `docker compose down --rmi all --volumes` — removes this project's containers, images, and volumes (scoped to Inception, does not touch unrelated Docker resources on the host). |
| `make fclean` | Runs `clean`, then deletes `/home/<login>/data` on the host plus `srcs/.env` and `secrets/`. |
| `make re` | `fclean` followed by `up` — full reset. |

Useful low-level commands while developing:

```bash
docker compose -f srcs/docker-compose.yml logs -f <service>   # follow logs of one service
docker compose -f srcs/docker-compose.yml exec <service> sh   # shell into a running container
docker volume ls                                              # list volumes (mariadb, wordpress)
docker volume inspect wordpress                                # confirm the host path it is bound to
```

---

## 7. Data Location & Persistence Recap

Both named volumes (`mariadb`, `wordpress`) use the `local` driver with `o: bind` pointed at `${HOME_DIR}/data/...`, where `HOME_DIR` comes from `srcs/.env` (`/home/<login>`). This satisfies two constraints at once: Docker sees them as regular named volumes (`docker volume ls`), while the data is physically stored at `/home/<login>/data/mariadb` and `/home/<login>/data/wordpress` on the host, as required by the subject. Removing the containers (`make down`) does not touch this data; only `make fclean` deletes it explicitly.