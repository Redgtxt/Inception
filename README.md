> *This project has been created as part of the 42 curriculum by hguerrei.*

# Inception

## Description

This project aims to broaden my knowledge of system administration using Docker. It consists of setting up a small infrastructure composed of three services (NGINX, WordPress, MariaDB) utilizing Docker Compose inside a virtual machine.

To fully understand the role of Docker, pulling ready-made images is avoided. Instead, each service runs in a dedicated container built from scratch using custom Dockerfiles, with the penultimate stable version of Debian serving as the base image.

---

## Instructions

### 1. Prerequisites

Before running the project, configure your local machine to resolve the custom domain. Open your terminal and edit the hosts file:

```bash
sudo nano /etc/hosts
```

Add the following line to map the domain to your local IP:

```
127.0.0.1    hguerrei.42.fr
```

You must also ensure that you have a valid `.env` file located in the `srcs/` directory containing all the necessary credentials (e.g., `DOMAIN_NAME`, database passwords, and WordPress credentials).

---

### 2. Execution & Management

This project uses a `Makefile` located at the root of the repository to easily orchestrate the Docker containers.

| Command | Description |
|---|---|
| `make` / `make up` | Builds Docker images and starts containers in the background. Also creates the necessary local directories for volumes. |
| `make down` | Stops containers and removes the network created by Docker Compose. |
| `make start` / `make stop` | Starts or stops existing containers without removing them. |
| `make clean` | Stops containers and removes all project-related Docker images, networks, and volumes. |
| `make fclean` | Deep clean: runs `make clean` and physically deletes persistent data folders from the host (`/home/hguerrei/data`). |
| `make re` | Fully resets the project by running `fclean` followed by `up`. |

---

### 3. Accessing the Services

Once the containers are running (`make up`), access the infrastructure via your web browser:

- **WordPress Website:** https://hguerrei.42.fr
- **WordPress Admin Panel:** https://hguerrei.42.fr/wp-admin

> **Note:** Since the SSL/TLS certificate is self-signed, your browser will likely display a security warning. You must accept the risk to proceed.

---

## Core Concepts & Technical Choices

### Virtual Machines vs. Docker

#### What is a Virtual Machine?

A virtual machine is a computer built out of software. It behaves like a physical computer — using RAM, storage, processors, and other hardware — but only exists as a program running on the physical machine.

Three essential components make a VM work:

- **Host:** The physical computer and its primary operating system.
- **Hypervisor:** The software that creates and manages the VM, acting as a traffic cop that borrows physical resources (RAM, disk, CPU) from the host.
- **Guest:** The operating system running inside the VM. At this level, the guest thinks it is on physical hardware.

#### Docker Architecture

Docker is a software platform that allows you to build, test, and deploy applications quickly by packaging them into standardized, isolated units called **containers**.

- **Docker Image:** The result of a `Dockerfile` — a file containing instructions on how the container should be built.
- **Docker Containers:** Docker doesn't use a Hypervisor or require a full guest OS like a VM. Instead, it uses a background program called the **Docker Engine**, which allows all containers to securely share the host's kernel. A container only holds the application and the exact files, libraries, and dependencies it needs.

#### The Comparison

| | Docker | Virtual Machine |
|---|---|---|
| **Architecture** | Shares host OS kernel via Docker Engine | Hypervisor emulates hardware; requires a full guest OS |
| **Speed** | Starts in milliseconds (no OS boot) | Boots an entire OS; can take minutes |
| **Resource Usage** | Dynamic — uses only what's needed at that moment | Static — resources are permanently allocated |

---

### The Docker Daemon

The Docker Daemon is a background process that manages Docker objects. It acts as an intermediary, listening for requests from the Docker API. The Docker Client sends commands to the Daemon to execute. It manages the lifecycle of containers (starting and stopping) and resources such as memory, networks, and storage.

---

### Data Persistence: Volumes vs. Bind Mounts

Containers are ephemeral — if you shut one down, all modified data inside it is lost. For example, without persistence, stopping the MariaDB container would delete the database.

- **Docker Volumes:** Save data permanently by bypassing the container's temporary file system and writing directly to a Docker-managed location on the host. Volumes are easier to back up, migrate, or clean.
- **Bind Mounts:** Map a specific, user-defined folder from the host machine directly into the container.

---

### Security: Environment Variables vs. Secrets

- **Environment Variables:** Dynamic values stored outside the application (usually in a `.env` file). Great for centralizing configuration, but visible to anyone with system access — making them unsafe for sensitive data.
- **Docker Secrets:** A built-in security feature for sensitive information (passwords, API keys). Docker encrypts the secret and controls access, mounting it as a temporary, read-only file in the container's memory at `/run/secrets/<secret_name>`.

---

### Networking: Docker Network vs. Host Network

- **Docker Network (Bridge):** A virtual, software-defined network created by the Docker Engine. Establishes a private environment where containers communicate securely with each other while remaining isolated from external traffic.
- **Host Network:** Removes standard network isolation entirely, allowing the container to bind directly to the host machine's network interfaces.

---

### Encryption: TLSv1.2 & TLSv1.3

TLS (Transport Layer Security) is the cryptographic protocol that provides end-to-end encryption for data sent over a network — putting the "S" (Secure) in HTTPS.

> **The Armored Truck Analogy:** Standard HTTP is like writing your password on a postcard — anyone can read it. HTTPS (using TLS) is like putting your password in a heavily armored truck with a unique padlock.

Before data is sent, the client and server perform a **handshake**: they verify identities using SSL/TLS certificates and agree on an encryption method.

- **TLSv1.2 (The Reliable Veteran):** Released in 2008. Extremely stable and widely supported, but retains support for outdated algorithms, making the handshake slower.
- **TLSv1.3 (The Modern Standard):** Released in 2018. A major overhaul that removed vulnerable algorithms ("secure by default") and streamlined the handshake to a single round-trip, improving both security and speed.

---

## Resources & Links

- [TLS Transport Layer Security Protocol](https://en.wikipedia.org/wiki/Transport_Layer_Security)
- [Docker Overview](https://docs.docker.com/get-started/overview/)
- [How does Docker Daemon work?](https://docs.docker.com/engine/reference/commandline/dockerd/)
- [Docker Network Connect](https://docs.docker.com/engine/reference/commandline/network_connect/)
- [Intro to Docker](https://www.youtube.com/watch?v=Ud7Npgi6x8E)
- [Docker in 100 seconds](https://www.youtube.com/watch?v=Gjnup-PuquQ)
- [Docker basics](https://www.youtube.com/watch?v=DQdB7wFEygo&t=491s)


AI usage:
- Discuss Architecture and structure design ideias;
- Get technical information of some concepts;

> *Disclouser: AI was used consciously and critically, acting as a supplementary learning tool to accelerate understanding, not to skip learning steps. All architectural decisions, code implementations, and debugging sessions were manually driven.*
> 
</details>