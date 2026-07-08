---
name: api-client
description: HTTP client, API integration, fetching data from external APIs. Use when consuming the HubeeV1 API or any external service.
globs:
  - "lib/http_client.rb"
  - "lib/hub_api/**/*.rb"
  - "lib/keycloak/{client,user}.rb"
  - "spec/support/*_helpers.rb"
---

# API Client Skill

## Architecture en 3 couches

```
┌─────────────────────────────────────────┐
│  Objets métier        (Data.define)     │  Un fichier par ressource
├─────────────────────────────────────────┤
│  Client spécialisé    (include module)  │  Un par API externe
├─────────────────────────────────────────┤
│  HttpClient           (module)          │  Unique, partagé par tous
└─────────────────────────────────────────┘
```

Organisation des fichiers :

```
lib/
├── http_client.rb              # Module générique (unique)
├── service_a/
│   ├── client.rb               # Client spécialisé
│   ├── organization.rb          # Objet métier
│   └── subscription.rb          # Objet métier
└── service_b/
    ├── client.rb
    └── user.rb
spec/
└── support/
    ├── service_a_helpers.rb    # Helper WebMock
    └── service_b_helpers.rb
```

## Couche 1 : Module HttpClient

Module unique partagé par tous les clients. Net::HTTP natif, pas de gem externe.

### Contrat

Méthodes publiques fournies par le module :

```ruby
def get(path, params = {})   # GET avec query params
def post(path, body = {})    # POST avec JSON body
def put(path, body = {})     # PUT avec JSON body
```

Obligations du client qui inclut le module :

```ruby
# Définir @base_url dans le constructeur
@base_url = "https://api.example.com"

# Implémenter authorization_token (private)
def authorization_token
  # => String (sera envoyé comme Bearer token)
end
```

### Hiérarchie d'erreurs

```ruby
HttpClient::Error                # Base (timeout, JSON invalide, code inattendu)
HttpClient::UnauthorizedError    # 401
HttpClient::ForbiddenError       # 403
HttpClient::NotFoundError        # 404
HttpClient::ConflictError        # 409
HttpClient::ServerError          # 5xx
```

Accessibles via le client : `MonService::Client::NotFoundError`.

### Gestion des réponses

| Code HTTP | Retour |
|-----------|--------|
| 200-299 | JSON parsé (Hash ou Array) |
| 201 | Header `Location` (String) |
| 204 | `nil` |
| 400 | `Error` (message includes body) |
| 401, 403, 404, 409 | Exception spécialisée |
| 5xx | `ServerError` |
| Autre | `Error` |

### Réseau

- Timeout : 30s (open + read)
- `Net::OpenTimeout`, `Net::ReadTimeout` → `Error "Request timeout"`
- `SocketError`, `Errno::ECONNREFUSED` → `Error "Connection failed"`

## Couche 2 : Client spécialisé

Un client par API externe. Inclut `HttpClient`, définit `@base_url`, implémente `authorization_token`.

### Stratégie A : Token passthrough

Le token utilisateur est transmis tel quel. Pour les APIs où l'utilisateur est déjà authentifié.

```ruby
module MonService
  class Client
    include HttpClient

    def initialize(access_token:, base_url: ENV.fetch("MON_SERVICE_URL"))
      @base_url = base_url
      @access_token = access_token
    end

    private

    def authorization_token = @access_token
  end
end
```

### Stratégie B : OAuth2 Client Credentials

Le client obtient son propre token machine-to-machine à chaque requête.

