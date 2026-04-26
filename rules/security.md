# Security Rules

These rules are ALWAYS enforced. No exceptions.

## Sensitive Files

NEVER read, write, or expose:
- `.env`, `.env.*` - Environment variables with secrets
- `config/master.key` - Rails master encryption key
- `config/credentials.yml.enc` - Encrypted credentials
- Any file containing API keys, passwords, or tokens

## Code Security

### Input Validation
- Always validate and sanitize user input
- Use strong parameters in controllers
- Never trust data from external sources

### SQL Injection
- NEVER use string interpolation in SQL queries
- Always use parameterized queries or ActiveRecord methods

```ruby
# BAD - SQL injection vulnerability
User.where("name = '#{params[:name]}'")

# GOOD - Safe parameterized query
User.where(name: params[:name])
User.where("name = ?", params[:name])
```

### XSS Prevention
- Rails escapes HTML by default, don't disable it
- Use `sanitize` helper when rendering user HTML
- Never use `raw` or `html_safe` on user input

```ruby
# BAD - XSS vulnerability
<%= raw user_input %>
<%= user_input.html_safe %>

# GOOD - Escaped by default
<%= user_input %>
<%= sanitize(user_input) %>
```

### Authentication/Authorization
- All users are authenticated administrators via Keycloak OIDC
- No granular authorization needed: all authenticated users have full admin access
- `authenticate_user!` (before_action in ApplicationController) is the sole access control
- Never expose user data without proper authentication

## Dependency Security

- Run `bundle exec bundler-audit` before commits
- Run `bin/brakeman` for static analysis
- Keep dependencies updated
- Review security advisories for gems

## npm / Supply Chain

Les projets HubEE privilégient les gems Ruby (ex : `dsfr-assets` pour le frontend) au lieu de npm afin de réduire la surface d'attaque supply chain.

Si npm devient indispensable sur un projet :

- Préférer `npm ci --ignore-scripts` à `npm install` (lifecycle scripts désactivés)
- Activer `ignore-scripts=true` dans `.npmrc`
- Épingler les versions exactes (pas de `^` ou `~`)
- Voir `frontend.md` projet-local pour les détails et restrictions spécifiques

## Git Security

- NEVER commit secrets or credentials
- Use `.gitignore` properly
- Review `git diff` before committing
- Signed commits when possible
