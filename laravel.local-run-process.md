# Arman Computers — Local Run Process

Laravel 12 API + Vue 3 SPA monolith. App code lives in `laravel-app/`.

## Prerequisites

- PHP 8.2+, Composer
- Node 22+, npm
- MySQL running locally (or skip DB setup below and use SQLite — see Database section)

## First-time setup

```bash
cd laravel-app
composer install
npm install
```

`.env` already exists with `APP_KEY` and `JWT_SECRET` generated. If starting fresh:

```bash
cp .env.example .env
php artisan key:generate
php artisan jwt:secret
```

## Database

Current `.env` is wired to MySQL:

```
DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=araman_computers
DB_USERNAME=root
DB_PASSWORD=engrdevpass1
```

Database must already exist:

```bash
mysql -h127.0.0.1 -P3306 -uroot -pengrdevpass1 -e "CREATE DATABASE IF NOT EXISTS araman_computers CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
```

Run migrations + demo seed data:

```bash
php artisan migrate:fresh --seed
php artisan storage:link   # required once, for profile avatar uploads
```

Seed creates: 2 roles (admin/manager), general/purchase/sale/invoice statuses, 2 demo users, 8 brands, 24 products, 10 customers, sample Purchase/Sale transactions with auto-generated invoices.

## Running the app

Two processes, both from `laravel-app/`:

```bash
php artisan serve --port=7878   # backend + serves the SPA shell
npm run dev                      # Vite dev server (HMR)
```

Visit **http://127.0.0.1:7878** — Vite is only used for asset compilation/HMR, not for serving pages, so there's a single origin and no CORS setup needed.

## Demo logins

| Email | Role | Password |
|---|---|---|
| admin@armancomputers.com | Admin | `AdminAC!2026#Xk9` |
| manager@armancomputers.com | Manager | `ManagerAC!2026#Qz4` |

Note: a Staff role/account existed previously and has been fully retired — only admin/manager remain.

## Production build

```bash
npm run build
```

Outputs to `public/build/`. Laravel serves the built assets automatically once `public/hot` (Vite dev marker) is absent.

## Tests

```bash
php artisan test
```

Runs against an in-memory SQLite DB (configured in `phpunit.xml`) — does not touch the MySQL dev database. 23 feature tests cover auth, Stock In, and Stock Out (including insufficient-stock rejection, transaction rollback, and stock reconciliation on edit/delete).
