---
name: tdd-workflow
description: Méthodologie TDD et conventions de tests RSpec HubEE. À utiliser pour écrire des tests ou des specs, créer des fonctionnalités en TDD, ou déboguer des échecs de tests.
globs:
  - "spec/**/*.rb"
  - "spec/factories/**/*.rb"
  - "spec/support/**/*.rb"
---

> **Complète `superpowers:test-driven-development`** : son cycle RED-GREEN-REFACTOR s'applique tel quel ; cette skill ajoute uniquement les conventions de tests HubEE décrites ci-dessous.

# TDD & conventions de tests HubEE

## Langue : descriptions de tests en anglais

Toutes les descriptions `describe` / `context` / `it` DOIVENT être en **anglais**, même si le reste du projet (commits, MRs, commentaires) reste en français. Les specs sont la seule surface obligatoirement en anglais.

```ruby
# ❌
it "marche"
it "should return true"
it "test la création"

# ✅
it "returns true when organization is active"
it "creates a subscription with valid params"
it "displays error for invalid SIRET"
```

## Exemples RSpec

### Specs de modèle

```ruby
RSpec.describe Organization, type: :model do
  # shoulda-matchers pour les validations
  describe "validations" do
    it { is_expected.to validate_presence_of(:siret) }
    it { is_expected.to validate_uniqueness_of(:siret) }
  end

  # shoulda-matchers pour les associations
  describe "associations" do
    it { is_expected.to have_many(:subscriptions) }
    it { is_expected.to belong_to(:parent).optional }
  end

  # Tester les méthodes métier
  describe "#full_name" do
    subject(:org) { build(:organization, siret: "123", name: "Test") }

    it "combines siret and name" do
      expect(org.full_name).to eq("123 - Test")
    end
  end
end
```

### Specs de requête

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

**Assertions HTML : `Capybara.string` + matchers sémantiques, pas regex/string brute.** Préférer `Capybara.string(response.body)` + `have_field` / `have_checked_field` / `have_unchecked_field` / `have_link` / `have_css` à `match(/regex/)`, `include("<html…>")` ou `Nokogiri + at_css(...)["attr"]` : le matcher exprime l'**intention** et échoue lisiblement.

```ruby
# ❌ regex/string fragile                    # ✅ matcher sémantique
match(/name="user\[active\]".*checked/)   →  have_checked_field("user[active]")
include('<a href="/users/42">')           →  have_link("Voir", href: "/users/42")
Nokogiri::HTML(b).at_css("#x")["value"]   →  have_field("user[email]", with: "a@b.fr")
```

Trois nuances :
- **Capybara pour l'intention, Nokogiri/CSS pour l'ordre/structure DOM.** Nokogiri reste légitime quand on teste une *position* (`thead th:first-child`, ordre des colonnes), pas une intention métier. Ne pas sur-appliquer Capybara.
- **`visible: :all` inutile en request spec, requis en system spec.** `Capybara.string` analyse du HTML statique sans CSS → les inputs masqués DSFR ne sont pas « hidden ». En system spec (vrai navigateur + CSS DSFR), ils le sont → `visible: :all` requis.
- **`have_unchecked_field` > `not_to match(/checked/)`** : le matcher exige présence **et** état. L'ancienne regex passait à vide si l'élément était absent (faux positif).

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

## Conventions de test HubEE

### Pas de date absolue future codée en dur

Ne jamais coder en dur une date absolue dans le futur (ex: `Date.new(2027, 1, 1)`) : elle finira par être dans le passé et le test deviendra flaky à l'échéance. Utiliser une date **relative** (`1.year.from_now`) ou figer le temps avec `travel_to`. Réflexe : « cette date sera-t-elle toujours dans le futur quand le test tournera dans 1 an ? ».

```ruby
# ❌ périmera
build(:subscription, expires_at: Date.new(2027, 1, 1))

# ✅ relative
build(:subscription, expires_at: 1.year.from_now)

# ✅ ou temps figé si une date précise est nécessaire
travel_to Date.new(2026, 6, 8) do
  expect(build(:subscription, expires_at: Date.new(2026, 1, 1))).not_to be_valid
end
```

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

### Form specs : shoulda-matchers sans `type: :model`

Les form objects vivent dans `spec/forms/`. Ne pas déclarer `type: :model` pour obtenir les shoulda-matchers — un form object n'est pas un modèle ActiveRecord. Inclure les matchers directement dans le `describe` :

```ruby
# ❌ type sémantiquement faux, vestige de spec/models/
RSpec.describe UserForm, type: :model do

# ✅ include ciblé, sans polluer le type
RSpec.describe UserForm do
  include Shoulda::Matchers::ActiveModel
```

### Espaces superflus : tester dans les form specs

Les cas d'espaces (strip avant validation de longueur) se testent dans les specs du form object, pas dans les request specs. La request spec garde un seul cas représentatif pour valider l'intégration.

```ruby
# Dans search_form_spec.rb
describe "name normalization" do
  it "strips surrounding whitespace before checking length" do
    expect(described_class.new(name: "  ab  ")).not_to be_valid   # 2 utiles
    expect(described_class.new(name: "  a bb c  ")).to be_valid   # 7 utiles
  end
end
```

### `expect` plutôt que `allow` — sans exception

`allow` autorise un appel sans garantir qu'il a lieu. Si le stub est important, c'est que l'appel a lieu — donc `expect`. La règle est absolue :

