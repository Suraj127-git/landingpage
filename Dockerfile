# Use an official PHP runtime with Alpine for a lightweight image
FROM php:8.2-fpm-alpine3.18 AS base

# Set working directory
WORKDIR /var/www/html

# Install system dependencies, PHP extensions, and cleanup
RUN apk add --no-cache \
    nginx \
    supervisor \
    git \
    libpng-dev \
    libxml2-dev \
    libzip-dev \
    && docker-php-ext-install \
    pdo_mysql \
    gd \
    xml \
    zip \
    opcache \
    && docker-php-ext-enable opcache \
    && rm -rf /var/cache/apk/*

# Copy PHP and Nginx configurations
COPY docker/php/php.ini /usr/local/etc/php/php.ini
COPY docker/nginx/nginx.conf /etc/nginx/nginx.conf
COPY docker/supervisor/supervisor.conf /etc/supervisord.conf

# Set PHP to production mode
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

# Add a non-root user for application security
RUN addgroup -S laravel && adduser -S laravel -G laravel

# Set up Composer
COPY --from=composer:2.6.5 /usr/bin/composer /usr/bin/composer

# Copy application files and set permissions
COPY . /var/www/html
RUN composer install --no-dev --no-interaction --optimize-autoloader --no-progress --no-suggest \
    && chown -R laravel:laravel /var/www/html/storage /var/www/html/bootstrap/cache \
    && php artisan config:cache \
    && php artisan route:cache \
    && php artisan view:cache

# Final lightweight image for production
FROM base AS production

# Set environment variables for production
ENV APP_ENV=production
ENV APP_DEBUG=false

# Expose port 80 for Nginx
EXPOSE 80

# Switch back to root to run supervisord
USER root

# Command to run supervisor (manages Nginx & PHP-FPM)
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
