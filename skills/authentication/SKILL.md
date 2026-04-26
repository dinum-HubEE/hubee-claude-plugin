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
  - app/services/keycloak/**
  - config/initializers/omniauth.rb
  - config/initializers/session_store.rb
  - spec/requests/authentication_spec.rb
  - spec/requests/sessions_spec.rb
---

# Keycloak OIDC Authentication

## Architecture

The app uses OmniAuth with the `openid_connect` provider to authenticate via Keycloak.

## OIDC Tokens - Key Points

### id_token vs access_token

| Token | Expiration | Usage |
|-------|------------|-------|
| **id_token** | Minutes | SSO Logout (`id_token_hint`) - stored in Rails.cache |
| **access_token** | 5 min | Its `expires_in` is used as cache TTL and to compute session `expires_at` |
| **refresh_token** | Long | Not used |

### Why this separation?

- **`expires_at` from access_token's `expires_in`**: Access token expires in 5 min (Keycloak config). The id_token expires too quickly to serve as reference. The controller computes `expires_at = Time.current.to_i + expires_in`.
- **`id_token` for logout**: The OIDC spec defines `id_token_hint`, not `access_token_hint`. The id_token contains the `sid` (session ID) claim.

## Key Files

### `app/controllers/concerns/authentication.rb`

```ruby
module Authentication
  LOGIN_PATH = "/auth/openid_connect"

  def authenticate_user!
    return if valid_session?

    reset_session
    redirect_to LOGIN_PATH
  end

  def current_user
    @current_user ||= session[:user_info]&.with_indifferent_access
  end

  def user_signed_in?
    current_user.present?
  end

  private

  def valid_session?
    user_signed_in? && !token_expired?
  end

  def token_expired?
    expires_at = current_user&.dig("expires_at")
    expires_at && expires_at < Time.current.to_i
  end
end
```

### `app/controllers/sessions_controller.rb`

- `create`: OmniAuth callback, stores user_info in session and id_token in cache
- `destroy`: Clears session, deletes id_token from cache, redirects to Keycloak logout
- `failure`: Handles authentication errors

### `app/services/keycloak/logout_url_builder.rb`

Builds the `end_session_endpoint` URL with `id_token_hint` and `post_logout_redirect_uri`.

## Session

```ruby
session[:user_info] = {
  "keycloak_id" => "uuid",
  "email" => "user@example.com",
  "name" => "Name",
  "session_token" => "uuid-local",  # Key to retrieve id_token from cache
  "expires_at" => 1706540400        # Unix timestamp (computed from access_token expires_in)
}
```

## Expiration (defense in depth)

1. **Token**: `token_expired?` checks `expires_at` on every request
2. **Cookie**: Expires after 30min of inactivity (`session_store.rb`)

## SSO

- **Login**: If already connected to Keycloak, automatic login (standard SSO)
- **Logout**: Single Logout - disconnects from all apps in the realm

## Keycloak Configuration

| Parameter | Value | Effect |
|---|---|---|
| Access Token Lifespan | 5 min | Cache TTL in Solid Cache |
| SSO Session Idle | 2h | Max inactivity before SSO invalidation |
| SSO Session Max | 8h | Absolute max SSO session duration |

## Security Model

| Threat | Protection | Status |
|--------|-----------|--------|
| Forged JWT | OmniAuth verifies JWKS signature at login | Covered |
| Forged cookie | Rails encryption + signature (`secret_key_base`) | Covered |
| Stolen cookie + revoked token | Backchannel logout (not implemented) | Residual risk (5 min window) |

The app does NOT verify JWT signatures itself — OmniAuth handles this at login.
After login, only a session UUID circulates (not the JWT). Backchannel logout is not
implemented; the max exposure window is 5 min (access token TTL).

See `docs/authentication.md` for the full security analysis.

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

In dev, use the `dotenv` gem via a local `.env` file. In production, variables are injected by Ansible from Vault.

## Tests

```ruby
# Test helper
sign_in_via_omniauth(email: "test@example.com", expires_in: 3600)
```

Specs: `spec/requests/authentication_spec.rb`, `spec/requests/sessions_spec.rb`
