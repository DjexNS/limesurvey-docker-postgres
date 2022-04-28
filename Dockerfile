FROM php:8.0-apache-buster

ENV DOWNLOAD_URL https://download.limesurvey.org/latest-stable-release/limesurvey5.3.11+220425.zip
ENV DOWNLOAD_SHA256 c3787f4c839e083fec1e157e4f26f64d7e9973297f698201f45af26a2d489f95

# install the PHP extensions we need
RUN apt-get update && apt-get install -y unzip libc-client-dev libfreetype6-dev libmcrypt-dev libpng-dev libjpeg-dev libldap-common libldap2-dev zlib1g-dev libkrb5-dev libtidy-dev libzip-dev libsodium-dev && rm -rf /var/lib/apt/lists/* \
	&& docker-php-ext-configure gd --with-freetype=/usr/include/  --with-jpeg=/usr \
	&& docker-php-ext-install gd mysqli pdo pdo_mysql opcache zip iconv tidy \
    && docker-php-ext-configure ldap --with-libdir=lib/$(gcc -dumpmachine)/ \
    && docker-php-ext-install ldap \
    && docker-php-ext-configure imap --with-imap-ssl --with-kerberos \
    && docker-php-ext-install imap \
    && docker-php-ext-install sodium \
    && pecl install mcrypt-1.0.4 \
    && docker-php-ext-enable mcrypt \
    && docker-php-ext-install exif


RUN apt-get update && apt-get install -y libpq-dev \
    && docker-php-ext-install pdo pdo_pgsql pgsql

RUN a2enmod rewrite

# set recommended PHP.ini settings
# see https://secure.php.net/manual/en/opcache.installation.php
RUN { \
		echo 'opcache.memory_consumption=128'; \
		echo 'opcache.interned_strings_buffer=8'; \
		echo 'opcache.max_accelerated_files=4000'; \
		echo 'opcache.revalidate_freq=2'; \
		echo 'opcache.fast_shutdown=1'; \
		echo 'opcache.enable_cli=1'; \
	} > /usr/local/etc/php/conf.d/opcache-recommended.ini

RUN set -x; \
    curl -SL "$DOWNLOAD_URL" -o /tmp/lime.zip; \
    echo "$DOWNLOAD_SHA256 /tmp/lime.zip" | sha256sum -c - || exit 1; \
    unzip /tmp/lime.zip -d /tmp; \
    mv /tmp/lime*/* /var/www/html/; \
    mv /tmp/lime*/.[a-zA-Z]* /var/www/html/; \
    rm /tmp/lime.zip; \
    rmdir /tmp/lime*; \
    chown -R www-data:www-data /var/www/html; \
    mkdir -p /var/lime/application/config; \
    mkdir -p /var/lime/upload; \
    mkdir -p /var/lime/plugins; \
    cp -dpR /var/www/html/application/config/* /var/lime/application/config; \
    cp -dpR /var/www/html/upload/* /var/lime/upload; \
    cp -dpR /var/www/html/plugins/* /var/lime/plugins

#Set PHP defaults for Limesurvey (allow bigger uploads)
RUN { \
		echo 'memory_limit=256M'; \
		echo 'upload_max_filesize=128M'; \
		echo 'post_max_size=128M'; \
		echo 'max_execution_time=120'; \
        echo 'max_input_vars=10000'; \
        echo 'date.timezone=UTC'; \
	} > /usr/local/etc/php/conf.d/uploads.ini

VOLUME ["/var/www/html/plugins"]
VOLUME ["/var/www/html/upload"]

#ensure that the config is persisted especially for security.php
VOLUME ["/var/www/html/application/config"]


COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh
RUN ln -s usr/local/bin/docker-entrypoint.sh /entrypoint.sh # backwards compat

# RUN php -version

# ENTRYPOINT resets CMD
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["apache2-foreground"]