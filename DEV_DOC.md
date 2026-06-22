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
  