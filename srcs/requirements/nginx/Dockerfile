#vamos usar a penultima versao
FROM debian:bookworm

#Login/domain is injected at build time so it is never hardcoded (matches
#whichever user builds the image, e.g. redgtxt on the dev VM or hguerrei on
#the evaluation VM)
ARG DOMAIN_NAME

#Update the packages and install Nginx
RUN apt-get update && apt-get install -y \
    nginx \
    openssl \
    && rm -rf /var/lib/apt/lists/*

#Create the folder where we will store the SSL certificates
RUN mkdir -p /etc/nginx/ssl

#Generate self-signed SSL certificates
RUN openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/inception.key \
    -out /etc/nginx/ssl/inception.crt \
    -subj "/C=PT/ST=LX/L=Lisbon/O=42/OU=Inception/CN=${DOMAIN_NAME}"

#Create folder where nginx will store the PID file
RUN mkdir -p /var/run/nginx

#Copy the nginx configuration file to the container and replace the
#${DOMAIN_NAME} placeholder, since nginx does not expand shell-style
#environment variables in its own config files
COPY ./conf/nginx.conf /etc/nginx/nginx.conf
RUN sed -i "s/\${DOMAIN_NAME}/${DOMAIN_NAME}/" /etc/nginx/nginx.conf

#Port where the services will comunicate
EXPOSE 443

#Define the command to start nginx in the foreground
#daemon off is used to keep nginx running in the foreground, which is necessary for the container to keep running
CMD [ "nginx", "-g", "daemon off;" ]