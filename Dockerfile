FROM centos:7

LABEL maintainer="matr1xc0in"

USER root

ARG NGINX_USER
ARG NGINX_UID
ARG NGINX_GID

# Configurating all necessary stuff
ENV SHELL=/bin/bash \
    NGINX_USER=$NGINX_USER \
    NGINX_UID=$NGINX_UID \
    NGINX_GID=$NGINX_GID \
    NGINX_DIR=/usr/share/nginx \
    NGINX_LOG=/var/log/nginx \
    NGINX_RUN=/var/run/nginx \
    NGINX_LOCK=/run/lock/subsys/nginx \
    SHELL=/bin/bash \
    LC_ALL=en_US.UTF-8 \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US.UTF-8

ENV PATH=$PATH \
    HOME=/home/$NGINX_USER

COPY update-permission /usr/local/bin/update-permission

RUN groupadd -g $NGINX_GID $NGINX_USER && \
    useradd -u $NGINX_UID -g $NGINX_GID -d $HOME -ms /bin/bash $NGINX_USER && \
    chmod g+w /etc/passwd /etc/group

# Pre-install all required pkgs
RUN yum clean all && rpm --rebuilddb && \
    yum update -y && \
    yum install -y \
      git \
      bzip2 \
      unzip \
      make \
      gcc \
      gcc-c++ \
      gd-devel GeoIP-devel gperftools-devel libxslt-devel pcre-devel perl-ExtUtils-Embed redhat-rpm-config zlib-devel \
      && yum clean all && rm -rf /var/cache/yum

RUN mkdir -p $NGINX_LOG && chown -R $NGINX_USER:$NGINX_GID $NGINX_LOG && \
    mkdir -p $NGINX_RUN && chown -R $NGINX_USER:$NGINX_GID $NGINX_RUN && \
    mkdir -p $NGINX_LOCK && chown -R $NGINX_USER:$NGINX_GID $NGINX_LOCK && \
    mkdir -p $HOME/tmp && \
    update-permission $NGINX_LOG $NGINX_RUN $NGINX_LOCK $HOME

ADD ./nginx.github.build.tar.gz /tmp

# Build nginx
RUN cd /tmp/build/nginx ; \
    ./auto/configure --prefix=$NGINX_DIR \
    --sbin-path=/usr/sbin/nginx \
    --modules-path=/usr/lib64/nginx/modules \
    --conf-path=/etc/nginx/nginx.conf \
    --error-log-path=$NGINX_LOG/error.log \
    --http-log-path=$NGINX_LOG/access.log \
    --http-client-body-temp-path=$HOME/tmp/client_body \
    --http-proxy-temp-path=$HOME/tmp/proxy \
    --http-fastcgi-temp-path=$HOME/tmp/fastcgi \
    --http-uwsgi-temp-path=$HOME/tmp/uwsgi \
    --http-scgi-temp-path=$HOME/tmp/scgi \
    --pid-path=$NGINX_RUN/nginx.pid \
    --lock-path=$NGINX_LOCK \
    --user=nginx --group=nginx \
    --with-file-aio \
    --with-http_ssl_module \
    --with-http_v2_module \
    --with-http_realip_module \
    --with-http_addition_module \
    --with-http_xslt_module=dynamic \
    --with-http_image_filter_module=dynamic \
    --with-http_geoip_module=dynamic \
    --with-http_sub_module \
    --with-http_dav_module \
    --with-http_flv_module \
    --with-http_mp4_module \
    --with-http_gunzip_module \
    --with-http_gzip_static_module \
    --with-http_random_index_module \
    --with-http_secure_link_module \
    --with-http_degradation_module \
    --with-http_slice_module \
    --with-http_stub_status_module \
    --with-http_perl_module=dynamic \
    --with-openssl=$(pwd)/../openssl \
    --with-openssl-opt='-shared' \
    --with-mail=dynamic \
    --with-mail_ssl_module \
    --with-pcre \
    --with-pcre-jit \
    --with-stream=dynamic \
    --with-stream_ssl_module \
    --with-google_perftools_module \
    --with-debug \
    --with-cc-opt='-O2 -g -pipe -Wall -Wp,-D_FORTIFY_SOURCE=2 -fexceptions -fstack-protector-strong --param=ssp-buffer-size=4 -grecord-gcc-switches -specs=/usr/lib/rpm/redhat/redhat-hardened-cc1 -m64 -mtune=generic' \
    --with-ld-opt='-Wl,-z,relro -specs=/usr/lib/rpm/redhat/redhat-hardened-ld -Wl,-E' && \
    make && make install && make clean && \
    yum clean all && rm -rf /var/cache/yum && rm -rf /tmp/*

USER $NGINX_UID

EXPOSE 8080
