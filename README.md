# Inception

![42 School](https://img.shields.io/badge/42-Lisboa-000000?style=flat-square&logo=42&logoColor=white)
![Milestone](https://img.shields.io/badge/milestone-5-informational?style=flat-square)
![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?style=flat-square&logo=docker&logoColor=white)
![Base](https://img.shields.io/badge/base%20image-debian%20bookworm-A81D33?style=flat-square&logo=debian&logoColor=white)
![TLS](https://img.shields.io/badge/TLS-1.2%20only-success?style=flat-square)

> A three-container WordPress infrastructure — NGINX, WordPress/PHP-FPM and MariaDB — with every image built from scratch on Debian. No `docker pull wordpress`.

The rule that shapes this project is what it forbids: pulling a ready-made image. Every container starts from `debian:bookworm` and is assembled by hand, which means writing the TLS certificate generation, the database bootstrap, the WordPress install and the process supervision yourself. It is the difference between *using* Docker and understanding what an image actually is.

The whole stack comes up with one command, from a clean machine, with no passwords committed anywhere.

📁 **The project lives in [`inception/`](./inception)** — that is where you `cd` before running anything.

---

## Table of contents

- [Architecture](#architecture)
- [Quick start](#quick-start)
- [Make targets](#make-targets)
- [The three containers](#the-three-containers)
- [Design notes](#design-notes)
- [Documentation](#documentation)
- [What I took away from it](#what-i-took-away-from-it)

---

## Architecture

```
                        host machine
                             │
                   https://<login>.42.fr:443
                             │
        ┌────────────────────▼────────────────────┐
        │  network: inception  (bridge)           │
        │                                         │
        │  ┌───────────┐  fastcgi   ┌───────────┐ │
        │  │   nginx   │───────────►│ wordpress │ │
        │  │  TLS 1.2  │   :9000    │  php-fpm  │ │
        │  │  :443     │            │  wp-cli   │ │
        │  └─────┬─────┘            └─────┬─────┘ │
        │        │                        │       │
        │        │  shared volume         │ :3306 │
        │        │  /var/www/html         │       │
        │        │                  ┌─────▼─────┐ │
        │        │                  │  mariadb  │ │
        │        │                  └─────┬─────┘ │
        └────────┼────────────────────────┼───────┘
                 │                        │
        ┌────────▼────────┐      ┌────────▼────────┐
        │ ~/data/wordpress│      │ ~/data/mariadb  │
        └─────────────────┘      └─────────────────┘
                  bind-mounted named volumes
```

Only NGINX publishes a port. WordPress and MariaDB are reachable **only** from inside the `inception` bridge network — there is no route to them from the host, which is the isolation the project is really about.

NGINX and WordPress share the `/var/www/html` volume: PHP-FPM writes the site, NGINX serves the static files from it directly and forwards only `.php` requests over FastCGI.

## Quick start

Map the domain to localhost first:

```bash
echo "127.0.0.1 $(whoami).42.fr" | sudo tee -a /etc/hosts
```

Then:

```bash
cd inception
make
```

That single command generates `srcs/.env` and the Docker secrets on first run, creates the host directories the volumes bind to, builds the three images and starts the stack. Then open **https://\<your-login\>.42.fr** — the certificate is self-signed, so the browser will warn once.

## Make targets

| Target | What it does |
| --- | --- |
| `make` / `make up` | Generates config on first run, creates volume directories, builds and starts everything detached |
| `make down` | Stops the containers and removes them and the network |
| `make stop` / `make start` | Pauses and resumes without removing anything |
| `make db` | Opens an interactive MariaDB shell inside the container as `root` |
| `make clean` | Removes this project's containers, images and volumes |
| `make fclean` | `clean`, plus deletes the host data directories, `.env` and `secrets/` |
| `make re` | `fclean` then `up` — a genuinely clean rebuild |

`clean` is scoped to the project on purpose: `docker system prune` would take unrelated images and volumes on the host with it.

## The three containers

### NGINX — the only door

TLS 1.2 only, on a self-signed certificate generated at build time, with the subject taken from the domain passed in as a build argument. The config file is copied in and its placeholders substituted with `sed`:

```dockerfile
RUN sed -i "s/\${DOMAIN_NAME}/${DOMAIN_NAME}/" /etc/nginx/nginx.conf && \
    sed -i "s/\${NGINX_PORT}/${NGINX_PORT}/g" /etc/nginx/nginx.conf
```

NGINX does not expand shell-style variables inside its own configuration, so substitution has to happen before it ever reads the file. Doing it at build time rather than at startup keeps the entrypoint trivial: `nginx -g "daemon off;"`, running in the foreground because a container lives exactly as long as its PID 1.

### MariaDB — bootstrapped once, then just a database

The entrypoint script is **idempotent**. It checks whether the database directory already exists and skips the whole setup if it does, so a restart is a restart and not a re-initialisation:

```bash
if [ -d "/var/lib/mysql/$DB_NAME" ]; then
    echo "Database already exists. Starting normally..."
else
    # start temporarily, create database + user, set root password, shut down
fi

exec mariadbd --user=mysql
```

That final `exec` matters more than it looks. It replaces the script with the database process, so `mariadbd` *becomes* PID 1 and receives `docker stop`'s `SIGTERM` directly. The usual `mysqld_safe` wrapper does not forward signals properly, which is how you end up with a container that takes ten seconds to stop and a database that was never shut down cleanly.

### WordPress — PHP-FPM, installed by script

No web server here at all: just PHP-FPM listening on a TCP port for NGINX, plus `wp-cli` to do the install. Since Compose starts all three containers at once, `depends_on` only guarantees start order, not readiness — so the script waits for the database to actually answer:

```bash
while ! mariadb -h mariadb -P${DB_PORT} -u${DB_USER} -p${DB_PASSWORD} -e "SELECT 1" &> /dev/null; do
    sleep 3
done
```

Then, guarded by the presence of `wp-config.php` so it only runs once: download core, write the config, install the site, create an admin and a second author user. And `exec php-fpm8.2 -F` to finish, for the same PID 1 reason as MariaDB.

## Design notes

- **Secrets are never environment variables.** Passwords are generated by `setup.sh` with `openssl rand -base64 12`, written into `secrets/`, and mounted by Docker as read-only files at `/run/secrets/`. The containers `cat` them at startup. `.env` holds only the harmless half — database and user *names*, ports, the domain — and both `secrets/` and `srcs/.env` are gitignored. Nothing sensitive is ever in an image layer, in `docker inspect`, or in this repository.

- **Everything is generated per machine.** `setup.sh` takes the login from `whoami`, so the domain, the home path and the volume locations are correct on whatever machine clones the repo. There is no hardcoded `hguerrei` anywhere in the build.

- **Ports are build arguments, not constants.** `DB_PORT`, `WP_PORT` and `NGINX_PORT` come from `.env`, are passed as `ARG` into each Dockerfile, and get baked into the MariaDB config, the PHP-FPM pool and the NGINX server block. Changing a port is one line in `.env` plus a rebuild, with no file to hunt through.

- **Named volumes with bind options**, rather than plain bind mounts — so the data lands in a known place on the host (`~/data/mariadb`, `~/data/wordpress`) while still being a Docker-managed volume that `docker volume` commands understand.

- **`restart: always` on all three**, so the stack survives a host reboot without intervention.

- **Idempotent entrypoints everywhere.** Both init scripts check whether their work is already done. The test that matters is not "does `make up` work" but "does `make up` twice in a row still work" — and it does.

## Documentation

The project directory carries its own docs:

| File | For |
| --- | --- |
| [`inception/README.md`](./inception/README.md) | Full setup instructions, plus the concepts behind the project — VMs vs containers, the Docker daemon, volumes vs bind mounts, env vars vs secrets, bridge vs host networking, TLS |
| [`inception/USER_DOC.md`](./inception/USER_DOC.md) | Running and operating the stack |
| [`inception/DEV_DOC.md`](./inception/DEV_DOC.md) | Internals, file by file |

## What I took away from it

- What an image actually is: a stack of filesystem layers plus a command, and nothing more. Writing the Dockerfiles by hand is what turns `FROM` from magic into a filesystem you are responsible for.
- Why PID 1 matters in a container, and that `exec` in an entrypoint script is the difference between a process that receives `SIGTERM` and one that gets killed after a timeout.
- That `depends_on` orders *starts*, not *readiness* — every real distributed system needs its own wait-for-it loop, because "the container is running" and "the service is answering" are different facts.
- The practical difference between configuration and secrets, and that the line between them is drawn by what happens if the file leaks.
- That the real test of an init script is running it twice.

---

**Author** — Hugo Pinto ([`hguerrei`](https://profile.intra.42.fr/users/hguerrei) · [@Redgtxt](https://github.com/Redgtxt))
