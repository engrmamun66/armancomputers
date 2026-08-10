# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repo layout

The web application lives in `laravel-app/` — run all commands from there, not the repo root. `mobile-app/` is a Flutter client (Riverpod + go_router + dio) consuming the same `/api` — see "Mobile app" below. `laravel.local-run-process.md` at the repo root has full local setup steps (MySQL creds, demo logins, etc.) — note it still uses old "Stock In/Stock Out" terminology in places; trust the code/this file over it for naming.

This is a Laravel 12 + Vue 3 SPA **monolith**: Vue owns all client-side routing, Laravel serves one Blade shell (`resources/views/app.blade.php`) and a JSON API under `/api`. Vite is used only for asset compilation/HMR, never for page routing — this is deliberate, it avoids CORS entirely since everything is same-origin.

## Commands

Run from `laravel-app/`:

```bash
composer run dev          # php artisan serve + queue:listen + pail + vite, concurrently
php artisan test          # full backend suite
php artisan test --filter=SaleTest          # single test class
php artisan test --filter=test_sale_rejects_insufficient_stock_and_does_not_change_stock   # single test by name
npm run dev                # vite only (HMR)
npm run build               # production frontend build — run after any resources/js or resources/css change
```

There is no frontend test suite or linter configured. After any JS/CSS change, `npm run build` and then verify in-browser (this project's history is full of build-time-only bugs — see "Known sharp edges" below).

Tests run against an isolated **in-memory SQLite** DB (`phpunit.xml`), completely separate from the real MySQL dev database (`araman_computers`) configured in `.env`. `RefreshDatabase` is safe to use in feature tests as a result.

## Architecture

**Auth**: `tymon/jwt-auth` (NOT Sanctum) — stateless bearer tokens, `auth:api` guard on all routes except login. Chosen so the mobile client can hit the exact same API (see "Mobile app" below) without a separate auth scheme. Token TTL is 7 days (`JWT_TTL` in `.env` / `config/jwt.php`).

**Roles**: admin / manager (a third "staff" role existed early on and was fully retired — if you see stray references to it, they're stale), enforced in three independent places that must be kept in sync:
- Backend: `app/Policies/*` (authoritative — e.g. `SalePolicy` lets either role create a Sale but requires admin/manager to update/delete it; `PurchasePolicy` restricts create/view/update/delete to admin/manager too).
- Web frontend: `resources/js/utils/permissions.js`'s `CAPABILITIES` map + each route's `meta.roles` in `resources/js/router/index.js` (`router.beforeEach` redirects on violation).
- Mobile: `mobile-app/lib/core/permissions.dart`'s `kCapabilities` map, which the file's own doc-comment says "mirrors resources/js/utils/permissions.js exactly" — update both together.

None of the frontend copies are a security boundary; they only control what each UI *shows*.

**Status model**: a single polymorphic-by-convention `statuses` table backs Product/Customer/Brand/User ("general": active/inactive), Purchase/Sale/Invoice status (completed/cancelled/issued), scoped by `Status::TYPE_*` constants (`TYPE_GENERAL`/`TYPE_PURCHASE`/`TYPE_SALE`/`TYPE_INVOICE`). Look up IDs via `Status::id($type, $slug)`, never hardcode a status ID.

**Purchase / Sale are the core modules** (formerly "Stock In / Stock Out" — that naming still lingers in `laravel.local-run-process.md` and some UI component paths like `components/stock/`, but the models/controllers/routes/tests are all Purchase/Sale now) — everything else supports them. Both live in `app/Http/Controllers/Api/{Purchase,Sale}Controller.php` and wrap `store()`/`update()`/`destroy()` in `DB::transaction`, but their stock-safety mechanics differ because one increases stock and the other decreases it:
- **Sale** (decreases stock, the riskier direction): `store()`/`update()` first `lockForUpdate()` the `Product` row, check `current_stock` is sufficient, then apply an atomic conditional decrement (`->where('current_stock', '>=', qty)->decrement(...)`) and throw immediately (→ 422) if it affected zero rows. This is what makes concurrent Sale requests safe — verified historically with real parallel HTTP requests, not just unit assertions. `update()`/`destroy()` reverse the old effect (plain increment) before reapplying the new one, so edits and cancellations can never leave stock in a wrong state.
- **Purchase** (increases stock on create; the risk is only on reversal): `store()` just increments. `update()`/`destroy()` reverse the old effect with a plain decrement, then check across all affected product IDs (`where('current_stock', '<', 0)->exists()`) and throw a `RuntimeException` (caught → 422) if the reversal would go negative — no row locking needed since only the reversal step can go negative and that's checked before commit.
- Sale auto-creates a 1:1 `Invoice` (linked via `sale_id`) with matching items/totals; editing or deleting a Sale keeps its Invoice in sync (Invoices have no independent create/update/delete — `InvoicePolicy` is view-only). Purchase has no Invoice.
- Reference numbers (`PUR-YYYY-NNNN` / `SAL-YYYY-NNNN` / `INV-YYYY-NNNN`) come from `app/Services/ReferenceNumberGenerator.php::generate($prefix, $table, $column)`, which also uses `lockForUpdate()` to stay race-safe.

**List/index endpoints** share two small conventions worth reusing rather than reinventing per-controller:
- Sorting: `app/Http/Controllers/Concerns/Sortable.php` — `applySort($query, $request, $sortMap, $defaultKey, $defaultDir)` where `$sortMap` whitelists `sort_by` keys to either a real column or a `Closure($query, $dir)` for relation columns (e.g. sort Products by `brand` via a correlated subquery on `brands.name`). Never interpolate `sort_by` into raw SQL.
- Purchase/Sale list responses include a `totals` key (items/qty/amount; Sale additionally reports cost/profit/due) computed over the *entire filtered result set* via a cloned pre-pagination query, not just the current page.

**Soft deletes**: Product, Customer, Brand, User are soft-deleted. Every `belongsTo` that points at one of them (e.g. `Sale::customer()`, `Purchase::creator()`) is declared `->withTrashed()` so historical transactions keep displaying correctly after the parent is deleted. If you add a new relation to one of these models, apply the same pattern or history will silently break.

**Date columns are plain strings, not Eloquent date casts.** `purchase_date`/`sale_date`/`invoice_date` deliberately have no `'date'` cast. Eloquent's `date` cast only affects the *read* format — on write it always stores full `Y-m-d H:i:s` regardless of the cast's format modifier, which corrupted date-based grouping/filtering earlier in this project's history. Keep passing/storing these as plain `Y-m-d` strings; if seeding, call `->toDateString()` explicitly.

## Frontend conventions

- `resources/js/{stores,services,composables,views,layouts,components}` — Pinia stores are options-API style (see `stores/auth.js`, `stores/theme.js`). One `services/*.js` file per resource, each a thin wrapper around `services/api.js` (axios instance); list endpoints take a `params` object passed straight through to the query string (sort/filter/pagination params all flow through untouched — don't rename them client-side).
- `components/tables/DataTable.vue` is the shared list-table component: pass `columns` (`{ key, label, align, sortable }`) + `rows`, provide `#cell-<key>` slots for custom rendering, `#footer` slot for a totals row. It renders its own sortable column headers and emits `@sort(key)` — the parent view owns the actual `sort_by`/`sort_dir` state and refetch (see any `*List.vue` for the pattern: toggle asc/desc if the same key is clicked again, else reset to asc).
- Every list view has both a desktop `<table>` (via DataTable, `hidden md:block`) and an independent mobile card list (`md:hidden`) — these are two separate template blocks that must be updated together; there is no shared row-rendering logic between them.
- `components/common/SelectSearch.vue` is a searchable dropdown for **small fixed enumerable option lists** (Status, Role, payment method) with an optional inline "add new" (`allow-create` + `create-fn` prop — only wired up for Brand, since Role/Status/payment-method values are hardcoded elsewhere in both frontend permission logic and backend business logic, so letting users freely create new ones would silently break things). `components/common/{Product,Customer}Search.vue` are async debounced remote-search dropdowns for large/dynamic collections instead — don't use SelectSearch for those.
- `components/common/DateRangePicker.vue` wraps the third-party `em-datetimepicker` widget (`resources/js/vendor/em-datetimepicker/`, `components/common/EmDateTimePicker.vue`). Default mode is two separate date inputs; pass `unified` + `:presets="[...]"` for the single-field range-with-presets variant (used on Purchase/Sale/Invoice lists). This is the only date input in the app — never add a native `<input type="date">`.

## Mobile app

`mobile-app/` is a Flutter client (Riverpod for state, `go_router` for routing, `dio` for HTTP, `flutter_secure_storage` for the JWT) hitting the same `/api` as the web SPA — this is the payoff of the jwt-auth choice above. It structurally mirrors the Laravel/Vue side rather than following idiomatic Flutter conventions of its own:
- `lib/services/*.dart` — one per resource, thin wrappers around a shared `dio` instance (`lib/core/api_client.dart`), same 1:1 split as `resources/js/services/*.js`.
- `lib/features/{sales,purchases,products,...}/` — screens grouped by resource, paralleling `resources/js/views/*`.
- `lib/core/permissions.dart` mirrors `resources/js/utils/permissions.js` exactly (see Roles above) — keep both in sync.
- Run/build commands (Chrome dev, Android emulator/device, APK build) are documented in `mobile-app.md` at the repo root, not here — check there before assuming Flutter tooling.

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
