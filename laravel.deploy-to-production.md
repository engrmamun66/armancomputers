# Deploy to Production (cPanel / Shared Hosting)

## 1. Build assets locally

Server doesn't need Node — build on your machine, upload the output (`public/build/`) in step 2.

```bash
cd laravel-app
npm ci
npm run build
```

## 2. Upload code

- Git: `git clone <repo-url> laravel-app` on server, or
- Manual: zip `laravel-app/` (include `vendor/`, `public/build/`), upload + extract via File Manager

If code is already cloned on server: just upload local `laravel-app/public/build/` into the same path on server (`public/build` is gitignored, won't exist from a clone).

```bash
composer install --no-dev --optimize-autoloader
```

## 3. Set document root

cPanel → Domains → set Document Root to `laravel-app/public`

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

```bash
git pull
composer install --no-dev --optimize-autoloader
npm run build   # locally, then re-upload public/build/
php artisan migrate --force
php artisan optimize:clear
php artisan config:cache
php artisan route:cache
php artisan view:cache
php artisan event:cache
```
