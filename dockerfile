# First stage: Building NGINX with Naxsi
FROM alpine:latest AS build

ENV NGINX_VERSION=1.22.0

# Install necessary build dependencies
RUN apk add --no-cache \
    git \
    build-base \
    pcre2-dev \
    openssl-dev \
    zlib-dev \
    wget \
    curl \
    ca-certificates \
    libxml2-dev \
    libxslt-dev \
    geoip-dev \
    gd-dev

# Download Naxsi
WORKDIR /usr/src
RUN git clone https://github.com/nbs-system/naxsi.git

# Download and build NGINX with Naxsi module
RUN wget http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz && \
    tar -zxvf nginx-${NGINX_VERSION}.tar.gz && \
    cd nginx-${NGINX_VERSION} && \
    ./configure --add-module=/usr/src/naxsi/naxsi_src/ \
                --prefix=/etc/nginx \
                --sbin-path=/usr/sbin/nginx \
                --modules-path=/usr/lib/nginx/modules \
                --conf-path=/etc/nginx/nginx.conf \
                --error-log-path=/var/log/nginx/error.log \
                --http-log-path=/var/log/nginx/access.log \
                --pid-path=/var/run/nginx.pid \
                --lock-path=/var/run/nginx.lock \
                --http-client-body-temp-path=/var/cache/nginx/client_temp \
                --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
                --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
                --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
                --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
                --user=nginx \
                --group=nginx \
                --with-http_ssl_module \
                --with-http_realip_module \
                --with-http_addition_module \
                --with-http_sub_module \
                --with-http_dav_module \
                --with-http_flv_module \
                --with-http_mp4_module \
                --with-http_gunzip_module \
                --with-http_gzip_static_module \
                --with-http_random_index_module \
                --with-http_secure_link_module \
                --with-http_stub_status_module \
                --with-http_auth_request_module \
                --with-http_xslt_module=dynamic \
                --with-http_image_filter_module=dynamic \
                --with-http_geoip_module=dynamic \
                --with-threads \
                --with-stream \
                --with-stream_ssl_module \
                --with-stream_ssl_preread_module \
                --with-stream_realip_module \
                --with-stream_geoip_module=dynamic \
                --with-http_slice_module \
                --with-mail \
                --with-mail_ssl_module \
                --with-compat \
                --with-cc-opt="-I /usr/local/include" \
                --with-ld-opt="-L /usr/local/lib" \
                --with-http_v2_module && \
    make && \
    make install

# Final stage: Creating the runtime image
FROM alpine:latest

# Install necessary runtime dependencies
RUN apk add --no-cache \
    pcre2 \
    zlib \
    openssl \
    ca-certificates \
    libxml2 \
    libxslt \
    geoip \
    gd

# Create necessary directories
RUN mkdir -p /var/cache/nginx /var/log/nginx /var/run/nginx

# Create nginx user and group
RUN addgroup -S nginx && adduser -S nginx -G nginx

# Set permissions
RUN chown -R nginx:nginx /var/cache/nginx /var/log/nginx /var/run/nginx

# Copy the built NGINX binary and related files
COPY --from=build /etc/nginx /etc/nginx
COPY --from=build /usr/sbin/nginx /usr/sbin/nginx
COPY --from=build /usr/lib/nginx /usr/lib/nginx

# Copy custom NGINX and Naxsi configuration files
COPY naxsi_core.rules /etc/nginx/naxsi_core.rules
COPY naxsi.rules /etc/nginx/naxsi.rules
COPY nginx.conf /etc/nginx/nginx.conf
COPY default.conf /etc/nginx/conf.d/default.conf

# Expose NGINX ports
EXPOSE 80 443

# Start NGINX
CMD ["/usr/sbin/nginx", "-g", "daemon off;"]