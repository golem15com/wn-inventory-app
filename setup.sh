#!/bin/bash
git submodule update --init --recursive
mkdir -p storage/temp/protected/paymentgateway
composer update
composer update
cp .env.example .env
php artisan key:generate
php artisan winter:install
echo "Run the stack with php artisan serve"
