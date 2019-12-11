FROM alpine:latest

ENV RESTY_VERSION="1.15.8.1"
ENV RESTY_OPENSSL_VERSION="1.0.2p"
ENV RESTY_PCRE_VERSION="8.42"
ENV NGINX_UPLOAD_VERSION="2.3.0"
ENV NGINX_RTMP_VERSION="1.2.1"
ENV RESTY_J="5"
ENV RESTY_CONFIG_OPTIONS="\
  --prefix=/opt/openresty \
  --sbin-path=/opt/openresty/sbin/nginx \
  --conf-path=/opt/openresty/etc/nginx.conf \
  --http-log-path=/opt/openresty/log/access.log \
  --pid-path=/opt/openresty/run/nginx.pid \
  --lock-path=/opt/openresty/run/nginx.lock \
  --http-client-body-temp-path=/opt/openresty/cache/client_temp \
  --http-proxy-temp-path=/opt/openresty/cache/proxy_temp \
  --http-fastcgi-temp-path=/opt/openresty/cache/fastcgi_temp \
  --http-uwsgi-temp-path=/opt/openresty/cache/uwsgi_temp \
  --http-scgi-temp-path=/opt/openresty/cache/scgi_temp \
  --user=nginx \
  --group=nginx \
  --with-http_perl_module \
  --with-http_geoip_module \
  --with-http_addition_module \
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
  --with-http_image_filter_module \
  --with-pcre-jit \
  --with-file-aio \
  --add-module=/opt/nginx-upload-module-${NGINX_UPLOAD_VERSION} \
  --add-module=/opt/nginx-rtmp-module-${NGINX_RTMP_VERSION}"
ENV RESTY_CONFIG_OPTIONS_MORE=""
ENV RESTY_ADD_PACKAGE_BUILDDEPS=""
ENV RESTY_ADD_PACKAGE_RUNDEPS=""
ENV RESTY_EVAL_PRE_CONFIGURE=""
ENV RESTY_EVAL_POST_MAKE=""

LABEL resty_version="${RESTY_VERSION}"
LABEL resty_openssl_version="${RESTY_OPENSSL_VERSION}"
LABEL resty_pcre_version="${RESTY_PCRE_VERSION}"
LABEL resty_config_options="${RESTY_CONFIG_OPTIONS}"
LABEL resty_config_options_more="${RESTY_CONFIG_OPTIONS_MORE}"
LABEL resty_add_package_builddeps="${RESTY_ADD_PACKAGE_BUILDDEPS}"
LABEL resty_add_package_rundeps="${RESTY_ADD_PACKAGE_RUNDEPS}"
LABEL resty_eval_pre_configure="${RESTY_EVAL_PRE_CONFIGURE}"
LABEL resty_eval_post_make="${RESTY_EVAL_POST_MAKE}"

# These are not intended to be user-specified
ENV _RESTY_CONFIG_DEPS="--with-openssl=/opt/openssl-${RESTY_OPENSSL_VERSION} --with-pcre=/opt/pcre-${RESTY_PCRE_VERSION}"


# Add nginx upload module patch
ADD 0001.patch /opt/0001.patch

# 1) Install apk dependencies
# 2) Download and untar OpenSSL, PCRE, and OpenResty
# 3) Download and unzip nginx_upload_module and nginx_rtmp_module
# 4) Build OpenResty
# 5) Cleanup

RUN apk add --no-cache --virtual .build-deps \
        build-base \
        tzdata \
        curl \
        git \
        gd-dev \
        geoip-dev \
        libxslt-dev \
        linux-headers \
        make \
        readline-dev \
        zlib-dev \
        ${RESTY_ADD_PACKAGE_BUILDDEPS} \
    && apk add --no-cache \
        gd \
        ffmpeg \
        geoip \
        libgcc \
        libxslt \
        perl-dev \
        zlib \
        ${RESTY_ADD_PACKAGE_RUNDEPS} \
    #updating time Zone
    && touch /etc/timezone /etc/localtime \
    && cp /usr/share/zoneinfo/Asia/Jakarta /etc/localtime \
    && echo "Asia/Jakarta" > /etc/timezone \
    && addgroup -S nginx -g 501 && adduser -S nginx -G nginx -u 501 -s /bin/ash \
    && mkdir -p /opt \
    && cd /opt \
    && curl -fSL https://www.openssl.org/source/openssl-${RESTY_OPENSSL_VERSION}.tar.gz -o openssl-${RESTY_OPENSSL_VERSION}.tar.gz \
    && tar xzf openssl-${RESTY_OPENSSL_VERSION}.tar.gz \
    && curl -fSL https://ftp.pcre.org/pub/pcre/pcre-${RESTY_PCRE_VERSION}.tar.gz -o pcre-${RESTY_PCRE_VERSION}.tar.gz \
    && tar xzf pcre-${RESTY_PCRE_VERSION}.tar.gz \
    && curl -fSL https://openresty.org/download/openresty-${RESTY_VERSION}.tar.gz -o openresty.tar.gz \
    && mkdir -p /opt/openresty \
    && tar xzf openresty.tar.gz -C /opt/openresty --strip-components 1 \
    && curl -fSL https://github.com/fdintino/nginx-upload-module/archive/${NGINX_UPLOAD_VERSION}.zip -o upload.zip \
    && unzip upload.zip \
    && curl -fSL https://github.com/arut/nginx-rtmp-module/archive/v${NGINX_RTMP_VERSION}.zip -o rtmp.zip \
    && unzip rtmp.zip \
    && rm -rf openssl-${RESTY_OPENSSL_VERSION}.tar.gz \
        openresty-${RESTY_VERSION}.tar.gz openresty.tar.gz \
        pcre-${RESTY_PCRE_VERSION}.tar.gz upload.zip rtmp.zip \
    && cd /opt/nginx-upload-module-${NGINX_UPLOAD_VERSION} \
    && mv /opt/0001.patch . \
    && git apply -v --ignore-space-change --ignore-whitespace 0001.patch \
    && if [ -n "${RESTY_EVAL_PRE_CONFIGURE}" ]; then eval $(echo ${RESTY_EVAL_PRE_CONFIGURE}); fi \
    && cd /opt/openresty \
    && mkdir -p /opt/openresty/cache \
    && ./configure -j2 ${_RESTY_CONFIG_DEPS} ${RESTY_CONFIG_OPTIONS} ${RESTY_CONFIG_OPTIONS_MORE} \
    && make -j${RESTY_J} \
    && make -j${RESTY_J} install \
    && cd /opt \
    && if [ -n "${RESTY_EVAL_POST_MAKE}" ]; then eval $(echo ${RESTY_EVAL_POST_MAKE}); fi \
    && rm -rf openssl-${RESTY_OPENSSL_VERSION} \
        pcre-${RESTY_PCRE_VERSION} \
        nginx-upload-module-${NGINX_UPLOAD_VERSION} \
        nginx-rtmp-module-${NGINX_RTMP_VERSION} \
    && apk del .build-deps \
    && mkdir -p /opt/openresty/vhosts-extra/tools \
    && mkdir -p /opt/openresty/vhosts \
    && ln -sf /dev/stdout /opt/openresty/nginx/logs/access.log \
    && ln -sf /dev/stderr /opt/openresty/nginx/logs/error.log \
    && chown -R nginx:nginx /opt/openresty
