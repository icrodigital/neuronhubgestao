FROM docker.io/library/php:8.3-fpm-alpine

# Build with: `docker build . --tag leantime:devel`

##########################
#### ENVIRONMENT INFO ####
##########################

# Change version to trigger build
ARG LEAN_VERSION=3.3.3

WORKDIR /var/www/html

ENTRYPOINT ["/start.sh"]
EXPOSE 80

########################
#### IMPLEMENTATION ####
########################

# Install dependencies
RUN apk add --no-cache \
    openldap-dev \
    libzip-dev \
    zip \
    freetype libpng libjpeg-turbo freetype-dev libpng-dev libjpeg-turbo-dev oniguruma-dev \
    icu-libs \
    jpegoptim optipng pngquant gifsicle \
    supervisor \
    nginx \
    openssl

## Installing extensions ##
# Running in a single command is worse for caching/build failures, but far better for image size
RUN docker-php-ext-install \
    mysqli pdo_mysql mbstring exif pcntl pdo bcmath opcache ldap zip \
    && \
    docker-php-ext-enable zip \
    && \
    docker-php-ext-configure gd \
      --enable-gd \
      --with-jpeg=/usr/include/ \
      --with-freetype \
      --with-jpeg \
    && \
    docker-php-ext-install gd

## Installing Leantime ##

# (silently) Download the specified release, piping output directly to `tar`
RUN curl -sL https://github.com/Leantime/leantime/releases/download/v${LEAN_VERSION}/Leantime-v${LEAN_VERSION}.tar.gz | \
    tar \
      --ungzip \
      --extract \
      --verbose \
      --strip-components 1

RUN chown www-data:www-data -R .

COPY ./start.sh /start.sh
RUN chmod +x /start.sh

COPY config/custom.ini /usr/local/etc/php/conf.d/custom.ini

# Configure supervisord
COPY config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Configure Nginx
COPY config/nginx.conf /etc/nginx/nginx.conf

# Remove Apache configurations and add Nginx configurations
RUN rm -rf /etc/apache2 && \
    sed -i '/Content-Security-Policy/d' /etc/nginx/nginx.conf && \
    echo "add_header Content-Security-Policy \"default-src 'self'; img-src 'self' data: https://neuronhubgest-o-production.up.railway.app; style-src 'self' 'unsafe-inline' https://neuronhubgest-o-production.up.railway.app; style-src-elem 'self' 'unsafe-inline' https://neuronhubgest-o-production.up.railway.app; script-src 'self' 'unsafe-inline' https://neuronhubgest-o-production.up.railway.app https://unpkg.com;\";" >> /etc/nginx/nginx.conf