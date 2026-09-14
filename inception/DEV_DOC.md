> *This project has been created as part of the 42 curriculum by hguerrei.*

# Developer Documentation - Inception

## Overview
This document provides technical details regarding the architecture, configuration, and deployment of the Inception infrastructure. It is designed for developers, maintainers, and evaluators who need to understand the internal workings of the Docker containers, networking, and data persistence strategies implemented in this project.

---

## 1. Architecture & Network Design

The infrastructure is built using Docker Compose and consists of three isolated services communicating over a custom Docker bridge network. 

### Container Flow
1. **NGINX (Entrypoint):** Acts as the reverse proxy. It listens exclusively on port `NGINX_PORT` (HTTPS, defaults to 443) and handles all incoming web traffic.
2. **WordPress (Application):** Runs PHP-FPM. It does not expose any ports to the host machine. It receives FastCGI requests from NGINX on port `WP_PORT` (defaults to 9000).
3. **MariaDB (Database):** Stores all WordPress site data and user credentials. It is isolated from the host and NGINX, communicating only with the WordPress container on port `DB_PORT` (defaults to 3306).

All three ports are defined once in `srcs/.env` and propagated from there — see [§3 Port Configuration](#3-port-configuration).

### Networking Mode: Docker Bridge vs. Host
The project utilizes a custom **Docker Bridge Network** (typically named `inception`). 
* **Why Bridge?** It establishes a secure, private DNS resolution layer where containers can discover each other by their service names (e.g., `fastcgi_pass wordpress:${WP_PORT};`). It ensures strict isolation; the host machine cannot directly query the database, nor can external actors.
* **Why not Host?** Host networking bypasses Docker's isolation, mapping container ports directly to the host's interfaces. This violates the project's security constraints, which dictate that only NGINX should be accessible from the outside.

---

## 2. Service Configurations

Each service is built from the penultimate stable version of Debian using a custom `Dockerfile`. No pre-configured images (like `nginx:latest` or `wordpress:fpm`) are used.

### NGINX (`/srcs/requirements/nginx`)
* **TLS Encryption:** Configured to strictly accept **TLSv1.2 and TLSv1.3**. SSL certificates are self-signed and generated during the image build process using OpenSSL.
* **Configuration:** The `nginx.conf` is copied into the image. It routes PHP requests to the WordPress container using `try_files` and `fastcgi_pass wordpress:${WP_PORT}`.
* **Port placeholders:** `nginx.conf` contains `${NGINX_PORT}` and `${WP_PORT}` placeholders (in the `listen` and `fastcgi_pass` directives). Since NGINX doesn't expand shell variables in its own config, the Dockerfile receives both as build `ARG`s (passed from `docker-compose.yml`, sourced from `srcs/.env`) and `sed`s them into the file at build time — the same mechanism already used for `DOMAIN_NAME`.
* **Permissions:** Runs worker processes as the `www-data` user to safely serve files from `/var/www/html`.

### WordPress (`/srcs/requirements/wordpress`)
* **Core Technologies:** Installs `php-fpm` and `php-mysql`.
* **`WORKDIR /var/www/html`:** The Dockerfile sets this explicitly. Without it, `wp core download`/`wp core install` (run by `init-wp.sh`) write to the container's default working directory (`/`) instead of the volume shared with NGINX, which silently produces a `403 Forbidden` (empty directory, no `index.php`) once the bind-mounted host folder is actually empty (a stale/pre-populated folder can mask this).
* **PHP-FPM port:** `listen = ${WP_PORT}` in `/etc/php/8.2/fpm/pool.d/www.conf` is set via `sed` at build time, using the `WP_PORT` build `ARG`.
* **Initialization (`init-wp.sh`):** Uses WP-CLI to automate the setup process. Upon container startup, the script:
  1. Waits for the MariaDB database to be ready, connecting on `${DB_PORT}` (runtime env var from `srcs/.env`).
  2. Downloads the WordPress core files.
  3. Generates the `wp-config.php` file dynamically, with `--dbhost=mariadb:${DB_PORT}`.
  4. Computes `SITE_URL` (`https://${DOMAIN_NAME}`, or `https://${DOMAIN_NAME}:${NGINX_PORT}` when `NGINX_PORT` isn't 443) and installs WordPress with `--url=${SITE_URL}`, so the `siteurl`/`home` options WordPress stores in the DB already match the port NGINX is actually listening on. **This only runs on first install** (guarded by `[ ! -f wp-config.php ]`) — if you change `NGINX_PORT` against an already-provisioned volume, WordPress will keep redirecting to the old URL (dropping the port) until you fix it manually: `docker exec wordpress wp option update siteurl "https://<domain>:<port>" --allow-root` (and the same for `home`).
  5. Starts the PHP-FPM daemon in the foreground.

### MariaDB (`/srcs/requirements/mariadb`)
* **Daemon:** Uses `mariadbd` (not `mysqld_safe` for backgrounding, to keep the container alive).
* **Port:** The Dockerfile writes `/etc/mysql/mariadb.conf.d/60-port.cnf` (`[mysqld]\nport = ${DB_PORT}`) at build time from the `DB_PORT` build `ARG`. It's a separate file (loaded after `50-server.cnf`) rather than a `sed` on the existing config, since `50-server.cnf` has no pre-existing `port =` line to target reliably.
* **Setup:** A shell script intercepts the startup process to create the database, assign root privileges, and create the WordPress user using SQL commands passed during runtime.

---

## 3. Port Configuration

`DB_PORT`, `WP_PORT` and `NGINX_PORT` in `srcs/.env` (default `3306`/`9000`/`443`) are the single source of truth for the ports each service uses. Nothing is hardcoded elsewhere; changing a value and running `make re` (or `docker compose up -d --build`) is enough. Two different mechanisms carry the value into each service, depending on when it's needed:

* **Build-time (`ARG`), for anything baked into a config file at image-build time:**
  * `mariadb` — `DB_PORT` → `/etc/mysql/mariadb.conf.d/60-port.cnf`.
  * `wordpress` — `WP_PORT` → PHP-FPM's `listen` directive.
  * `nginx` — `NGINX_PORT` and `WP_PORT` → the `listen` and `fastcgi_pass` lines in `nginx.conf` (NGINX only serves SSL, so `NGINX_PORT` also drives the host port mapping in `docker-compose.yml`: `ports: ["${NGINX_PORT}:${NGINX_PORT}"]`).
* **Runtime (`env_file: .env`), for anything read by a script when the container starts:**
  * `wordpress` — `init-wp.sh` uses `DB_PORT` to connect to MariaDB, and `NGINX_PORT` to build the `SITE_URL` passed to `wp core install` (see [§2 WordPress](#2-service-configurations)).

**Caveat:** the `SITE_URL`/`wp core install` step only runs once, on first install. Changing `NGINX_PORT` on a volume that already has WordPress installed does **not** update the stored `siteurl`/`home` — you have to fix those manually (see previous section) or wipe the volume with `make re`.

---

## 4. Data Persistence & Volumes

To prevent data loss when containers are stopped or removed, the project implements **Docker Volumes** bound to specific directories on the host machine.

* **WordPress Volume:** Mounted at `/var/www/html` in the container and physically stored at `/home/hguerrei/data/wordpress` on the host. This ensures themes, plugins, and uploaded media are retained.
* **Database Volume:** Mounted at `/var/lib/mysql` in the container and physically stored at `/home/hguerrei/data/mariadb`. This preserves all SQL tables and user data.

---

## 5. Security Implementation

### Docker Secrets vs. Environment Variables
The project strictly separates standard configuration from sensitive credentials.

* **`.env` File:** Used for standard environment variables like `DOMAIN_NAME` and basic configuration toggles.
* **Docker Secrets:** For highly sensitive data (like database root passwords). Docker Secrets mount credentials into the container's temporary memory (`/run/secrets/`), ensuring they are never exposed in system-wide environment variables or image layers.

### Port Exposure
The `docker-compose.yml` file explicitly defines `ports` only for the NGINX service:
```yaml
ports:
  - "${NGINX_PORT}:${NGINX_PORT}"
```
WordPress (`WP_PORT`) and MariaDB (`DB_PORT`) are only reachable from other containers on the `inception` Docker network — they are never published to the host, regardless of what those ports are set to (see [§3 Port Configuration](#3-port-configuration)).

---

## 6. Setting Up the Environment From Scratch

1. **Prerequisites:** Docker Engine and the Docker Compose plugin installed on the VM, and a user with permission to run `docker`.
2. **Configuration files:** Nothing needs to be created by hand. Running `make` (see below) triggers `setup.sh`, which:
   * Generates `srcs/.env` with non-sensitive configuration (`DOMAIN_NAME`, `HOME_DIR`, database/user names, and the `DB_PORT`/`WP_PORT`/`NGINX_PORT` ports — see [§3 Port Configuration](#3-port-configuration)). The login used for `DOMAIN_NAME`/`HOME_DIR` is taken automatically from `whoami`, so the same scripts work unmodified on any machine/user.
   * Creates the `secrets/` folder at the repository root and generates random passwords with `openssl rand -base64 12` into `db_password.txt`, `db_root_password.txt`, `wp_admin_password.txt`, `wp_user_password.txt`.
3. Both `srcs/.env` and `secrets/` are listed in `.gitignore` and must never be committed.
4. If you need to regenerate credentials, delete `srcs/.env` and re-run `make` (or run `bash setup.sh` directly) — the setup step is skipped automatically once `srcs/.env` already exists.

---

## 7. Build, Launch and Manage the Project

All operations go through the root `Makefile`, which wraps Docker Compose (`srcs/docker-compose.yml`):

| Command | What it does |
|---|---|
| `make` / `make up` | Runs `setup.sh` if needed, creates the host data directories, then `docker compose up -d --build` (builds all three images and starts the containers). |
| `make down` | `docker compose down` — stops and removes the containers and the `inception` network. |
| `make stop` / `make start` | `docker compose stop` / `start` — pause/resume containers without removing them. |
| `make db` | `docker exec -it mariadb mariadb -u root -p...` — opens an interactive MySQL shell inside the `mariadb` container, logged in as `root` (password read from `secrets/db_root_password.txt`), pre-selecting the `DB_NAME` database from `srcs/.env`. |
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

## 8. Data Location & Persistence Recap

Both named volumes (`mariadb`, `wordpress`) use the `local` driver with `o: bind` pointed at `${HOME_DIR}/data/...`, where `HOME_DIR` comes from `srcs/.env` (`/home/<login>`). This satisfies two constraints at once: Docker sees them as regular named volumes (`docker volume ls`), while the data is physically stored at `/home/<login>/data/mariadb` and `/home/<login>/data/wordpress` on the host, as required by the subject. Removing the containers (`make down`) does not touch this data; only `make fclean` deletes it explicitly.