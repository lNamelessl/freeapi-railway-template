# FreeAPI Hub — Learn APIs by Doing

The FreeAPI learning server (Hitesh Choudhary's `apihub`, 9.9k stars) packaged for Railway as **two pinned services**: the API hub itself plus a MongoDB that actually exists — so it boots, serves the Swagger docs at the root URL, and every route works on the first try. Zero deploy-form prompts; per-deploy auth secrets; data persists across redeploys.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/freeapi-hub-learn-apis-by-doing)

**After deploying (2–3 minutes):**

1. **Open your app domain.** Click the service in your Railway project, open the Networking tab, click the generated `up.railway.app` domain — the FreeAPI Swagger docs render right at the root URL. Export it for the curl commands below: `export URL="https://your-domain-here.up.railway.app"` (grab the exact value from the Networking tab).
2. **Register a user** (the API has no admin seed — you self-register):

   ```bash
   curl -s -X POST "$URL/api/v1/users/register" \
     -H "Content-Type: application/json" \
     -d '{"username":"alice","email":"alice@example.com","password":"learning-apis-2026"}'
   ```

3. **Log in** and take the access token from the response (`data.accessToken`):

   ```bash
   curl -s -X POST "$URL/api/v1/users/login" \
     -H "Content-Type: application/json" \
     -d '{"username":"alice","password":"learning-apis-2026"}'
   ```

   ```bash
   export TOKEN="paste-the-access-token-here"
   ```

4. **Call an authed route** with the bearer token, then **do a write** to prove the whole loop works:

   ```bash
   curl -s "$URL/api/v1/users/current-user" -H "Authorization: Bearer $TOKEN"
   ```

   ```bash
   curl -s -X POST "$URL/api/v1/todos" \
     -H "Content-Type: application/json" \
     -d '{"title":"Learn what a bearer token is","description":"registered, logged in, authenticated, wrote data"}'
   ```

5. **Explore.** Every other route is documented in the Swagger docs at your root URL — try a public one without any token: `curl -s "$URL/api/v1/public/quotes/quote/random"`. A wrong token gets a clean 401: `curl -s "$URL/api/v1/users/current-user" -H "Authorization: Bearer nope"`.

## What you get

- **Two services, both pinned.** `freeapi-app` builds from the vendored source of `hiteshchoudhary/apihub` at upstream commit `3163bf09d9ee23e29378c402ae4d581e544d6c9f` (2026-10-26, v1.3.1) with its own Dockerfile; `Mongo` runs the official `mongo:8` image, digest-pinned, with a volume at `/data/db`.
- **A database that exists.** The app gets its `MONGODB_URI` as a Railway expression resolved from Mongo's private-network hostname (`mongodb://Mongo.railway.internal:27017/freeapi` in spirit) — no Atlas placeholder, no `querySrv EBADNAME` crash loop, no `process.exit(1)` before the server ever listens.
- **Secrets that are yours alone.** `ACCESS_TOKEN_SECRET`, `REFRESH_TOKEN_SECRET`, and `EXPRESS_SESSION_SECRET` are generated fresh for every deployment (`secret(64)` expressions in the Variables tab) — they are never the public `.env.sample` values shared across every deployment of the old FreeAPI.app template.
- **Production-shaped defaults.** `NODE_ENV=production` (no stack traces to clients), `CORS_ORIGIN=*` so browser apps on any origin can call your instance, no dead placeholder variables, no `PORT` variable (Railway injects the port at runtime).
- **Zero deploy prompts.** The deploy form asks nothing. Everything has a working default; tune from the Variables tab afterwards.
- **Persistent by design.** Users, todos, ecommerce and social-media records live in the MongoDB volume and survive redeploys.

## Route cookbook (copy-paste, all verified against a live deployment)

Every documented route below was exercised against a real deployment of this template. The response envelope is `{ "statusCode": ..., "success": ..., "message": ..., "data": ... }`.

| Route | Auth | Try it |
| --- | --- | --- |
| Swagger docs | none | open `$URL/` in a browser |
| Healthcheck | none | `curl -s "$URL/api/v1/healthcheck"` |
| Random quote | none | `curl -s "$URL/api/v1/public/quotes/quote/random"` |
| Register | none | `curl -s -X POST "$URL/api/v1/users/register" -H "Content-Type: application/json" -d '{"username":"alice","email":"alice@example.com","password":"learning-apis-2026"}'` |
| Login (returns tokens) | none | `curl -s -X POST "$URL/api/v1/users/login" -H "Content-Type: application/json" -d '{"username":"alice","password":"learning-apis-2026"}'` |
| Current user | bearer | `curl -s "$URL/api/v1/users/current-user" -H "Authorization: Bearer $TOKEN"` |
| Refresh tokens | refresh token | `curl -s -X POST "$URL/api/v1/users/refresh-token" -b "refreshToken=$REFRESH"` |
| Create a todo | none | `curl -s -X POST "$URL/api/v1/todos" -H "Content-Type: application/json" -d '{"title":"ship a portfolio API"}'` |
| List todos | none | `curl -s "$URL/api/v1/todos"` |
| Wrong token (control) | bad bearer | `curl -s "$URL/api/v1/users/current-user" -H "Authorization: Bearer nope"` → 401 |

Login also sets `accessToken` / `refreshToken` as httpOnly cookies, so the refresh-token call above works straight after a login if you keep the cookie jar (`-c jar.txt -b jar.txt`).

## Optional integrations (never asked for at deploy time)

| Credential | Where to get it | How to set it |
| --- | --- | --- |
| Mailtrap SMTP (verification / password-reset emails) | mailtrap.io — free sandbox inbox, copy the SMTP host, port, user and password | Set `MAILTRAP_SMTP_HOST`, `MAILTRAP_SMTP_PORT`, `MAILTRAP_SMTP_USER`, `MAILTRAP_SMTP_PASS` on the `freeapi-app` service. Without them, registration and login still work — email sending fails silently (logged in the deploy logs). |
| GitHub OAuth login | github.com/settings/developers — New OAuth app; set the Authorization callback URL to `https://your-domain-here.up.railway.app/api/v1/users/github/callback` | Set `GITHUB_CLIENT_ID` and `GITHUB_CLIENT_SECRET` on the `freeapi-app` service. The callback URL is already correct: the app derives it from your Railway domain. |
| Google OAuth login | Google Cloud console OAuth client (same callback pattern with `/api/v1/users/google/callback`) | Set `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET`. |

None of these are required to deploy or to use the API — the email/password flow and every public route work out of the box.

## Honest limits (measured, not marketing)

| Limit | Reality |
| --- | --- |
| Memory | the Node process idles at about 160 MB RSS (measured; peak about 350 MB during boot and first requests) with MongoDB on the same private network — comfortable on any plan |
| Sessions | express-session uses the default in-memory store: sessions vanish on redeploy (login tokens issued as JWTs keep working) and it is single-process by design |
| Email | no Mailtrap credentials = verification / password-reset emails are never delivered (registration and login still succeed; email errors are logged, never thrown) |
| File uploads | avatars and product images write to the container filesystem (`public/images`), so they do not survive a redeploy — database records do |
| Not hardened | upstream apihub is a teaching codebase (a course project): rate limit 5000 requests / 15 min per IP, permissive CORS, no admin hardening. Treat this as a learning sandbox, not a production backend |
| Seeds | the demo-data seeds (todos, ecommerce, social media, chat) are opt-in POST endpoints (`/api/v1/seed/...`), not boot-time magic |
| Email verification | unverified users can log in and use the API; verification links only work if you configured Mailtrap |

## Deploying your own copy

Click the deploy button at the top — Railway asks nothing, creates both services, and healthchecks the app before calling the deployment successful. Your first user is one register call away (step 2 of the quickstart).

# Deploy and Host

## About Hosting

Two services on Railway's private network. `freeapi-app` is a source build (Dockerfile builder, `node:24-alpine` digest-pinned base) of the vendored apihub tree at upstream commit `3163bf09d9ee23e29378c402ae4d581e544d6c9f` — pinned so builds are reproducible even if upstream moves. `Mongo` is the official `mongo:8` image (`sha256:05b334b0a7a78fe913caac0cd2e1ecccf4da515d9a3a44be911b6ea3734c17cd`) with a volume at `/data/db` and **no public domain** — it is reachable only from your project's private network. The app connects with a `MONGODB_URI` expression that always points at the current Mongo service over the private network.

The app listens on the Railway-injected port with a public domain targeting 8080 and a platform healthcheck on `/` (the Swagger docs page, unauthenticated, 200) — a deployment only goes live once the app and its Mongo connection are actually up. All three auth secrets are `secret(64)` expressions, resolved once per environment (stable across redeploys) and generated fresh for every new deployment.

## Why Deploy

- **The old FreeAPI.app template on Railway (307 deploys) has 0% deploy health** — it ships a literal Atlas placeholder as the Mongo URI with no database service, so every deployment crash-loops before the server listens, and it ships the public `.env.sample` auth secrets shared by every instance. This template exists to fix exactly that, and the fix is verified live: zero `EBADNAME` lines in any boot log.
- **Zero prompts, instant routes:** deploy, open the domain, register, and you are calling authed routes within minutes — no configuration wall for API-learning beginners.
- **Per-deploy secrets:** nobody can forge tokens on your instance using public sample values.
- **Pinned and honest:** upstream commit pinned, images digest-pinned, limitations disclosed in the table above instead of glossed over.

## Common Use Cases

- Learning HTTP APIs by doing: auth flows, bearer tokens, CRUD, status codes, cookies — against a real server you own.
- Teaching API basics to a class or bootcamp: every student deploys their own isolated instance in one click.
- Building a portfolio frontend against a realistic backend (register, login, JWT) without writing a backend yourself.
- A throwaway integration sandbox for webhooks and client libraries with realistic JSON envelopes.

## Dependencies for

### Deployment Dependencies

- [hiteshchoudhary/apihub](https://github.com/hiteshchoudhary/apihub) — the upstream FreeAPI learning server (ISC license, vendored at commit `3163bf09d9ee23e29378c402ae4d581e544d6c9f` in the `apihub/` directory of this repo)
- [mongo:8 official image](https://hub.docker.com/_/mongo) — digest-pinned, volume at `/data/db`, private-network only
- One Railway volume (default size) for MongoDB data and one public HTTP domain for the app

## Similar templates

The only other FreeAPI listing on Railway as of 2026-11-19 is [FreeAPI.app](https://railway.com/deploy/B2f7Hq) by Anirudh Jwala's Projects. It has 307 deploys at 0% deploy health: its deployments crash-loop because the template ships a placeholder Atlas URI and no MongoDB service, and it ships the upstream `.env.sample` auth secrets as literals. If you want a FreeAPI instance that boots and stays up, deploy this one.
