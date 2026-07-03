# Deployment & CI/CD

The production architecture is **Supabase-first** (see the root `README.md`).
There are three deployable artifacts and one managed backend:

| Artifact | What it is | Where it runs |
| --- | --- | --- |
| `web-admin/` | Static SPA (Vite build → `dist/`) | Any static host / CDN |
| `web-staff/` | Static SPA (Vite build → `dist/`) | Any static host / CDN |
| `lib/` (Flutter) | Android / iOS app | App stores / internal distribution |
| `supabase/` | Postgres schema + RLS + Edge Functions | **Supabase (managed)** — the backend |

There is **no application server and no container** in this architecture. The web
apps are static bundles; the backend is Supabase. (This is why there is no
`Dockerfile`: a Vite SPA is served as static files from a CDN, and Postgres/Auth
are managed by Supabase — there is nothing to containerize. If a future FastAPI
service is added, that is when Docker would enter.)

## Continuous Integration (`.github/workflows/ci.yml`)

Runs on every push / PR to `main`:

| Job | Gate |
| --- | --- |
| **Web** (matrix: web-admin, web-staff) | `npm ci` → `npm run build` (**`tsc -b` typecheck + Vite build**) → `npm audit` (high+) → uploads `dist/` artifact |
| **Flutter** | `flutter pub get` → `flutter analyze` → `flutter test` |
| **RLS policy suite** | `supabase/tests` — signs in as every role and asserts every policy (see `supabase/tests/README.md`) |

Plus:
- **`codeql.yml`** — CodeQL security scanning (JavaScript/TypeScript) on push/PR + weekly.
- **`dependabot.yml`** — weekly dependency + GitHub-Actions update PRs for both web apps, the RLS suite, and Flutter (`pub`).

### Configuring the RLS job
By default the suite targets the shared dev/demo Supabase project (publishable key
only — safe). To point CI at a different project, set repo **secrets**:
`SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, `DEMO_PASSWORD`. Never add the
`service_role` key — the suite does not use it.

## Environments & secrets

Use **GitHub Environments** to separate `development` / `staging` / `production`,
each with its own Supabase project and its own environment secrets:

| Secret | Used by | Notes |
| --- | --- | --- |
| `VITE_SUPABASE_URL` | web build | per environment |
| `VITE_SUPABASE_PUBLISHABLE_KEY` | web build | publishable (browser-safe) |
| `SUPABASE_SERVICE_ROLE_KEY` | Supabase Edge Function config only | **never** in a web/Flutter build or committed |

Client config is read from env at build time (`web-*/.env`, Flutter
`--dart-define`); see each app's `.env.example`.

## Deploying

### Database (Supabase)
Migrations are the ordered SQL files in `supabase/` (see `SUPABASE_SETUP.md`).
Apply them to the target project's SQL editor / via the Supabase CLI **in order**;
all are idempotent. Deploy Edge Functions with `supabase functions deploy <name>`.

### Web apps
`npm run build` produces a static `dist/` (already uploaded as a CI artifact).
Publish that folder to your chosen static host. **A hosting provider has not been
chosen yet** — this is a product decision. Once chosen (e.g. Vercel, Netlify,
Cloudflare Pages, or GitHub Pages), add a `deploy.yml` workflow triggered on
release/tag that builds with the environment's `VITE_SUPABASE_*` secrets and
uploads to that host with its token. Until then, deployment is done manually from
the CI artifact. **This step is intentionally not automated to avoid a fake
integration against an unchosen provider.**

### Mobile (Flutter)
`flutter build appbundle` / `flutter build ipa` with the production
`--dart-define`s, then distribute via the stores or an internal channel.

## Rollback
- **Web**: redeploy the previous build artifact / previous release tag (static
  hosts keep immutable deploys — roll back by re-pointing to the prior one).
- **Database**: migrations are forward-only. To reverse a change, write and apply
  a new compensating migration; do not hand-edit production tables. Take a
  Supabase backup/point-in-time snapshot before large migrations.
- **Edge Functions**: redeploy the previous version from git history.

## Recommended branch protection for `main`
- Require pull requests; no direct pushes.
- Require status checks to pass: **Web (web-admin)**, **Web (web-staff)**,
  **Flutter**, **RLS policy suite**, **CodeQL**.
- Require branches up to date before merge; require at least 1 review.
- Dismiss stale approvals on new commits; require conversation resolution.
- Restrict who can push; enforce for administrators.

## Status
- ✅ CI (typecheck, build, Flutter analyze/test, RLS suite), CodeQL, Dependabot — configured and runnable on GitHub.
- ⏳ **Automated deploy** — blocked on a hosting-provider decision + its token/secrets (see above). Manual deploy from CI artifacts works today.
- ⏳ Docker — **not applicable** to the current Supabase-first, static-frontend architecture.
