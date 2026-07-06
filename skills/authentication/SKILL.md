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
| **refresh_token** | 2h (`REFRESH_TOKEN_TTL`) | `keycloak_refresh_token:#{session_token}` | Renouvellement silencieux des tokens (`renew_keycloak_tokens!`) |

### Pourquoi cette séparation ?

- **Le TTL du cache de l'access_token *est* sa fenêtre de validité** : l'access token expire en 5 min (config Keycloak). Le TTL posé à l'écriture dans `Rails.cache` fait foi — token présent en cache = valide, token absent = à renouveler (expiré ou évincé). Aucun `expires_at` n'est dupliqué en session ni comparé dans le concern.
- **`id_token` pour le logout** : la spec OIDC définit `id_token_hint`, pas `access_token_hint`. L'id_token contient la claim `sid` (session ID).
- **`refresh_token` en cache** : permet au concern de renouveler silencieusement les tokens (quand l'access token n'est plus en cache) sans renvoyer l'utilisateur vers Keycloak. TTL aligné sur "SSO Session Idle" (2h).

## Fichiers clés

### `app/controllers/concerns/authentication.rb`

```ruby
module Authentication
  extend ActiveSupport::Concern

  class TokenRefreshFailed < StandardError; end

  ACCESS_TOKEN_TTL_FALLBACK = 1.hour # fallback si expires_in absent de la réponse Keycloak
  REFRESH_TOKEN_TTL = 2.hours # aligné sur "SSO Session Idle" Keycloak (Realm Settings > Sessions)

  included do
    helper_method :current_user, :user_signed_in?
  end

  def authenticate_user!
    # 1. Access token encore utilisable : rien à faire.
    return if access_token_usable?

    # 2. Pas de session Rails (session[:user_info] absent) : ré-authentification complète.
    unless user_signed_in?
      redirect_to_login!
      return
    end

    # 3. Session Rails présente mais access token expiré/évincé du cache
    #    (Rails.cache = unique source de vérité) : renouvellement silencieux
    #    via le refresh_token. Échoue en TokenRefreshFailed si absent/invalide.
    renew_keycloak_tokens!
  rescue TokenRefreshFailed
    redirect_to_login!
  end

  # session[:user_info] (cookie Rails) ne contient qu'une identité légère et une
  # clé de liaison (session_token) vers les tokens Keycloak, stockés côté serveur
  # dans Rails.cache — un JWT Keycloak est trop volumineux pour tenir en cookie.
  def current_user
    @current_user ||= session[:user_info]&.with_indifferent_access
  end

  def user_signed_in?
    current_user.present?
  end

  # Rails.cache est l'unique source de vérité sur l'access_token : sa présence
  # ET sa fraîcheur sont garanties par le TTL posé à l'écriture. Aucune expiration
  # n'est dupliquée en session : absent du cache = à renouveler (qu'il ait expiré
  # naturellement ou été évincé sous pression mémoire).
  def current_access_token
    session_token = current_user&.dig("session_token")
    Rails.cache.read("keycloak_access_token:#{session_token}") if session_token
  end

  private

  def access_token_usable?
    user_signed_in? && current_access_token.present?
  end

  def renew_keycloak_tokens!
    session_token = current_user["session_token"]
    refresh_token = Rails.cache.read("keycloak_refresh_token:#{session_token}")
    raise TokenRefreshFailed unless refresh_token

    token_response = Keycloak::TokenRefresher.call(refresh_token:)
    persist_renewed_tokens!(session_token, token_response)
  rescue Keycloak::Client::Error => e
    Rails.logger.error("[Authentication] Keycloak refresh failed: #{e.message}")
    raise TokenRefreshFailed
  end

  def persist_renewed_tokens!(session_token, token_response)
    tokens_ttl = token_response["expires_in"]&.seconds || ACCESS_TOKEN_TTL_FALLBACK

    write_keycloak_tokens_to_cache(
      session_token:,
      access_token: token_response["access_token"],
      id_token: token_response["id_token"],
      refresh_token: token_response["refresh_token"],
      tokens_ttl:
    )
  end

  # Point d'écriture unique des 3 tokens en cache, partagé avec
  # SessionsController#create (qui hérite de ce concern via ApplicationController)
  # — évite de dupliquer les clés "keycloak_*_token:" à deux endroits.
  def write_keycloak_tokens_to_cache(session_token:, access_token:, id_token:, refresh_token:, tokens_ttl:)
    Rails.cache.write("keycloak_access_token:#{session_token}", access_token, expires_in: tokens_ttl)
    Rails.cache.write("keycloak_id_token:#{session_token}", id_token, expires_in: tokens_ttl)
    Rails.cache.write("keycloak_refresh_token:#{session_token}", refresh_token, expires_in: REFRESH_TOKEN_TTL)
  end

  def redirect_to_login!
    reset_session
    redirect_to "/auth/openid_connect?origin=#{CGI.escape(request.fullpath)}"
  end
end
```

### `app/controllers/sessions_controller.rb`

- `create` : callback OmniAuth. Retraduit le vocabulaire de la gem (`credentials.token` → `access_token`), écrit les 3 tokens via `write_keycloak_tokens_to_cache` (mutualisé avec le concern), stocke une identité légère en session (**sans `expires_at`**), et redirige vers l'`origin` post-login (validée : commence par `/` mais pas `//`)
- `destroy` : lit l'`id_token` en cache, vide la session, supprime les 3 clés cache, redirige vers le logout Keycloak (`post_logout_redirect_uri: root_url.chomp("/")` — Keycloak exige une correspondance exacte sans slash final)
- `failure` : gère les erreurs d'authentification

> **Piège de la gem `omniauth_openid_connect`** : dans `auth.credentials`, l'access_token est nommé `token` (et non `access_token`). Le controller le retraduit une bonne fois vers notre vocabulaire (`access_token` / `id_token` / `refresh_token`) avant l'écriture en cache.

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
  "session_token" => "uuid-local"  # clé de liaison vers les tokens en cache
}
```

## Expiration (défense en profondeur)

1. **Cache = source de vérité** : la présence de l'access token en cache (TTL Solid Cache) garantit sa fraîcheur ; `access_token_usable?` vérifie uniquement cette présence, sans comparaison de timestamp
2. **Renouvellement silencieux** : access token absent du cache → `renew_keycloak_tokens!` le régénère via le `refresh_token` avant toute redirection vers login
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
# helper de test (spec/support/omniauth.rb)
sign_in_via_omniauth(email: "test@example.com", expires_in: 3600)
# attrs supportés : uid, email, name, token, refresh_token, id_token, expires_in
```

`expires_in` pilote le TTL du cache des tokens (il n'existe plus d'`expires_at` en session) : le baisser simule un access token évincé/expiré et déclenche le renouvellement silencieux.

Specs : `spec/requests/authentication_spec.rb`, `spec/requests/sessions_spec.rb`
