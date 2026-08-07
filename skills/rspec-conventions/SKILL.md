---
name: rspec-conventions
description: "Conventions d'écriture des specs RSpec HubEE (tous types) : descriptions en anglais, un cas = un it = N expects, assertions positives, let/subject, expect plutôt que allow, hash complet vs hash_including, factories FactoryBot, matrices d'état, form specs sans type:model, dates relatives, helpers, + spécificités request/system (have_http_status, Capybara, frontière gem HTTP). À utiliser pour écrire ou relire n'importe quel spec. Pour décider QUOI/OÙ tester et la couverture, voir la skill test-strategy."
globs:
  - "spec/**/*.rb"
  - "spec/factories/**/*.rb"
  - "spec/support/**/*.rb"
---

> Pour décider **quoi/où** tester et la couverture (ce qu'il ne faut pas tester, niveaux de frontière gem, organizer/step, objectif SimpleCov) → skill `test-strategy`.

# Conventions d'écriture RSpec HubEE

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

### Un cas = un `it` = N expects

Un scénario ne se découpe pas en plusieurs `it` : **un cas = un `it`** contenant autant d'`expect` que nécessaire. Fractionner artificiellement un même cas en plusieurs `it` (un `expect` chacun) fragmente la lecture et multiplie le setup.

> Déclinaison request spec (chaque `it` qui asserte sur le body inclut `have_http_status` + une assertion positive, les `it` sans rendu en sont exemptés) : voir § « Request & system specs ».

### Assertions : asserter positivement sur ce que produit le code

Asserter d'abord **positivement** sur ce que le code produit (valeur retournée, enregistrement créé, contenu rendu). Une assertion négative (`not_to`) vient en **complément**, jamais seule : « ça ne contient pas X » ne dit pas ce que la sortie contient réellement. Exception : si la sortie ne révèle rien de significatif à asserter positivement, une assertion négative seule est tolérée, mais un commentaire doit expliquer l'exception au relecteur.

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

### `expect` plutôt que `allow`

> **Règle validée en pratique — ne pas assouplir.** Elle a fait détecter un échange de code OIDC stubbé en `allow` qui masquait le contrat réel (parcours d'authentification ProConnect, `datagouv/hubee`).

`allow` autorise un appel sans garantir qu'il a lieu. Si le stub est important, c'est que l'appel a lieu — donc `expect` :

- `expect(...).to receive(...)` → l'appel doit avoir lieu
- `expect(...).not_to receive(...)` → l'appel est interdit
- `allow` → jamais, **sauf** dans un helper de `spec/support/` inclus globalement (voir plus bas)

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

**Exception — helpers de `spec/support/` inclus globalement.** Un helper monté via `RSpec.configure { |c| c.include KeycloakStubs }` pose le décor de dizaines de specs, dont toutes n'exercent pas le chemin stubbé. En `expect`, il rendrait l'appel obligatoire et ferait échouer les specs qui ne l'empruntent légitimement pas (un formulaire re-rendu en erreur ne joint jamais Keycloak). Ces helpers-là peuvent utiliser `allow`, à trois conditions :

1. le helper vit dans `spec/support/` et est inclus globalement — un `allow` dans un `before` **local** reste proscrit ;
2. il porte un **commentaire** expliquant l'exception ;
3. les specs qui *vérifient* l'appel arment leur propre `expect(...).to receive(...)` dans le `it` — le décor global ne dispense jamais de l'expectation quand l'appel **est** le sujet du test.

```ruby
# spec/support/keycloak_stubs.rb
module KeycloakStubs
  # `allow` et non `expect` : ce helper est inclus globalement (voir spec_helper) et
  # pose le décor de specs qui n'atteignent pas toutes Keycloak — un formulaire
  # re-rendu en erreur, par exemple. Une spec qui *vérifie* l'appel arme son propre
  # expect(...).to receive(...) dans le `it`.
  def stub_keycloak_search(users: [])
    allow(Keycloak::UserClient).to receive(:search).and_return(users)
  end
end
```

Cible à tenir : **zéro `allow` hors de `spec/support/`**, et chacun de ceux qui restent commenté.

### Hash complet plutôt que `hash_including`

Quand on asserte les arguments d'un appel mocké (`have_received(...).with(...)`), **préférer le hash complet** : le contrat est explicite et tout paramètre inattendu est détecté. `hash_including` est toléré dans des cas précis (hash très verbeux, paramètres variables comme un timestamp), mais accompagné d'un commentaire qui justifie l'exception. Vaut partout où l'on espionne des arguments (services, interactors, clients d'API, request specs) — pas seulement en request spec.

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

## Conventions `let` / `subject`

Cinq règles, tirées de [l'article de référence](https://toppa.com/2026/rspec-5-rules-for-using-let-effectively/). Principe fondateur : **`let` est un outil de refactoring, pas un point de départ**, et il déclare un **objet du domaine partagé à l'identique** par tous les specs qui le voient — pas un levier pour faire varier le décor d'un contexte à l'autre.

**Violer la lettre de ces règles, c'est violer leur esprit** : « je ne surcharge que l'axe qui varie » reste une surcharge.

### 1. Inline d'abord, `let` seulement après coup (DAMP > DRY)

Écrire le setup directement dans le `it`. N'extraire en `let` qu'à partir de **3 usages identiques** avérés. On ne repère la vraie duplication qu'après avoir écrit plusieurs tests ; la duplication dans une suite de tests est **acceptable** si elle rend chaque test lisible en autonomie (DAMP — *Descriptive And Meaningful Phrases* — prime sur DRY).

Corollaire : ne pas monter une machinerie DRY (un `let` qui pilote un `before`) pour éviter de répéter trois lignes de `create`.

```ruby
# ❌ Machinerie prématurée : un let pilote la création dans un before partagé
let(:active_subscriptions_count) { 0 }
before { create_list(:subscription, active_subscriptions_count, :active, organization:) }

context "with 4 active subscriptions" do
  let(:active_subscriptions_count) { 4 }   # « mystery guest » : le lecteur remonte au before parent
  it { expect(billing_tier).to eq(:paid) }
end

# ✅ Setup inline, chaque test se lit seul
context "with 4 active subscriptions" do
  it "is paid" do
    organization = create(:organization)
    create_list(:subscription, 4, :active, organization:)

    expect(organization.billing_tier).to eq(:paid)
  end
end
```

### 2. 1 à 3 `let` par contexte (jamais plus de 5)

Limiter les helpers mémoïsés d'un contexte à 1, 2, ou éventuellement 3 déclarations. Au-delà, la lisibilité se dégrade : le lecteur doit tracer de multiples définitions pour savoir quelles données existent réellement. Si un contexte accumule les `let`, c'est le signal de les **redescendre** dans les contextes enfants qui en ont réellement besoin (voir règle 4).

### 3. Ne jamais redéfinir dans un enfant un `let` d'un contexte parent

**La règle la plus enfreinte.** Si des contextes ont besoin de valeurs différentes, chacun déclare **son propre** `let` — on ne pose **pas** un défaut au niveau parent qu'on surcharge ensuite. Un `let` signifie : « cet objet représente le même état/concept dans **tous** les specs qui suivent ». Le surcharger contredit cette promesse et éparpille les définitions sur plusieurs niveaux d'imbrication.

```ruby
# ❌ let(:params) parent surchargé dans chaque enfant — « je ne redéfinis que ce qui varie »
let(:params) { {} }
context "with a valid siret" do
  let(:params) { {search: {siret: "22770001000019"}} }   # surcharge
  ...
end
context "with an invalid siret" do
  let(:params) { {search: {siret: "123"}} }               # surcharge
  ...
end

# ✅ Chaque contexte déclare son propre params, ou l'inline dans le it
context "with a valid siret" do
  it "renders the results table" do
    get "/organizations", params: {search: {siret: "22770001000019"}}
    ...
  end
end
```

Cette règle vaut aussi pour `subject` : préférer un `subject` nommé propre à chaque contexte plutôt qu'un `subject` parent redéfini.

### 4. Les `let` d'un contexte doivent servir à TOUS ses tests

Placer chaque `let` au niveau le plus étroit où **tous** les tests l'utilisent. Un `let` défini au-dessus de tests qui ne s'en servent pas est un **mystery guest** : une donnée cachée que le relecteur doit aller chercher loin. Le descendre dans le contexte concerné isole aussi les changements (un diff ne touche que les tests réellement concernés).

Symptôme à bannir : « ce contexte s'appuie sur le défaut du parent ». Si un test ne pose pas explicitement ce dont il dépend, il ne devrait pas dépendre d'un `let` lointain.

### 5. Pas d'action dans `let` / `subject`

`let` ne sert qu'à **définir une valeur** (un objet du domaine). Tout effet de bord — créer/charger un enregistrement de façon impérative, envoyer un email, appeler un interactor — va dans un `before` ou **inline dans le `it`**, jamais dans un `let`. L'éval paresseuse rend sinon le moment d'exécution invisible : l'action ne se produit qu'au premier accès.

```ruby
# ❌ action masquée dans un let, déclenchée par effet de bord au premier accès
let(:result) { Subscriptions::Create.call(organization:, process:) }

# ✅ subject nomme l'appel, déclenché explicitement dans le it (cf. « expect plutôt que allow »)
subject(:result) { described_class.call(organization:, process:) }

it "creates the subscription and enqueues the email" do
  expect(SubscriptionMailer).to receive(:created).and_return(message)

  expect { result }.to change(Subscription, :count).by(1)   # déclenchement explicite
  expect(result).to be_a_success
end
```

> La section « `expect` plutôt que `allow` » impose déjà d'armer les expectations **avant** de déclencher l'action dans le `it` : un `before` qui appellerait le sujet s'exécuterait trop tôt. Déclencher inline est donc à la fois la règle `let` et la contrainte des message expectations.

La spec de frontière gem (§ « Request & system specs ») illustre déjà la règle : `let(:fake_client) { FakeClient.new }` est une **valeur** ; les actions (`fake_client.add_subscription(...)`) vivent dans le `before`.

### Rationalisations à rejeter

| Rationalisation | Réalité |
|---|---|
| « Je ne surcharge que l'axe qui varie, ça isole la cause » | Une surcharge reste une surcharge (règle 3). Déclarer le `let` dans chaque contexte, ou inliner. |
| « Le défaut parent garde la variation visible » | Il crée un mystery guest : le lecteur doit remonter au parent (règle 4). |
| « Un `let(:count)` + `create_list` en `before` évite de répéter » | Machinerie DRY prématurée (règle 1). Inliner tant qu'il n'y a pas 3 usages identiques. |
| « Ce contexte s'appuie sur le défaut du parent » | Un test ne doit pas dépendre d'un `let` lointain qu'il ne pose pas (règle 4). |
| « Mettre l'appel dans un `let` c'est plus concis » | L'action devient invisible et paresseuse (règle 5). `before` ou inline. |

### Red flags — STOP

- Un `let` (ou `subject`) redéfini à un niveau d'imbrication inférieur
- Plus de 3 `let` dans un même contexte
- Un `let` extrait alors qu'il n'a que 1 ou 2 usages
- Un `let` défini au-dessus de tests qui ne l'utilisent pas
- Un appel qui crée/envoie/charge enveloppé dans un `let`

## Request & system specs

Spécificités des specs qui exercent une requête HTTP et/ou rendent du HTML. Elles s'ajoutent aux conventions transverses ci-dessus.

### Chaque `it` qui asserte sur le body : `have_http_status` + assertion positive

Déclinaison de « un cas = un `it` » et « asserter positivement » : chaque `it` de request spec **qui asserte sur le body** inclut systématiquement `have_http_status` et au moins une assertion **positive** sur ce body.

**Exemption — les `it` qui n'exercent aucun rendu.** Une spec qui teste une redirection, un en-tête, un log ou un appel sortant n'a pas de body à asserter : l'assertion utile est `redirect_to`, `have_header` ou l'expectation de message, et `have_http_status(:redirect)` n'ajoute rien. Ces fichiers (specs de session, de CSP, d'authentification…) sont exemptés — **documenter l'exception en tête de fichier** pour qu'une revue ne la re-signale pas à chaque passage.

```ruby
# spec/requests/sessions_spec.rb
# Exemption « have_http_status » (skill rspec-conventions) : ce fichier n'exerce que
# des redirections OIDC — aucun rendu, donc aucune assertion sur le body.
RSpec.describe "Sessions" do
  it "redirects to the sign-in page when signed out" do
    delete "/sign_out"

    expect(response).to redirect_to(new_session_path)
  end
end
```

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

### Assertions HTML : `Capybara.string` + matchers sémantiques

**Pas de regex/string brute.** Préférer `Capybara.string(response.body)` + `have_field` / `have_checked_field` / `have_unchecked_field` / `have_link` / `have_css` à `match(/regex/)`, `include("<html…>")` ou `Nokogiri + at_css(...)["attr"]` : le matcher exprime l'**intention** et échoue lisiblement.

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

### Frontière gem : spec HTTP

> Le choix **de quel niveau teste quoi** (erreurs réseau / contrat form→gem / frontière HTTP) relève de la stratégie : voir la skill `test-strategy` § « Niveaux de test d'une frontière gem ». Cette section couvre l'**implémentation** de la spec de frontière HTTP.

La spec de frontière se rédige **avant le code** (TDD). Elle doit passer au rouge avec le code cassé, au vert après le fix.

```ruby
let(:fake_client) { HubApiV1::Testing::FakeClient.new }

before { fake_client.add_subscription(...) }

it "transmet companyName à l'API" do
  expect(HubApiV1::Client).to receive(:new).and_return(fake_client)
  expect(fake_client).to receive(:get_with_headers).with(
    HubApiV1::Subscription::PATH,
    # Hash complet, pas hash_including (voir § « Hash complet »). Les clés de
    # pagination sont injectées par le client de la gem, pas par notre code.
    { maxResult: 20, companyName: "mairie", offSet: 0 }
  ).and_call_original

  get "/subscriptions", params: { company_name: "mairie" }
end
```

**Règle sur `hash_including`** : ne jamais le substituer au hash complet en spec de frontière — il masquerait les paramètres inattendus transmis à l'API.

**Le hash complet inclut ce que le client injecte.** Une recherche paginée part avec ses clés de pagination (`maxResult`, `offSet`…) même si notre code ne les passe pas : elles viennent du client de la gem. Un hash qui les omet fait échouer l'assertion, et la tentation est alors de rebasculer sur `hash_including` — exactement ce que la règle interdit.

**Technique de la sonde** : si vous ne connaissez pas le hash réellement transmis, écrivez l'assertion avec ce que vous croyez savoir et **laissez-la échouer une fois** — le message de RSpec (`received :get_with_headers with unexpected arguments`) affiche le hash réel, à recopier tel quel. C'est le moyen le plus fiable d'écrire ces specs ; ne jamais le deviner.

## Commandes

```bash
bundle exec rspec                                      # tout
bundle exec rspec spec/models/subscription_spec.rb     # un fichier
bundle exec rspec spec/models/subscription_spec.rb:15  # une ligne
bundle exec rspec --only-failures                      # seulement les échecs
COVERAGE=true bundle exec rspec                         # avec coverage
```
