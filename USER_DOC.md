> *This project has been created as part of the 42 curriculum by hguerrei.*

# User Documentation — Inception

## Overview

Welcome to the Inception infrastructure. This document is intended for end-users and evaluators who need to interact with the deployed services. It outlines how to access the website, manage content via WordPress, and verify the basic operational status of the containers.

### Services Provided

| Service | Role |
|---|---|
| **NGINX** | Single entrypoint of the stack. Serves the site over HTTPS (port 443) and forwards PHP requests to WordPress. |
| **WordPress + php-fpm** | The content management system that powers the website and its admin panel. |
| **MariaDB** | Database that stores all WordPress content, settings, and user accounts. |

---

## 1. Accessing the Website

The primary interface for this infrastructure is a standard web browser. The entire site is served securely via NGINX over HTTPS.

1. Open your preferred web browser.
2. Navigate to the following URL:

```
https://hguerrei.42.fr
```

> **Note on Security Warnings:** Because this infrastructure uses a self-signed SSL/TLS certificate (as required by the project constraints rather than a paid, globally recognized authority), your browser will flag the connection as "Not Secure" or display an `ERR_CERT_AUTHORITY_INVALID` warning.
>
> To proceed: click **Advanced** and select **Proceed to hguerrei.42.fr (unsafe)**. This is expected behavior and confirms that TLSv1.2/1.3 encryption is active.

> **Note on custom ports:** NGINX's port is controlled by `NGINX_PORT` in `srcs/.env` (default `443`). If it's set to anything else, you must type the port **and** the `https://` scheme explicitly in the address bar (e.g. `https://hguerrei.42.fr:8443`) — on non-standard ports, browsers default to plain HTTP, which NGINX rejects with `400 Bad Request` since it only serves SSL.

---

## 2. Managing Content (WordPress Admin)

To add posts, change themes, or manage users, you must access the WordPress administrative dashboard.

Navigate to the admin login page:

```
https://hguerrei.42.fr/wp-admin
```

You will be greeted by the standard WordPress login screen. Enter the administrator credentials generated during the initial setup.

> **Locating credentials:** Usernames (e.g. the admin login) live in `srcs/.env`. Passwords are **not** stored there — they live as Docker secrets in the `secrets/` folder at the root of the repository (`wp_admin_password.txt`, `wp_user_password.txt`, `db_password.txt`, `db_root_password.txt`), generated once by `setup.sh`. This folder is git-ignored and should never be committed.

Once logged in, you will have full control over the site's content and configuration.

### User Roles

The system is configured with two default users during automated setup:

| Role | Privileges |
|---|---|
| **Administrator** | Full privileges — modify the site, change settings, manage users. |
| **Standard User** (Visitor/Author) | Restricted privileges — primarily for reading or contributing content without access to core settings. |

---

## 3. Managing the Infrastructure

If you need to start, stop, or reset the infrastructure, use the provided `Makefile` in the root directory. Open a terminal, navigate to the `Inception` folder, and run any of the following commands:

| Command | Action |
|---|---|
| `make up` | Starts all services (NGINX, WordPress, MariaDB) in the background. |
| `make down` | Safely stops all services and removes the internal network. |
| `make stop` | Pauses the running containers without removing them. |
| `make start` | Resumes stopped containers. |
| `make db` | Opens a MySQL shell inside the `mariadb` container, already logged in as `root` (shortcut for the manual steps in the next section). |
| `make clean` | Stops and removes containers, images, and the internal Docker network. |

---

## 4. Interacting with MariaDB

You can connect directly to the MariaDB container to inspect or query the database. The quickest way is `make db`, which opens a shell already logged in as `root`. Alternatively, do it manually: first, open a shell inside the container:

```bash
docker exec -it mariadb mariadb -u <user> -p
```

You will be prompted for the password defined in your `.env` file. Once connected, you will see the MariaDB prompt:

```
MariaDB [(none)]>
```

### Basic Commands

**List all databases:**

```sql
SHOW DATABASES;
```

**Select a database to use:**

```sql
USE <database>;
```

After running this, the prompt changes to `MariaDB [<database>]>`, confirming the active database.

**List all tables in the current database:**

```sql
SHOW TABLES;
```

**Query all rows from a table:**

```sql
SELECT * FROM <table>;
```

**Query a specific column from a table:**

```sql
SELECT <column> FROM <table>;
```

### Example — Inspecting the WordPress Database

```sql
USE wordpress;
SHOW TABLES;
SELECT * FROM wp_users;
```

>  All SQL statements must end with a semicolon (`;`). To exit the MariaDB prompt, type `exit` or press `Ctrl+D`.

---

## 5. Troubleshooting & Verification

If the site is not loading, verify the following:

### Domain Resolution

Ensure your host machine knows where to find `hguerrei.42.fr`:

```bash
ping hguerrei.42.fr
```

This should return replies from `127.0.0.1`. If it doesn't, ensure your `/etc/hosts` file is configured correctly.

### Container Status

Check if all three containers are currently running:

```bash
docker ps
```

You should see `nginx`, `wordpress`, and `mariadb` listed with an `Up` status.

### Checking Logs

If a specific service is failing (e.g., a `502 Bad Gateway` error), inspect the real-time logs of the relevant container:

```bash
docker logs nginx
# or
docker logs wordpress
# or
docker logs mariadb
```

### Page Keeps Redirecting to the Wrong Port / "Unable to Connect"

If you changed `NGINX_PORT` in `srcs/.env` on an infrastructure that was already running (without a full `make re`), the browser may end up "unable to connect" after being redirected to a URL without the port. This happens because WordPress stores its own site URL in the database at install time, and that only gets refreshed on a fresh install. Fix it without losing data:

```bash
docker exec wordpress wp option update siteurl "https://hguerrei.42.fr:<port>" --allow-root
docker exec wordpress wp option update home "https://hguerrei.42.fr:<port>" --allow-root
```