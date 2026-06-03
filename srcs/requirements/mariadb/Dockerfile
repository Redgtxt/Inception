#vamos usar a penultima versao
FROM debian:bookworm

#Update the packages and install MariaDb server
#rm -rf will clean the cache from apt
RUN apt-get update && apt-get install -y mariadb-server && \
    rm -rf /var/lib/apt/lists/*

#config Mariadb to accept connections from every ip(0.0.0.0) instead of the localhost
RUN sed -i 's/bind-address\s*=\s*127.0.0.1/bind-address = 0.0.0.0/' /etc/mysql/mariadb.conf.d/50-server.cnf

#Creates the execution folder MySQL and give perms
RUN mkdir -p /var/run/mysqld && \
    chown -R mysql:mysql /var/run/mysqld && \
    chmod 777 /var/run/mysqld

#copys the script to the container
COPY ./tools/init-db.sh /usr/local/bin/

#perms to the script
RUN chmod +x /usr/local/bin/init-db.sh

#Port where the services will comunicate
EXPOSE 3306

#Define the scipt has the main comando when the container starts
ENTRYPOINT [ "/usr/local/bin/init-db.sh" ]