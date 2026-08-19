# Deploy to Production (cPanel / Shared Hosting)

## 1. Build assets locally

Server doesn't need Node — build on your machine, upload the output (`public/build/`) in step 2.

```bash
cd laravel-app
npm ci
npm run build
```

## 2. Upload code

Zip `laravel-app/`'s contents (include `vendor/` and `public/build/`), upload + extract directly into `armancomputers.net/` via File Manager (no nested `laravel-app` folder on server — its contents go straight into `armancomputers.net/`).

```bash
composer install --no-dev --optimize-autoloader   # run this locally before zipping if vendor/ isn't already included
```

## 3. Set document root

cPanel → Domains → set Document Root to `armancomputers.net/public`

(Since `laravel-app/`'s contents were uploaded directly into `armancomputers.net/`, `public/` sits right under it — no extra `laravel-app` segment in the path.)

## 4. `.env`

```bash
cp .env.example .env
php artisan key:generate
php artisan jwt:secret
```

Fill in: `APP_ENV=production`, `APP_DEBUG=false`, `APP_URL`, `DB_*` (cPanel-prefixed db/user names)

## 5. Migrate + storage link

```bash
php artisan migrate --force
php artisan storage:link
```

## 6. Cache

```bash
php artisan config:cache
php artisan route:cache
php artisan view:cache
php artisan event:cache
```

## 7. Permissions

```bash
chmod -R 775 storage bootstrap/cache
```

## Redeploy (updates)

Re-upload changed files (or full zip re-extract) into `armancomputers.net/`, then:

```bash
composer install --no-dev --optimize-autoloader   # only if composer.json/lock changed
# rebuild locally + re-upload public/build/ if resources/js or resources/css changed
php artisan migrate --force                       # only if new migrations
php artisan optimize:clear
php artisan config:cache
php artisan route:cache
php artisan view:cache
php artisan event:cache
```