```ruby
module MonService
  class Client
    include HttpClient

    def initialize(
      base_url: ENV.fetch("MON_SERVICE_URL"),
      token_url: ENV.fetch("MON_SERVICE_TOKEN_URL"),
      client_id: ENV.fetch("MON_SERVICE_CLIENT_ID"),
      client_secret: ENV.fetch("MON_SERVICE_CLIENT_SECRET")
    )
      @base_url = base_url
      @token_url = token_url
      @client_id = client_id
      @client_secret = client_secret
    end

    private

    def authorization_token
      uri = URI(@token_url)
      request = Net::HTTP::Post.new(uri)
      request.set_form_data(
        grant_type: "client_credentials",
        client_id: @client_id,
        client_secret: @client_secret
      )
      response = perform_request(uri, request)

      unless response.is_a?(Net::HTTPSuccess)
        raise HttpClient::Error, "Token fetch failed (#{response.code})"
      end

      JSON.parse(response.body).fetch("access_token")
    end
  end
end
```

### Stratégie C : API key

Le plus simple — une clé statique.

```ruby
module MonService
  class Client
    include HttpClient

    def initialize(base_url: ENV.fetch("MON_SERVICE_URL"), api_key: ENV.fetch("MON_SERVICE_KEY"))
      @base_url = base_url
      @api_key = api_key
    end

    private

    def authorization_token = @api_key
  end
end
```

### Règles

- `ENV.fetch` dans les paramètres par défaut du constructeur → fail fast si absent
- Tous les paramètres injectables → testabilité
- Pas de cache de token au niveau client (sauf besoin explicite)
- Un module Ruby par service (`module MonService`)

## Couche 3 : Objets métier

Un fichier par ressource API. Encapsule le PATH, le mapping des données et la logique métier.

### Pattern A : Lookup simple

Pour un appel qui retourne une seule entité.

```ruby
module MonService
  class Organization
    Record = Data.define(:name, :identifier, :status)

    PATH = "v1/organizations"

    def self.find(identifier:, client: Client.new)
      data = client.get(PATH, id: identifier)
      raise Client::NotFoundError, "Organization not found" if data.empty?

      raw = data.first
      Record.new(
        name: raw["name"],
        identifier: raw["companyRegister"],   # camelCase API → snake_case
        status: raw["status"]
      )
    end
  end
end
```

**Principes** :
- `Record = Data.define(...)` — immutable, getters générés
- `client: Client.new` — injection optionnelle, défaut raisonnable
- Mapping explicite des clés API (camelCase) vers Ruby (snake_case)
- Erreur métier si résultat incohérent (array vide = not found)

### Pattern B : Liste simple

Quand le mapping camelCase → snake_case n'apporte pas de valeur, retourner le JSON brut.

```ruby
module MonService
  class Process
    PATH = "v1/processes"

    def self.list(identifier:, client: Client.new)
      client.get(PATH, companyRegister: identifier)
    end
  end
end
```

### Pattern C : Recherche paginée avec filtres

Pour des requêtes complexes avec critères multiples et pagination.

```ruby
module MonService
  class User
    VALID_TYPES = %w[admin member guest].freeze

    Result = Data.define(:items, :total, :offset, :per_page) do
      def total_pages
        return 1 if per_page.zero?
        (total.to_f / per_page).ceil
      end

      def current_page
        (offset / [per_page, 1].max) + 1
      end
    end

    Record = Data.define(:id, :first_name, :last_name, :email, :role)

    EMPTY_RESULT = Result.new(items: [], total: 0, offset: 0, per_page: 0).freeze

    def initialize(access_token:, name: nil, role: nil, offset: 0, per_page: 20)
      @access_token = access_token
      @name = name
      @role = role
      @offset = offset.to_i
      @per_page = per_page.to_i
    end

    # Factory method : instancie et exécute
    def self.search(access_token:, **args)
      new(access_token:, **args).search
    end

    def search
      return EMPTY_RESULT unless search_criteria?

      response = client.get("users/search", query_params)
      parse_response(response)
    end

    private

    attr_reader :access_token, :name, :role, :offset, :per_page

    def search_criteria?
      name.present? || role.present?
    end

    def client
      @client ||= Client.new(access_token:)
    end

    def query_params
      params = {}
      params[:name] = name if name.present?
      params[:role] = role if role.present?
      params[:first] = offset
      params[:max] = per_page
      params
    end

    def parse_response(response)
      items = response["data"].map { |raw| parse_record(raw) }
      Result.new(items:, total: response["total"], offset: response["first"], per_page: response["max"])
    end

    def parse_record(data)
      Record.new(
        id: data["id"],
        first_name: data["firstName"],
        last_name: data["lastName"],
        email: data["email"],
        role: data.dig("attributes", "role", 0)
      )
    end
  end
end
```

