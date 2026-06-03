---
name: tdd-workflow
description: TDD methodology, RSpec patterns, test writing. Use when writing tests, specs, creating features with TDD, or debugging test failures.
globs:
  - "spec/**/*.rb"
  - "spec/factories/**/*.rb"
  - "spec/support/**/*.rb"
---

> **Override de `superpowers:test-driven-development`** : cette skill ajoute les conventions HubEE Rails (RSpec, FactoryBot, SimpleCov 80% mini, descriptions `it`/`describe` en anglais) au cycle RED-GREEN-REFACTOR fourni par superpowers. Quand les deux sont disponibles, suivre cette skill HubEE.

# TDD Workflow Skill

## The TDD Cycle

### 1. RED - Write a failing test

```ruby
# spec/models/subscription_spec.rb
RSpec.describe Subscription, type: :model do
  describe "#active?" do
    it "returns true when status is active" do
      subscription = build(:subscription, status: "active")
      expect(subscription.active?).to be true
    end

    it "returns false when status is inactive" do
      subscription = build(:subscription, status: "inactive")
      expect(subscription.active?).to be false
    end
  end
end
```

Run: `bundle exec rspec spec/models/subscription_spec.rb`
Expected: RED (method doesn't exist)

### 2. GREEN - Minimum code to pass

```ruby
# app/models/subscription.rb
class Subscription < ApplicationRecord
  def active?
    status == "active"
  end
end
```

Run: `bundle exec rspec spec/models/subscription_spec.rb`
Expected: GREEN

### 3. REFACTOR - Improve while green

```ruby
# Maybe extract to a concern if pattern repeats
module Statusable
  extend ActiveSupport::Concern

  included do
    scope :active, -> { where(status: "active") }
  end

  def active?
    status == "active"
  end
end
```

## Language: English-only test descriptions

All `describe` / `context` / `it` descriptions MUST be in **English**, even though the rest of the project (commits, MRs, comments) stays in French. Specs are the only mandatory-English surface.

```ruby
# BAD
it "marche"
it "should return true"
it "test la création"

# GOOD
it "returns true when organization is active"
it "creates a subscription with valid params"
it "displays error for invalid SIRET"
```

## RSpec Patterns

### Model Specs

```ruby
RSpec.describe Organization, type: :model do
  # Use shoulda-matchers for validations
  describe "validations" do
    it { is_expected.to validate_presence_of(:siret) }
    it { is_expected.to validate_uniqueness_of(:siret) }
  end

  # Use shoulda-matchers for associations
  describe "associations" do
    it { is_expected.to have_many(:subscriptions) }
    it { is_expected.to belong_to(:parent).optional }
  end

  # Test custom methods
  describe "#full_name" do
    subject(:org) { build(:organization, siret: "123", name: "Test") }

    it "combines siret and name" do
      expect(org.full_name).to eq("123 - Test")
    end
  end
end
```

### Request Specs

**Règle fondamentale : 1 cas = 1 `it` = N expects.** Un scénario ne se découpe pas en plusieurs `it`. Chaque `it` doit systématiquement inclure `have_http_status` et au moins une assertion sur le body.

Toujours asserter positivement sur le contenu du body pour exprimer ce que la réponse contient. Une assertion négative peut venir en complément, mais ne suffit pas seule. Exception : si le body ne révèle absolument rien de significatif (ex: `<turbo-frame>` vide sans contenu métier), une assertion négative seule est tolérée, mais un commentaire doit remplacer l'assertion positive manquante pour expliquer l'exception au relecteur.

```ruby
# ✅ Assertion positive + négative en complément
it "renders the search hint and no results table" do
  get "/users", params: search_params

  expect(response).to have_http_status(:success)
  expect(response.body).to include("Renseignez au moins un critère")
  expect(response.body).not_to include("fr-table")
end

# ✅ Exception documentée : body sans contenu significatif
it "returns an empty list and does not call hub-api" do
  get "/organizations/autocomplete", params: {q: "abc"}

  expect(response).to have_http_status(:success)
  # Le body est un <turbo-frame> vide — aucun contenu métier à asserter positivement.
  expect(response.body).not_to include("<li")
end
```

**Préférer le hash complet à `hash_including`** — asserter le hash exact rend le contrat explicite et détecte les paramètres inattendus. `hash_including` est toléré dans des cas précis (hash très verbeux, paramètres variables comme un timestamp), mais doit être accompagné d'un commentaire qui justifie l'exception.

```ruby
# ✅ Hash complet — contrat explicite
expect(Keycloak::UserClient).to have_received(:search)
  .with(siret: "22770001000019", searched: "Dup", offset: 0, per_page: 10)

# ✅ Exception justifiée
expect(Keycloak::UserClient).to have_received(:search)
  .with(hash_including(siret: "22770001000019"))
  # offset et per_page testés séparément dans le contexte pagination

# ❌ hash_including sans raison — masque ce qui est réellement envoyé
expect(Keycloak::UserClient).to have_received(:search)
  .with(hash_including(siret: "22770001000019", searched: "Dup"))
```

```ruby
RSpec.describe "Subscriptions", type: :request do
  let(:user) { create(:user, :admin) }

  before { sign_in user }

  describe "GET /subscriptions" do
    it "returns the subscription list" do
      get subscriptions_path

      expect(response).to have_http_status(:success)
      expect(response).to render_template(:index)
    end
  end

  describe "POST /subscriptions" do
    context "with valid params" do
      let(:valid_params) do
        { subscription: attributes_for(:subscription) }
      end

      it "creates a new subscription and redirects" do
        expect {
          post subscriptions_path, params: valid_params
        }.to change(Subscription, :count).by(1)

        expect(response).to redirect_to(Subscription.last)
      end
    end

    context "with invalid params" do
      let(:invalid_params) do
        { subscription: { organization_id: nil } }
      end

      it "does not create a subscription and re-renders the form" do
        expect {
          post subscriptions_path, params: invalid_params
        }.not_to change(Subscription, :count)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("Organization must exist")
      end
    end
  end
end
```

### Factories

```ruby
# spec/factories/subscriptions.rb
FactoryBot.define do
  factory :subscription do
    organization
    process

    status { "active" }
    created_at { Time.current }

    trait :inactive do
      status { "inactive" }
    end

    trait :with_notes do
      notes { Faker::Lorem.paragraph }
    end
  end
end
```

## HubEE Test Conventions

### Matrices d'état : hashes nommés avec flags explicites

Utiliser des hashes avec clés nommées. Déclarer les flags booléens explicitement, ne jamais les recalculer inline.

```ruby
# ✅ Hash avec clés nommées et flags explicites
siret_states = {
  "valid siret"   => { input: "227 700 010 00019", invalid: false },
  "invalid siret" => { input: "123",               invalid: true  },
  "blank siret"   => { input: "",                  invalid: false }
}

# ❌ Flag calculé inline (confus, fragile)
siret_invalid = siret[:input].present? && siret[:sanitized].nil?

# ❌ Array positionnel (ordre implicite, illisible)
siret_states = {
  "valid siret"   => ["227 700 010 00019", "22770001000019"],
}
```

Pour les matrices de transformation (`to_keycloak_params`, etc.) :

```ruby
siret_states = {
  "valid siret"   => { input: "227 700 010 00019", expected_output: "22770001000019" },
  "invalid siret" => { input: "123",               expected_output: nil              },
  "blank siret"   => { input: "",                  expected_output: nil              }
}
```

### Séparation des `describe` par méthode

Ne jamais tester deux méthodes différentes dans le même `describe`. Un `describe "#valid?"` ne doit pas inclure d'assertions sur `#sanitized_siret`.

```ruby
# ✅
describe "#valid?" do
  it "is invalid with a bad siret" do
    expect(described_class.new(siret: "123")).not_to be_valid
  end
end

describe "#sanitized_siret" do
  it "returns nil for an invalid siret" do
    expect(described_class.new(siret: "123").sanitized_siret).to be_nil
  end
end
```

### Whitespace : tester dans les form specs

Les cas whitespace (strip avant validation de longueur) se testent dans les specs du form object, pas dans les request specs. La request spec garde un seul cas représentatif pour valider l'intégration.

```ruby
# Dans search_form_spec.rb
describe "name normalization" do
  it "strips surrounding whitespace before checking length" do
    expect(described_class.new(name: "  ab  ")).not_to be_valid   # 2 utiles
    expect(described_class.new(name: "  a bb c  ")).to be_valid   # 7 utiles
  end
end
```

### Helpers de test : pas de params inutilisés

Ne jamais ajouter `**extra` ou des paramètres optionnels à un helper de test s'ils ne sont pas utilisés.

```ruby
# ✅
def search_params(siret: "", organization_name: "", searched: "", user_type: "")
  {siret:, organization_name:, searched:, user_type:}
end

# ❌ **extra inutile, charge mentale pour le relecteur
def search_params(siret: "", organization_name: "", searched: "", user_type: "", **extra)
  {siret:, organization_name:, searched:, user_type:}.merge(extra)
end
```

## Commands

```bash
# Run all specs
bundle exec rspec

# Run specific file
bundle exec rspec spec/models/subscription_spec.rb

# Run specific line
bundle exec rspec spec/models/subscription_spec.rb:15

# Run with documentation format
bundle exec rspec --format documentation

# Run only failures
bundle exec rspec --only-failures

# Run with coverage
COVERAGE=true bundle exec rspec
```

## Coverage Target

Minimum **80% line coverage**, enforced by SimpleCov (`spec/spec_helper.rb`). Coverage runs automatically in CI and on-demand locally:

```bash
COVERAGE=true bundle exec rspec   # generates coverage/index.html
open coverage/index.html          # detailed report (line + branch)
```

Branch coverage is tracked but not enforced as a minimum (yet).

## What NOT to Test

- Rails internals (trust the framework)
- Third-party gems (trust their test suite)
- Simple delegations (`delegate :name, to: :organization`)
- Private methods directly — test through the public interface
