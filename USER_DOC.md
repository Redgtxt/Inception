> *This project has been created as part of the 42 curriculum by hguerrei.*

# User Documentation — Inception

## Overview

Welcome to the Inception infrastructure. This document is intended for end-users and evaluators who need to interact with the deployed services. It outlines how to access the website, manage content via WordPress, and verify the basic operational status of the containers.

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

---

## 2. Managing Content (WordPress Admin)

To add posts, change themes, or manage users, you must access the WordPress administrative dashboard.

Navigate to the admin login page:

```
https://hguerrei.42.fr/wp-admin
```

You will be greeted by the standard WordPress login screen. Enter the administrator credentials defined in the `.env` file during the initial setup. Once logged in, you will have full control over the site's content and configuration.

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
| `make clean` | Stops and removes containers, images, and the internal Docker network. |

---

## 4. Interacting with MariaDB

You can connect directly to the MariaDB container to inspect or query the database. First, open a shell inside the container:

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