**Principes** :
- Factory method `.search(...)` — crée l'instance et exécute
- Early return `EMPTY_RESULT` — évite un appel API inutile si aucun critère
- Lazy client `@client ||=` — créé à la demande
- Deux Records : `Result` (paginé, méthodes calculées) + `Record` (entité)
- `EMPTY_RESULT` frozen — réutilisé sans allocation

### Pattern D : Pagination par en-tête `Content-Range`

À utiliser quand l'API retourne le total dans l'en-tête `Content-Range` et non dans le corps JSON. Opposé au Pattern C où le total est dans `response["total"]`.

**Méthode** : `get_with_headers(path, params)` — retourne `{body:, headers: {"Content-Range" => ...}}`

**Format de l'en-tête** : `Content-Range: items 0-19/100` → total = 100 (extrait via regex `%r{/(\d+)\z}`)

```ruby
module MonService
  class Organization
    PaginatedResult = Data.define(:records, :total, :offset, :per_page) do
      CONTENT_RANGE_REGEX = %r{/(\d+)\z}

      def self.from_response(records:, content_range:, offset:, per_page:)
        total = content_range&.then { |h| h.match(CONTENT_RANGE_REGEX)&.[](1).to_i } || 0
        new(records:, total:, offset:, per_page:)
      end

      def total_pages = per_page.zero? ? 1 : (total.to_f / per_page).ceil
      def current_page = (offset / [per_page, 1].max) + 1
    end

    def self.search(criteria = {}, offset: 0, per_page: 20, client: Client.new)
      result = client.get_with_headers(PATH, {offSet: offset, maxResult: per_page}.merge(criteria))
      records = result[:body].map { |item| parse(item) }
      PaginatedResult.from_response(
        records:,
        content_range: result[:headers]["Content-Range"],
        offset:,
        per_page:
      )
    end
  end
end
```

**Quand utiliser** : dès que l'API renvoie le total dans `Content-Range` (comportement courant des APIs RESTful paginées qui suivent la RFC 7233). Si `Content-Range` est absent, `from_response` retourne `total: 0`.

### Display methods pour l'affichage

Les données d'une API externe arrivent incomplètes (champ absent, `null`). Pour les afficher, traiter **tous les champs de façon identique** : une méthode `display_*` avec fallback par champ, sans condition asymétrique. Un objet métier (`Data.define` ou classe) qui expose ces champs porte le contrat d'affichage de façon uniforme.

```ruby
# ✅ Contrat uniforme avec fallbacks via define_method
DISPLAY_FALLBACKS = {
  name: "Nom manquant",
  siret: "SIRET manquant",
  branch_code: nil,
  type: "Type inconnu"
}.freeze

DISPLAY_FALLBACKS.each_key do |field|
  define_method(:"display_#{field}") do
    send(field).presence || DISPLAY_FALLBACKS[field]
  end
end

# ❌ Condition asymétrique (pourquoi seulement branch_code ?)
def label
  parts = ["#{name} — SIRET #{siret}"]
  parts << "branche #{branch_code}" if branch_code.present?
  parts.join(", ")
end
```

## Consommation dans les controllers

