FROM php:8.4-fpm AS prod

ENV APP_ENV=prod
ENV APP_HOME=/github/workspace
ENV USERNAME=www-data
ARG HOST_UID=1000
ARG HOST_GID=1000

RUN apt-get update && apt-get upgrade -y && apt-get install -y \
    unzip \
    libxml2 \
    libxml2-dev \
    libzip-dev \
    wget \
    openssl \
    nginx \
    supervisor \
    gettext-base \
    libicu-dev \
    git \
    && docker-php-ext-configure pdo_mysql --with-pdo-mysql=mysqlnd \
    && docker-php-ext-configure intl \
    && docker-php-ext-install \
    pdo_mysql \
    intl \
    zip \
    && rm -rf /tmp/* \
    && rm -rf /var/list/apt/* \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

RUN mkdir -p $APP_HOME/backend/public && \
    mkdir -p /home/$USERNAME && chown $USERNAME:$USERNAME /home/$USERNAME \
    && usermod -o -u $HOST_UID $USERNAME -d /home/$USERNAME \
    && groupmod -o -g $HOST_GID $USERNAME \
    && chown -R ${USERNAME}:${USERNAME} $APP_HOME

RUN apt-get update \
    && apt-get install -y \
        curl \
        libxrender1 \
        libjpeg62-turbo \
        fontconfig \
        libxtst6 \
        xfonts-75dpi \
        xfonts-base \
        xz-utils \
        libfreetype6 \
        libpng16-16 \
        libx11-6 \
        libxcb1 \
        libxext6 \
        libssl3 \
    && rm -rf /tmp/* \
    && rm -rf /var/list/apt/* \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

RUN wget https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-3/wkhtmltox_0.12.6.1-3.bookworm_amd64.deb \
  && dpkg -i wkhtmltox_0.12.6.1-3.bookworm_amd64.deb \
  && apt-get -f install -y \
  && rm wkhtmltox_0.12.6.1-3.bookworm_amd64.deb

WORKDIR $APP_HOME

RUN git config --global --add safe.directory $APP_HOME

COPY ./docker/config/php-log.ini /usr/local/etc/php/conf.d/php-log.ini
COPY entrypoint.sh /github/workspace/entrypoint.sh

EXPOSE 80
EXPOSE 443

ENTRYPOINT ["/github/workspace/entrypoint.sh"]
CMD ["supervisord","-c","/github/workspace/docker/config/supervisord.conf","-n"]

FROM prod AS dev

RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

RUN apt update && apt install -y net-tools

RUN pecl install xdebug \
	&& docker-php-ext-enable xdebug \
    && echo "xdebug.mode=develop,debug" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini \
    && echo "xdebug.remote_autostart=off" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini \
	&& echo "xdebug.discover_client_host=0" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini \
	&& echo "xdebug.client_port=9003" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini \
    && echo "xdebug.start_with_request=yes" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini \
    && echo "xdebug.idekey=PHPSTORM" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini \
    && echo "error_reporting=E_ALL" >> /usr/local/etc/php/conf.d/error_reporting.ini