ARG NGINX_VERSION=1.27.3

FROM nginx:${NGINX_VERSION} AS builder

COPY script/db/40-apply-db-proxy.sh /docker-entrypoint.d