```ruby
class UsersController < ApplicationController
  def index
    return unless search_requested?

    @result = MonService::User.search(
      access_token: current_access_token,
      **search_params
    )
  rescue MonService::Client::Error => e
    flash.now[:alert] = t(".search_error", message: e.message)
  end

  private

  def search_requested?
    search_params.values.any?(&:present?)
  end

  def search_params
    @search_params ||= {
      name: params[:name]&.strip.presence,
      role: (params[:role] if MonService::User::VALID_TYPES.include?(params[:role]))
    }
  end
end
```

**Principes** :
- Rescue sur `Client::Error` (classe de base) pour attraper toutes les erreurs HTTP
- Sanitisation stricte : whitelist, strip, regex selon le type de donnée
- Early return si aucun critère (évite un appel API sans filtre)

## Tests avec WebMock

### Principes

1. **Stubs permissifs** : `stub_request` définit la réponse, sans contraindre les headers
2. **Vérification dédiée** : `have_requested(...).with(headers:)` dans un test séparé
3. **Un helper par API** dans `spec/support/` avec inclusion globale

### Helper de test

```ruby
# spec/support/mon_service_helpers.rb
module MonServiceHelpers
  def mon_service_base_url
    ENV.fetch("MON_SERVICE_URL")
  end

  # Pour OAuth2 Client Credentials
  def stub_mon_service_token(access_token: "test-token")
    stub_request(:post, ENV.fetch("MON_SERVICE_TOKEN_URL"))
      .with(body: {
        grant_type: "client_credentials",
        client_id: ENV.fetch("MON_SERVICE_CLIENT_ID"),
        client_secret: ENV.fetch("MON_SERVICE_CLIENT_SECRET")
      })
      .to_return(
        status: 200,
        body: {access_token:, expires_in: 3600}.to_json,
        headers: {"Content-Type" => "application/json"}
      )
  end

  # Builder de réponse pour les données de test
  def mon_service_user(overrides = {})
    {"id" => "uuid", "firstName" => "Test", "lastName" => "User",
     "email" => "test@example.com", "attributes" => {"role" => ["member"]}
    }.merge(overrides)
  end

  def mon_service_search_response(items:, total: nil, first: 0, max: 20)
    {"data" => items, "total" => total || items.size, "first" => first, "max" => max}
  end
end

RSpec.configure { |c| c.include MonServiceHelpers }
```

### Patterns de test

**Client : token + auth header**

```ruby
describe MonService::Client do
  let(:client) { described_class.new }

  it "sends Bearer auth header" do
    stub_mon_service_token(access_token: "my-token")
    stub_request(:get, "#{mon_service_base_url}/path")
      .to_return(status: 200, body: "[]", headers: {"Content-Type" => "application/json"})

    client.get("path")

    expect(WebMock).to have_requested(:get, "#{mon_service_base_url}/path")
      .with(headers: {"Authorization" => "Bearer my-token"})
  end
end
```

**Objet métier : injection du client pour isoler**

```ruby
describe MonService::Organization do
  let(:client) { instance_double(MonService::Client) }

  it "raises NotFoundError when empty" do
    allow(client).to receive(:get).and_return([])

    expect {
      described_class.find(identifier: "123", client:)
    }.to raise_error(MonService::Client::NotFoundError)
  end
end
```

**Recherche : early return sans appel API**

```ruby
describe MonService::User do
  it "returns EMPTY_RESULT without API call when no criteria" do
    result = described_class.search(access_token: "token")

    expect(result).to eq(MonService::User::EMPTY_RESULT)
    expect(WebMock).not_to have_requested(:get, /users/)
  end
end
```

## Checklist nouveau client API

1. Créer `lib/mon_service/client.rb` — `include HttpClient` + auth
2. Implémenter `authorization_token` selon la stratégie (A, B ou C)
3. Un fichier par ressource dans `lib/mon_service/` avec `Data.define` Records
4. `client: Client.new` en paramètre par défaut des class methods
5. Helper de test dans `spec/support/mon_service_helpers.rb`
6. Variables d'env dans `.env.example` et `.env.test`
