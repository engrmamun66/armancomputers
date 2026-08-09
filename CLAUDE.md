# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repo layout

The actual application lives in `laravel-app/` — run all commands from there, not the repo root. `mobile-app/` is an empty placeholder for a future native client that will consume the same API. `laravel.local-run-process.md` at the repo root has full local setup steps (MySQL creds, demo logins, etc.).

This is a Laravel 12 + Vue 3 SPA **monolith**: Vue owns all client-side routing, Laravel serves one Blade shell (`resources/views/app.blade.php`) and a JSON API under `/api`. Vite is used only for asset compilation/HMR, never for page routing — this is deliberate, it avoids CORS entirely since everything is same-origin.

## Commands

Run from `laravel-app/`:

```bash
composer run dev          # php artisan serve + queue:listen + pail + vite, concurrently
php artisan test          # full backend suite
php artisan test --filter=StockOutTest          # single test class
php artisan test --filter="stock out rejects insufficient stock"   # single test by name
npm run dev                # vite only (HMR)
npm run build               # production frontend build — run after any resources/js or resources/css change
```

There is no frontend test suite or linter configured. After any JS/CSS change, `npm run build` and then verify in-browser (this project's history is full of build-time-only bugs — see "Known sharp edges" below).

Tests run against an isolated **in-memory SQLite** DB (`phpunit.xml`), completely separate from the real MySQL dev database (`araman_computers`) configured in `.env`. `RefreshDatabase` is safe to use in feature tests as a result.

## Architecture

**Auth**: `tymon/jwt-auth` (NOT Sanctum) — stateless bearer tokens, `auth:api` guard on all routes except login. Chosen so a future mobile client can hit the exact same API. Token TTL is 7 days (`JWT_TTL` in `.env` / `config/jwt.php`).

**Roles**: admin / manager / staff, enforced in two independent places that must be kept in sync:
- Backend: `app/Policies/*` (authoritative — e.g. `StockOutPolicy` lets staff create but not delete/update).
- Frontend: `resources/js/utils/permissions.js`'s `CAPABILITIES` map + each route's `meta.roles` in `resources/js/router/index.js` (`router.beforeEach` redirects on violation). This only controls what the UI *shows*; it is not a security boundary.

**Status model**: a single polymorphic-by-convention `statuses` table backs Product/Customer/Brand/User ("general": active/inactive), StockIn/StockOut/Invoice status (completed/cancelled/issued), scoped by `Status::TYPE_*` constants. Look up IDs via `Status::id($type, $slug)`, never hardcode a status ID.

**Stock In / Stock Out are the core modules** — everything else supports them. Both follow the same shape in `app/Http/Controllers/Api/{StockIn,StockOut}Controller.php`:
- `store()`/`update()`/`destroy()` wrapped in `DB::transaction`.
- Stock changes use `lockForUpdate()` + atomic conditional decrements (`->where('current_stock', '>=', qty)->decrement(...)`) with a post-check that throws (→ 422) if it would go negative. This is what makes concurrent Stock Out requests safe — verified historically with real parallel HTTP requests, not just unit assertions.
- `update()`/`destroy()` use a reverse-then-reapply pattern (increment old effect, then apply new) so edits and cancellations can never leave stock in a wrong state.
- Stock Out auto-creates a 1:1 `Invoice` with matching items/totals; editing or deleting a Stock Out keeps its Invoice in sync (Invoices have no independent create/update/delete — `InvoicePolicy` is view-only).
- Reference numbers (`SI-YYYY-NNNNNN` / `SO-YYYY-NNNNNN`) come from `app/Services/ReferenceNumberGenerator.php`, which also uses `lockForUpdate()` to stay race-safe.

**List/index endpoints** share two small conventions worth reusing rather than reinventing per-controller:
- Sorting: `app/Http/Controllers/Concerns/Sortable.php` — `applySort($query, $request, $sortMap, $defaultKey, $defaultDir)` where `$sortMap` whitelists `sort_by` keys to either a real column or a `Closure($query, $dir)` for relation columns (e.g. sort Products by `brand` via a correlated subquery on `brands.name`). Never interpolate `sort_by` into raw SQL.
- Stock In/Out list responses include a `totals` key (items/qty/amount) computed over the *entire filtered result set* via a cloned pre-pagination query, not just the current page.

**Soft deletes**: Product, Customer, Brand, User are soft-deleted. Every `belongsTo` that points at one of them (e.g. `StockOut::customer()`, `StockIn::creator()`) is declared `->withTrashed()` so historical transactions keep displaying correctly after the parent is deleted. If you add a new relation to one of these models, apply the same pattern or history will silently break.

**Date columns are plain strings, not Eloquent date casts.** `purchase_date`/`sale_date`/`invoice_date` deliberately have no `'date'` cast. Eloquent's `date` cast only affects the *read* format — on write it always stores full `Y-m-d H:i:s` regardless of the cast's format modifier, which corrupted date-based grouping/filtering earlier in this project's history. Keep passing/storing these as plain `Y-m-d` strings; if seeding, call `->toDateString()` explicitly.

## Frontend conventions

- `resources/js/{stores,services,composables,views,layouts,components}` — Pinia stores are options-API style (see `stores/auth.js`, `stores/theme.js`). One `services/*.js` file per resource, each a thin wrapper around `services/api.js` (axios instance); list endpoints take a `params` object passed straight through to the query string (sort/filter/pagination params all flow through untouched — don't rename them client-side).
- `components/tables/DataTable.vue` is the shared list-table component: pass `columns` (`{ key, label, align, sortable }`) + `rows`, provide `#cell-<key>` slots for custom rendering, `#footer` slot for a totals row. It renders its own sortable column headers and emits `@sort(key)` — the parent view owns the actual `sort_by`/`sort_dir` state and refetch (see any `*List.vue` for the pattern: toggle asc/desc if the same key is clicked again, else reset to asc).
- Every list view has both a desktop `<table>` (via DataTable, `hidden md:block`) and an independent mobile card list (`md:hidden`) — these are two separate template blocks that must be updated together; there is no shared row-rendering logic between them.
- `components/common/SelectSearch.vue` is a searchable dropdown for **small fixed enumerable option lists** (Status, Role, payment method) with an optional inline "add new" (`allow-create` + `create-fn` prop — only wired up for Brand, since Role/Status/payment-method values are hardcoded elsewhere in both frontend permission logic and backend business logic, so letting users freely create new ones would silently break things). `components/common/{Product,Customer}Search.vue` are async debounced remote-search dropdowns for large/dynamic collections instead — don't use SelectSearch for those.
- `components/common/DateRangePicker.vue` wraps the third-party `em-datetimepicker` widget (`resources/js/vendor/em-datetimepicker/`, `components/common/EmDateTimePicker.vue`). Default mode is two separate date inputs; pass `unified` + `:presets="[...]"` for the single-field range-with-presets variant (used on Stock In/Out/Invoice lists). This is the only date input in the app — never add a native `<input type="date">`.

## Theming

Light/dark/auto theme (`stores/theme.js`, toggled via `components/common/ThemeToggle.vue` in the header) is implemented almost entirely in CSS, not with Tailwind `dark:` variants. `resources/css/app.css`'s `@theme` block redefines Tailwind's own `--color-white`/`--color-slate-*` (and the rose/amber/emerald badge shades) using the native CSS `light-dark()` function, keyed off `color-scheme` on `<html>` (set by the theme store). This means **every existing `bg-white`/`text-slate-*`/`border-slate-*` class anywhere in the app is already theme-aware for free** — you do not need to add `dark:` classes when writing new UI.

Two things are deliberately *not* theme-inverted, because they're used as solid button/badge fills with fixed white text and inverting them would break contrast:
- `--color-primary-*` (the brand ramp, currently black/near-black) — stays static.
- `--color-danger-solid` / `--color-success-solid` / `--color-ink-solid` / `--color-overlay-solid` — fixed-value escape hatches for the handful of spots (delete-confirm button, toasts, modal backdrops) that need a color that does *not* follow the theme.

For anything else that needs to visually invert with the theme but isn't a plain neutral surface — e.g. the bold "active" sidebar nav pill, or solid action buttons that should flip from dark-bg/white-text to white-bg/black-text in dark mode — use `--color-accent-solid` / `--color-on-accent-solid` (theme-inverting), not `--color-primary-*`. And for plain inline link/text-only color sitting directly on a card surface (as opposed to a button fill), use `--color-link` / `--color-link-hover` — `text-primary-600` on its own is barely visible in dark mode against a dark card background.

When adding a new solid-fill color, ask which category it is (always-static brand/danger color vs. theme-inverting accent) before picking a token — mixing these up is an easy, easy-to-miss bug (see "Known sharp edges").

## Known sharp edges

- A literal `*/` appearing inside a CSS comment (e.g. from wildcard-style shorthand like `text-slate-*/border-slate-*`) silently closes the comment early and breaks the whole `@theme` block with a confusing Tailwind error pointing at an unrelated line. If a `@theme` edit fails to build with "must only contain custom properties", check your comments for a stray `*/` first.
- Because `--color-white`'s dark-mode value and `--color-slate-800`'s light-mode value happen to coincide, a `bg-slate-100`-based chip can end up visually identical to its `bg-white` container in dark mode (looks invisible). If a "neutral" badge/button disappears in dark mode, it's this — bump it a shade (e.g. `slate-100` → `slate-200`).
- The `em-datetimepicker` prop `use-custom-range` (enables the preset sidebar on unified range pickers) is easy to typo into a no-op (e.g. `use-custom-range--`) since Vue silently accepts unknown kebab-case attrs without warning. If range presets stop appearing, check the attribute name is exact.
