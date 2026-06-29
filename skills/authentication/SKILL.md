---
name: authentication
version: 1.0.0
description: Keycloak OIDC authentication
triggers:
  - keycloak
  - oidc
  - auth
  - login
  - logout
  - session
  - token
globs:
  - app/controllers/concerns/authentication.rb
  - app/controllers/sessions_controller.rb
  - lib/keycloak/**
  - config/initializers/omniauth.rb
  - config/initializers/session_store.rb
  - spec/requests/authentication_spec.rb
  - spec/requests/sessions_spec.rb
---

# Keycloak OIDC Authentication

## Architecture

L'app utilise OmniAuth avec le provider `openid_connect` pour s'authentifier via Keycloak.

## Tokens OIDC

### Rôle de chaque token

| Token | Expiration | Clé cache | Usage |
|-------|------------|-----------|-------|
| **id_token** | Minutes | `keycloak_id_token:#{session_token}` | SSO Logout (`id_token_hint`) |
| **access_token** | 5 min (`expires_in`) | `keycloak_access_token:#{session_token}` | Bearer token pour les appels API Keycloak |
| **refresh_token** | 2h (`REFRESH_TOKEN_TTL`) | `keycloak_refresh_token:#{session_token}` | Refresh proactif de session (`refresh_session!`) |

### Pourquoi cette séparation ?

- **`expires_at` calculé depuis `expires_in` de l'access_token** : l'access token expire en 5 min (config Keycloak). Le controller calcule `expires_at = Time.current.to_i + expires_in`.
- **`id_token` pour le logout** : la spec OIDC définit `id_token_hint`, pas `access_token_hint`. L'id_token contient la claim `sid` (session ID).
- **`refresh_token` en cache** : permet au concern de renouveler proactivement les tokens sans renvoyer l'utilisateur vers Keycloak. TTL aligné sur "SSO Session Idle" (2h).

## Fichiers clés

### `app/controllers/concerns/authentication.rb`

```ruby
module Authentication
  extend ActiveSupport::Concern

  class RefreshFailed < StandardError; end

  TOKEN_TTL_FALLBACK = 1.hour
  REFRESH_TOKEN_TTL = 2.hours # aligné sur "SSO Session Idle" Keycloak

  included do
    helper_method :current_user, :user_signed_in?
  end

  def authenticate_user!
    return if valid_session?

    if token_expired?
      refresh_session!
      return
    end

    redirect_to_login!
  rescue RefreshFailed
    redirect_to_login!
  end

  def current_user
    @current_user ||= session[:user_info]&.with_indifferent_access
  end

  def user_signed_in?
    current_user.present?
  end

  def current_access_token
    session_token = current_user&.dig("session_token")
    Rails.cache.read("keycloak_access_token:#{session_token}") if session_token
  end

  private

  def valid_session?
    user_signed_in? && !token_expired? && current_access_token.present?
  end

  def token_expired?
    expires_at = current_user&.dig("expires_at")
    expires_at && expires_at < Time.current.to_i
  end

  def refresh_session!
    session_token = current_user["session_token"]
    refresh_token = Rails.cache.read("keycloak_refresh_token:#{session_token}")
    raise RefreshFailed unless refresh_token

    token_response = Keycloak::TokenRefresher.call(refresh_token:)
    refresh_tokens!(session_token, token_response)
  rescue Keycloak::Client::Error => e
    Rails.logger.error("[Authentication] Keycloak refresh failed: #{e.message}")
    raise RefreshFailed
  end

  def refresh_tokens!(session_token, token_response)
    token_ttl = token_response["expires_in"]&.seconds || TOKEN_TTL_FALLBACK

    Rails.cache.write("keycloak_access_token:#{session_token}", token_response["access_token"], expires_in: token_ttl)
    Rails.cache.write("keycloak_id_token:#{session_token}", token_response["id_token"], expires_in: token_ttl)
    Rails.cache.write("keycloak_refresh_token:#{session_token}", token_response["refresh_token"], expires_in: REFRESH_TOKEN_TTL)
    session[:user_info]["expires_at"] = Time.current.to_i + token_ttl.to_i
  end

  def redirect_to_login!
    reset_session
    redirect_to "/auth/openid_connect?origin=#{CGI.escape(request.fullpath)}"
  end
end
```

### `app/controllers/sessions_controller.rb`

- `create` : callback OmniAuth, stocke `user_info` en session, écrit les 3 tokens en cache, préserve `origin` pour la redirection post-login
- `destroy` : vide la session, supprime les 3 clés cache, redirige vers le logout Keycloak
- `failure` : gère les erreurs d'authentification

### `lib/keycloak/logout_url_builder.rb`

Construit l'URL `end_session_endpoint` avec `id_token_hint` et `post_logout_redirect_uri`.

### `lib/keycloak/token_refresher.rb`

Appelle l'endpoint `grant_type=refresh_token` de Keycloak. Retourne le hash de la réponse token (access_token, id_token, refresh_token, expires_in). Lève `Keycloak::Client::Error` en cas d'échec.

## Session

```ruby
session[:user_info] = {
  "keycloak_id" => "uuid",
  "email" => "user@example.com",
  "name" => "Name",
  "session_token" => "uuid-local",  # clé pour lire les tokens en cache
  "expires_at" => 1706540400        # Unix timestamp (calculé depuis expires_in de l'access_token)
}
```

## Expiration (défense en profondeur)

1. **Refresh proactif** : token expiré → `refresh_session!` tente de renouveler avant de rediriger vers login
2. **Token** : `token_expired?` vérifie `expires_at` à chaque requête ; `valid_session?` vérifie aussi que `current_access_token` est présent en cache
3. **Cookie** : expire après 30 min d'inactivité (`session_store.rb`)

## SSO

- **Login** : si déjà connecté à Keycloak, login automatique (SSO standard)
- **Logout** : Single Logout — déconnecte de toutes les apps du realm

## Configuration Keycloak

| Paramètre | Valeur | Effet |
|---|---|---|
| Access Token Lifespan | 5 min | TTL du cache Solid Cache |
| SSO Session Idle | 2h | Inactivité max avant invalidation SSO |
| SSO Session Max | 8h | Durée max absolue de session SSO |

## Modèle de sécurité

| Menace | Protection | Statut |
|--------|-----------|--------|
| JWT forgé | OmniAuth vérifie la signature JWKS au login | Couvert |
| Cookie forgé | Chiffrement + signature Rails (`secret_key_base`) | Couvert |
| Cookie volé + token révoqué | Backchannel logout (non implémenté) | Risque résiduel (fenêtre 5 min) |

L'app ne vérifie pas elle-même les signatures JWT — OmniAuth le fait au login.
Après le login, seul un UUID de session circule (pas le JWT). Le backchannel logout
n'est pas implémenté ; la fenêtre d'exposition maximale est de 5 min (TTL access token).

Voir `docs/authentication.md` pour l'analyse de sécurité complète.

## Configuration

Environment variables (see `.env.example`):

```bash
KEYCLOAK_ISSUER=https://keycloak.example.com/realms/master
KEYCLOAK_CLIENT_ID=hubee-admin-portal
KEYCLOAK_CLIENT_SECRET=secret
KEYCLOAK_REDIRECT_URI=http://localhost:3000/auth/openid_connect/callback
KEYCLOAK_POST_LOGOUT_REDIRECT_URI=http://localhost:3000
SECRET_KEY_BASE=...
```

En dev, utiliser le gem `dotenv` via un fichier `.env` local. En production, les variables sont injectées par Ansible depuis Vault.

## Tests

```ruby
# helper de test
sign_in_via_omniauth(email: "test@example.com", expires_in: 3600)
```

Specs : `spec/requests/authentication_spec.rb`, `spec/requests/sessions_spec.rb`
