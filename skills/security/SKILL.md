---
name: security
description: Security review and patterns for Rails HubEE projects. Use when handling user input, writing SQL queries, rendering user-provided HTML, dealing with authentication (Keycloak OIDC) or sensitive files (.env, master.key, credentials.yml.enc), consuming external APIs, or before merging changes that touch the security surface. Covers SQL injection, XSS, mass assignment, sensitive-data exposure, the HubEE authorization model (all authenticated users are admins, no granular authz), and the audit toolchain (brakeman, bundler-audit, bin/importmap audit).
---

# Security Skill

These rules are ALWAYS enforced. No exceptions.

## Sensitive Files — NEVER read, write, or expose

- `.env`, `.env.*` — environment variables with secrets
- `config/master.key` — Rails master encryption key
- `config/credentials.yml.enc` — encrypted credentials
- `config/credentials/*.key` / `*.yml.enc` — environment-scoped credentials (Rails 6+)
- Any file containing API keys, passwords, or tokens

> The plugin's `pre-edit-secrets` hook already blocks edits on these paths. Treat this list as the source of truth even when proposing reads.

## Code-level security patterns

### SQL Injection

NEVER use string interpolation in SQL queries.

```ruby
# VULNERABLE
User.where("name = '#{params[:name]}'")

# SAFE
User.where(name: params[:name])
User.where("name = ?", params[:name])
```

### XSS (Cross-Site Scripting)

Rails escapes HTML by default. Don't disable it on user input.

```erb
<!-- VULNERABLE -->
<%= raw user_input %>
<%= user_input.html_safe %>

<!-- SAFE -->
<%= user_input %>
<%= sanitize(user_input) %>
```

### Mass Assignment

Always use strong parameters in controllers.

```ruby
# VULNERABLE
User.create(params[:user])

# SAFE
User.create(user_params)

def user_params
  params.require(:user).permit(:name, :email)
end
```

### Sensitive Data Exposure

Filter sensitive params from logs.

```ruby
# VULNERABLE — sensitive data in logs
Rails.logger.info("User password: #{params[:password]}")

# SAFE — global filter (config/initializers/filter_parameter_logging.rb)
Rails.application.config.filter_parameters += [:password, :token, :secret]
```

## Authorization model (HubEE)

> **All authenticated users are administrators via Keycloak OIDC.** No granular authorization exists.

- `authenticate_user!` (declared as `before_action` in `ApplicationController`) is the **sole** access control
- Do NOT add Pundit policies, role checks, or fine-grained authorization unless the user explicitly asks
- A new controller inheriting from `ApplicationController` inherits the auth — nothing more to wire

If a feature ever requires per-role authorization, that's a project-level architecture decision (not a default).

## Dockerfile & secrets

**Règle absolue** : ne jamais utiliser `ARG` pour injecter un credential dans un Dockerfile (token gem privée, clé API, etc.) — même passé via `--build-arg`, la valeur est inscrite dans les layers et visible dans `docker history`.

**Trigger** : dès qu'un Dockerfile installe des gems depuis une source privée (ex: `source "https://rubygems.pkg.github.com/..."` dans le Gemfile) ou touche un token quelconque.

```dockerfile
# ❌ ARG — token visible dans l'historique de l'image
ARG BUNDLE_RUBYGEMS__PKG__GITHUB__COM
RUN bundle install

# ✅ RUN --mount=type=secret — ne persiste jamais dans les layers
# syntax=docker/dockerfile:1
# check=error=true
RUN --mount=type=secret,id=bundle_token \
    BUNDLE_RUBYGEMS__PKG__GITHUB__COM="$(cat /run/secrets/bundle_token)" \
    bundle install
```

CI correspondant — utiliser `--secret`, jamais `--build-arg` pour un token :

```bash
docker build \
  --secret id=bundle_token,env=BUNDLE_RUBYGEMS__PKG__GITHUB__COM \
  .
```

## npm / Supply Chain

HubEE projects prefer Ruby gems (e.g. `dsfr-assets` for the frontend) over npm packages to reduce the supply chain attack surface (Shai-Hulud incident).

If npm becomes unavoidable on a project:
- Prefer `npm ci --ignore-scripts` over `npm install` (disables lifecycle scripts)
- Set `ignore-scripts=true` in `.npmrc`
- Pin exact versions (no `^` or `~`)

## Git Security

- NEVER commit secrets or credentials (the `pre-edit-secrets` hook + `commit` skill enforce this)
- Use `.gitignore` properly
- Review `git diff` before committing
- Signed commits when possible

## Audit toolchain

Run before merging anything that touches the security surface:

```bash
# Static analysis — Rails-specific vulnerabilities
bundle exec brakeman -q --no-pager

# Dependency advisories
bundle exec bundler-audit check --update

# Importmap pin audit (front)
bin/importmap audit
```

`bin/ci` typically already runs these — verify with `cat bin/ci`.

## Review process — when to invoke this skill in audit mode

1. Identify user-input entry points (params, URL, headers, file uploads)
2. Trace data flow through the application
3. Check for proper validation / sanitization
4. Verify auth is in place (`authenticate_user!` cascading)
5. Look for sensitive-data handling (logs, error responses, JSON serialization)

### Output format for an audit

```markdown
## Security Review: [feature]

### Risk Assessment
- **Overall Risk**: Low / Medium / High
- **Attack Surface**: <one-liner>

### Findings

#### Critical
- **file.rb:42** — issue
  - Impact: what could happen
  - Fix: how to fix

#### Warning
- **file.rb:88** — potential issue
  - Recommendation: how to improve

#### Good Practices
- positive findings

### Required Actions
- [ ] action 1
- [ ] action 2
```

## Security Headers

Ensure these are configured at the project level:

```ruby
# config/initializers/content_security_policy.rb
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.script_src :self
    policy.style_src :self, :unsafe_inline
  end
end
```
