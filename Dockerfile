ARG NGINX_VERSION=1.27.2

FROM nginx:${NGINX_VERSION} AS builder

RUN apt-get update && \
    apt install -y --no-install-recommends \
        build-essential git libbrotli-dev libpcre3 libpcre3-dev \
        libssl-dev openssl tar unzip uuid-dev wget xz-utils \
        zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/build-stage

RUN wget https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz \
    && tar zxf nginx-${NGINX_VERSION}.tar.gz

RUN git clone --recurse-submodules -j$(nproc) https://github.com/google/ngx_brotli.git \
    && cd ngx_brotli \
    && git reset --hard a71f9312c2deb28875acc7bacfdd5695a111aa53 \
    && cd /opt/build-stage

RUN git clone --recurse-submodules -j$(nproc) https://github.com/nginx-modules/ngx_immutable.git \
    && cd ngx_immutable \
    && git reset --hard dab3852a2c8f6782791664b92403dd032e77c1cb \
    && cd /opt/build-stage

RUN git clone --recurse-submodules -j$(nproc) https://github.com/nginx-modules/ngx_cache_purge.git \
    && cd ngx_cache_purge \
    && git reset --hard a84b0f3f082025dec737a537a9a443bdd6d6af9d \
    && cd /opt/build-stage

RUN case "$(uname -m)" in \
    "x86_64") \
        wget https://github.com/netvpc/psol/releases/download/psol-1.15.0.0/psol-1.15.0.0-x86_64-glib-2.36.tar.gz \
        && git clone --depth=1 https://github.com/apache/incubator-pagespeed-ngx.git \
        && tar zxf psol-1.15.0.0-x86_64-glib-2.36.tar.gz \
        && mv psol incubator-pagespeed-ngx/; \
        ;; \
    "aarch64") \
        wget https://github.com/netvpc/psol/releases/download/psol-1.15.0.0/psol-1.15.0.0-aarch64-glib-2.36.tar.gz \
        && git clone --depth=1 https://github.com/apache/incubator-pagespeed-ngx.git \
        && tar zxf psol-1.15.0.0-aarch64-glib-2.36.tar.gz \
        && mv psol incubator-pagespeed-ngx/ \
        && sed -i 's/x86_64/aarch64/' incubator-pagespeed-ngx/config \
        && sed -i 's/x64/aarch64/' incubator-pagespeed-ngx/config \
        && sed -i 's/-luuid/-l:libuuid.so.1/' incubator-pagespeed-ngx/config; \
        ;; \
    "armv7l") \
        wget https://github.com/netvpc/psol/releases/download/psol-1.15.0.0/psol-1.15.0.0-armv7l-glib-2.36.tar.gz \
        && git clone --depth=1 https://github.com/apache/incubator-pagespeed-ngx.git \
        && tar zxf psol-1.15.0.0-armv7l-glib-2.36.tar.gz \
        && mv psol incubator-pagespeed-ngx/ \
        && sed -i 's/x86_64/armv7l/' incubator-pagespeed-ngx/config \
        && sed -i 's/x64/armv7l/' incubator-pagespeed-ngx/config \
        && sed -i 's/-luuid/-l:libuuid.so.1/' incubator-pagespeed-ngx/config; \
        ;; \ 
    *) \
        echo "Unsupported architecture $(uname -m)"; exit 1; \
        ;; \
    esac

WORKDIR /opt/build-stage/nginx-${NGINX_VERSION}

RUN ./configure --with-compat \
    --add-dynamic-module=../ngx_brotli \
    --add-dynamic-module=../incubator-pagespeed-ngx \
    --add-dynamic-module=../ngx_immutable \
    --add-dynamic-module=../ngx_cache_purge \
    && make modules \
    && cp objs/*.so /usr/lib/nginx/modules/

FROM nginx:${NGINX_VERSION} AS final
COPY --from=builder /usr/lib/nginx/modules/ /usr/lib/nginx/modules/
RUN echo "load_module modules/ngx_pagespeed.so;\n$(cat /etc/nginx/nginx.conf)" > /etc/nginx/nginx.conf && \
    echo "load_module modules/ngx_http_immutable_module.so;\n$(cat /etc/nginx/nginx.conf)" > /etc/nginx/nginx.conf && \
    echo "load_module modules/ngx_http_cache_purge_module.so;\n$(cat /etc/nginx/nginx.conf)" > /etc/nginx/nginx.conf && \
    echo "load_module modules/ngx_http_brotli_static_module.so;\n$(cat /etc/nginx/nginx.conf)" > /etc/nginx/nginx.conf && \
    echo "load_module modules/ngx_http_brotli_filter_module.so;\n$(cat /etc/nginx/nginx.conf)" > /etc/nginx/nginx.conf