- `expect(...).to receive(...)` → l'appel doit avoir lieu
- `expect(...).not_to receive(...)` → l'appel est interdit
- `allow` → jamais

```ruby
# ❌ allow : le lecteur ne sait pas si l'appel a réellement lieu
before do
  allow(conn).to receive(:execute).with(query)
end
it { expect(conn).to have_received(:execute).with(query) }

# ❌ allow pour un fake : si le fake compte, l'appel à .new compte aussi
allow(Client).to receive(:new).and_return(fake_client)

# ✅ expect avant l'action — ce qui est appelé est explicite
it "exécute la requête" do
  expect(conn).to receive(:execute).with(query)
  subject.perform_now
end

# ✅ expect pour le fake
expect(Client).to receive(:new).and_return(fake_client)

# ✅ not_to receive — échoue immédiatement si appelé
it "ne touche pas la DB en dry_run" do
  expect(conn).not_to receive(:execute)
  subject.perform_now(dry_run: true)
end
```

Pour éviter de dupliquer le setup dans chaque `it`, extraire un helper de spec plutôt que de mettre un `allow` dans un `before` partagé :

```ruby
def expect_readonly_connection
  expect(HubDb::ReadonlyRecord).to receive(:with_connection) { |&block| block.call(conn) }
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

## Commandes

```bash
bundle exec rspec                                      # tout
bundle exec rspec spec/models/subscription_spec.rb     # un fichier
bundle exec rspec spec/models/subscription_spec.rb:15  # une ligne
bundle exec rspec --only-failures                      # seulement les échecs
COVERAGE=true bundle exec rspec                         # avec coverage
```

## Objectif de couverture

Minimum **90 % de couverture de lignes et de branches**, imposé par SimpleCov (`spec/spec_helper.rb`). Tourne automatiquement en CI et à la demande en local :

```bash
COVERAGE=true bundle exec rspec   # génère coverage/index.html
```

Configuration SimpleCov pour activer les deux métriques :

```ruby
# spec/spec_helper.rb
SimpleCov.start "rails" do
  enable_coverage :branch
  minimum_coverage line: 90, branch: 90
end
```

SimpleCov mesure la couverture de branches depuis la version 0.18 — chaque `if/unless/case/&&/||` compte comme une branche. Une couverture de lignes à 100 % ne garantit pas la couverture de branches.

## Tests de frontière gem

Quand l'app consomme une gem externe (ex: `hub-api-v1`), distinguer trois niveaux :

| Niveau | Quand | Pattern |
|---|---|---|
| Erreurs réseau | 401, 403, 500 | `allow(GemClass).to receive(:method).and_raise(...)` — seul cas légitime de mock sur la classe gem |
| Contrat form→gem | À chaque `to_search_params` | Spec unitaire sur le hash exact retourné (clés ET valeurs) |
| Frontière HTTP | Tout chemin de recherche/écriture | Injecter `FakeClient`, espionner avec `and_call_original`, asserter sur les params HTTP |

La spec de frontière se rédige **avant le code** (TDD). Elle doit passer au rouge avec le code cassé, au vert après le fix.

```ruby
let(:fake_client) { HubApiV1::Testing::FakeClient.new }

before do
  fake_client.add_subscription(...)
  allow(HubApiV1::Client).to receive(:new).and_return(fake_client)
  allow(fake_client).to receive(:get_with_headers).and_call_original
end

it "transmet companyName à l'API" do
  get "/subscriptions", params: { company_name: "mairie" }

  expect(fake_client).to have_received(:get_with_headers).with(
    HubApiV1::Subscription::PATH,
    { companyName: "mairie" }   # hash complet, pas hash_including (voir règle ci-dessus)
  )
end
```

**Règle sur `hash_including`** : ne jamais le substituer au hash complet en spec de frontière — il masquerait les paramètres inattendus transmis à l'API. Justifier son usage avec un commentaire si l'exception est vraiment nécessaire.

## Ce qu'il ne faut PAS tester

- Les internes de Rails (faire confiance au framework)
- Les gems tierces (faire confiance à leur suite de tests)
- Les délégations simples (`delegate :name, to: :organization`)
- Les méthodes privées directement — tester via l'interface publique
- Les chemins inatteignables depuis les appelants réels

### Fausse couverture : tester un chemin mort

Un test peut passer sans jamais toucher le code qu'il prétend couvrir, donnant une fausse impression
de robustesse. Toujours vérifier que le cas testé peut réellement atteindre le `rescue` ou la
branche défensive depuis les appelants réels.

Exemple avec `Time.zone.parse` :

| Entrée testée | Ce qui se passe réellement |
|---|---|
| `"not-a-date"`, `""` | retourne `nil` nativement — le `rescue` n'est jamais touché |
| `nil` | lève `TypeError` — mais si tous les appelants font `&&`, chemin inatteignable |
| `"2024-13-01"` | lève `ArgumentError` — le seul vrai risque depuis une API externe |

```ruby
# ❌ teste un chemin mort (nil filtré par && chez tous les appelants)
it "returns nil for nil" do
  expect(described_class.safe_parse_time(nil)).to be_nil
end

# ✅ teste la vraie exception possible
it "returns nil for an out-of-range date string" do
  expect(described_class.safe_parse_time("2024-13-01")).to be_nil
end
```

Avant d'écrire un cas de test pour un `rescue`, se demander : **cette exception peut-elle réellement
être levée depuis les appelants réels, compte tenu des gardes existants ?**
