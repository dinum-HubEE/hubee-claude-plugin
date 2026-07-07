---
name: rails-patterns
description: Conventions Rails : modèles, controllers, interactors (logique métier). À utiliser pour créer des modèles, des controllers ou des fonctionnalités Rails.
globs:
  - "app/models/**/*.rb"
  - "app/controllers/**/*.rb"
  - "app/services/**/*.rb"
  - "app/interactors/**/*.rb"
---

# Rails Patterns Skill

## Conventions de nommage

```ruby
# Classes — PascalCase
class UserSubscription; end

# Methods / variables — snake_case
def calculate_total
  user_count = 42
end

# Constants — SCREAMING_SNAKE_CASE
MAX_RETRY_COUNT = 3

# Predicates — end with ?
def active?; end

# Dangerous methods — end with !
def destroy!; end
```

### Méthodes de classe

Déclarer les méthodes de classe dans un bloc `class << self` (toujours, même pour une seule), avec la visibilité (`private`/`public`) regroupée dans le bloc.

```ruby
class Foo
  class << self
    def build = new

    private

    def default_options = {}
  end
end
```

## Conventions de modèles

### Structure standard d'un modèle

```ruby
class Subscription < ApplicationRecord
  # === Constants ===
  STATUSES = %w[pending active suspended cancelled].freeze

  # === Associations ===
  belongs_to :organization
  belongs_to :process
  has_many :events, dependent: :destroy

  # === Validations ===
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :organization_id, uniqueness: { scope: :process_id }

  # === Scopes ===
  scope :active, -> { where(status: "active") }
  scope :by_organization, ->(org_id) { where(organization_id: org_id) }
  scope :recent, -> { order(created_at: :desc) }

  # === Callbacks (à utiliser avec parcimonie) ===
  after_create :notify_organization

  # === Méthodes de classe ===
  def self.for_dashboard
    includes(:organization, :process).active.recent.limit(10)
  end

  # === Méthodes d'instance ===
  def activate!
    update!(status: "active", activated_at: Time.current)
  end

  def display_name
    "#{organization.name} - #{process.name}"
  end

  private

  def notify_organization
    NotificationJob.perform_later(id)
  end
end
```

> **Valeur à liste fermée** (`select`, `enum`) : préférer `validates inclusion:` (erreur explicite) au filtrage silencieux — l'utilisateur doit savoir que sa saisie est rejetée, pas la voir disparaître.

### State Machine (AASM)

```ruby
class Subscription < ApplicationRecord
  include AASM

  aasm column: :status do
    state :pending, initial: true
    state :active
    state :suspended
    state :cancelled

    event :activate do
      transitions from: :pending, to: :active
      after { self.activated_at = Time.current }
    end

    event :suspend do
      transitions from: :active, to: :suspended
    end

    event :cancel do
      transitions from: %i[active suspended], to: :cancelled
    end
  end
end
```

## Conventions de controllers

### Controller RESTful

```ruby
class SubscriptionsController < ApplicationController
  before_action :set_subscription, only: %i[show edit update destroy]

  def index
    @subscriptions = policy_scope(Subscription)
      .includes(:organization, :process)
      .page(params[:page])
  end

  def show
    authorize @subscription
  end

  def new
    @subscription = Subscription.new
    authorize @subscription
  end

  def create
    @subscription = Subscription.new(subscription_params)
    authorize @subscription

    if @subscription.save
      redirect_to @subscription, notice: t(".success")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @subscription
  end

  def update
    authorize @subscription

    if @subscription.update(subscription_params)
      redirect_to @subscription, notice: t(".success")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @subscription
    @subscription.destroy
    redirect_to subscriptions_path, notice: t(".success")
  end

  private

  def set_subscription
    @subscription = Subscription.find(params[:id])
  end

  def subscription_params
    params.require(:subscription).permit(:organization_id, :process_id, :notes)
  end
end
```

## Form objects

Un form object ne porte que ce qui **pilote l'opération**. Faire transiter une donnée purement d'**affichage**, redondante avec un identifiant déjà présent, est un smell : deux infos pour une même entité → risque de désync et état UI modélisé côté serveur.

```ruby
# Contexte : le SIRET identifie l'organisation ; le serveur re-résout le nom
# via HubApi::Organization.find. organization_name ne sert qu'à un message.

# ❌ le nom (affichage) transite et est validé alors qu'il est redondant
#    avec le SIRET, seul identifiant réellement nécessaire pour créer l'objet
validates :siret, presence: true, unless: -> { organization_name.present? }
validate  :organization_selected   # vérifie la cohérence du couple nom + siret

# ✅ le SIRET identifie l'organisation ; sa présence suffit côté serveur.
#    Le nom reste une aide de saisie côté front (Stimulus), non soumise.
validates :siret, presence: true
```

Corollaire : un champ qui ne sert qu'à l'UX côté client se rend **non soumis** plutôt que permis puis ignoré (voir skill `build-fix`, params soumis mais non permis).

## Interactors & Organizers (logique métier)

La logique métier multi-étapes utilise la gem [interactor](https://github.com/collectiveidea/interactor) (`gem "interactor"`). Pas de service objects PORO ad-hoc pour la logique métier.

**Frontière — où mettre la logique ?**
- ✅ Une étape simple → méthode de modèle (YAGNI, voir skill `principles`)
- ✅ Scaffold, ou complexité de niveau scaffold → code directement dans le controller
- ✅ Au-dessus du scaffold → Organizer + Interactors dans `app/interactors/`, **même s'il n'y a qu'un seul interactor** (on passe alors automatiquement en organizer + interactor, pas de PORO ni de logique gonflée dans le controller)
- ✅ Client API externe / adapter d'infrastructure → `app/services/<service>/` (voir skills `api-client` et `authentication`)

Le seuil de bascule est la complexité : tant qu'on reste au niveau d'un scaffold (CRUD direct, une ou deux lignes triviales), la logique reste dans le controller. Dès qu'on le dépasse, on bascule en organizer + interactor sans attendre d'avoir « assez » d'étapes pour le justifier.

### Organizer

Un organizer orchestre des interactors atomiques, exécutés dans l'ordre. Il ne contient aucune logique lui-même.

```ruby
# app/interactors/data_packages/transmit.rb
module DataPackages
  class Transmit
    include Interactor::Organizer

    organize Transmit::ValidateTransmission,
      Transmit::ResolveRecipients,
      Transmit::CreateNotifications,
      Transmit::TransitionToTransmitted
  end
end
```

### Interactor

Chaque interactor = une étape atomique. Le `context` transporte les données entre étapes ; `context.fail!` interrompt la chaîne.

```ruby
# app/interactors/data_packages/transmit/validate_transmission.rb
module DataPackages
  class Transmit
    class ValidateTransmission
      include Interactor

      def call
        context.fail!(error: :not_draft) unless data_package.draft?
        context.fail!(error: :no_completed_attachments) unless data_package.has_completed_attachments?
      end

      private

      def data_package
        context.data_package
      end
    end
  end
end
```

### Nommage & namespaces

Le nommage se déduit du controller, et l'on nomme par **intention** (ce que l'étape veut faire), jamais par mécanique interne.

- **Organizer** : son namespace reflète le controller, **namespace du controller inclus**. `[Namespace::]Ressource::Action` = `[Namespace::]RessourceController#action`.
  - `UsersController#create` → `Users::Create` dans `app/interactors/users/create.rb`.
  - `Api::UsersController#create` → `Api::Users::Create` dans `app/interactors/api/users/create.rb`.
- **Interactors** : namespacés sous leur organizer. Chaque étape vit sous `<Organizer>::`.
  `app/interactors/users/create/validate_form.rb` → `Users::Create::ValidateForm`.
- **Noms par intention** : `ValidateForm`, `ResolveOrganization`, `UpdateHubApiSubscription` — l'intention métier, pas le comment.

### Partage — pas de duplication d'intention

Deux organizers qui ont besoin de la même intention ne dupliquent pas l'étape : on la partage sous un sous-namespace `shared`, **remonté au premier niveau qui couvre tous les usages**.

- Entre plusieurs actions d'une même ressource → `<Ressource>::Shared::<Étape>` dans `app/interactors/<ressource>/shared/`.
- Entre plusieurs ressources d'un même namespace → `<Namespace>::Shared::<Étape>` dans `app/interactors/<namespace>/shared/`.
- Transverse à plusieurs namespaces de premier niveau (ex. `Api` + `PortailV2`) → namespace global `HubEE::Shared::<Étape>` dans `app/interactors/hubee/shared/`.
- La racine nue `Shared::<Étape>` (`app/interactors/shared/`) n'est admise que si l'app n'a **aucun** namespace de premier niveau significatif. Dès qu'il en existe, le global passe par `HubEE::Shared`.

```ruby
# Subscriptions::Create et Subscriptions::Update ont tous deux besoin de résoudre l'organisation.
# app/interactors/subscriptions/shared/resolve_organization.rb
module Subscriptions
  module Shared
    class ResolveOrganization
      include Interactor

      def call
        context.organization = HubApi::Organization.find(context.siret)
      rescue HubApi::Client::Error
        context.fail!(error: :organization_not_found)
      end
    end
  end
end
```

❌ Recopier une intention quasi identique sous deux namespaces d'action (`Subscriptions::Create::ResolveOrganization` **et** `Subscriptions::Update::ResolveOrganization`) : c'est le signal d'un `Shared` à extraire.

Dans l'`organize`, référence l'étape partagée par sa constante depuis l'organizer.

```ruby
module Subscriptions
  class Update
    include Interactor::Organizer

    organize Update::ValidateForm,
      Shared::ResolveOrganization,
      Update::SaveAuditTrail,
      Update::UpdateHubApiSubscription
  end
end
```

### Rollback

`rollback` est appelé sur les étapes déjà réussies (en ordre inverse) quand une étape **suivante** fait `context.fail!` — pas sur une exception levée, d'où le pattern `rescue` ⇒ `fail!`. À définir sur les étapes qui écrivent localement :

```ruby
def call
  context.notifications = create_notifications
end

def rollback
  context.notifications.each(&:destroy)
end
```

**API externe : jamais de rollback compensatoire.** Une compensation s'exécute dans le chemin d'échec, là où l'API vient de flancher — elle a toutes les chances d'échouer aussi. À la place, une règle d'ordonnancement :

> **Ordonner les étapes par irréversibilité croissante** — rien de non-rejouable n'a d'étape après lui.

- **Étapes locales d'abord** : rollbackables de façon fiable.
- **Puis les calls externes rejouables** : update (PUT complet, idempotent par nature), `find_or_create`, create avec rescue du conflit (`ConflictError`…) qui retrouve l'existant par sa clé naturelle au lieu de doublonner. Ils peuvent être suivis d'autres étapes : si l'une échoue, on ré-exécute l'organizer entier — les étapes déjà faites no-op ou repoussent à l'identique, les manquantes tournent enfin.
- **L'éventuel call non-rejouable en dernier** : rien après lui → aucun état partiel externe possible, aucune compensation à écrire. Deux non-rejouables dans la même opération = signal de conception : en rendre un rejouable, ou découper l'opération.

```ruby
module Subscriptions
  class Update
    include Interactor::Organizer

    organize Update::ValidateForm,        # local — pur calcul
      Shared::ResolveOrganization,        # externe en lecture — rejouable
      Update::SaveAuditTrail,             # local — rollbackable
      Update::UpdateHubApiSubscription    # externe — en dernier, pas de rollback
  end
end
```

```ruby
# app/interactors/subscriptions/update/update_hub_api_subscription.rb
module Subscriptions
  class Update
    class UpdateHubApiSubscription
      include Interactor

      # Pas de rollback : une compensation échouerait pour les mêmes raisons que
      # le call (réseau, 5xx). Son échec fait fail! → rollback des étapes locales
      # → retour à l'état initial. Et le PUT complet est idempotent : ré-exécuter
      # l'organizer repousse le même payload, sans effet de bord.
      def call
        HubApi::Subscription.update(id: context.subscription_id, payload: context.form.to_payload)
      rescue HubApi::Client::ServerError => e
        Rails.logger.error("Subscription update failed for #{context.subscription_id}: #{e.message}")
        context.fail!(error: :api_unavailable)   # transitoire — un rejeu peut réussir
      rescue HubApi::Client::Error => e
        Rails.logger.error("Subscription update rejected for #{context.subscription_id}: #{e.message}")
        context.fail!(error: :update_rejected)   # 4xx — rejouer redonnerait le même refus
      end
    end
  end
end
```

**Comment se rejoue l'organizer.** Le rejeu n'est pas un mécanisme à part : c'est ré-appeler `.call` avec les **mêmes entrées**. Deux déclencheurs selon le contexte :

```ruby
# Action interactive : l'échec ré-affiche le formulaire, la resoumission EST le
# rejeu. Suffisant si un humain est là et que l'état partiel peut attendre.
def update
  result = Subscriptions::Update.call(subscription_id: params[:id], form: @subscription_form)

  if result.success?
    redirect_to edit_subscription_path(params[:id]), notice: t(".success")
  else
    flash.now[:alert] = t(".#{result.error}")
    render :edit, status: :unprocessable_content
  end
end
```

```ruby
# Complétion à garantir (webhook, batch — personne pour resoumettre) : job qui
# rejoue jusqu'au succès. `.call` avale le fail! → re-lever pour armer retry_on.
# Ne re-lever que l'erreur transitoire (:api_unavailable) : rejouer un refus
# métier (4xx) redonnerait le même refus.
class UpdateSubscriptionJob < ApplicationJob
  retry_on HubApi::Client::ServerError, wait: :polynomially_longer, attempts: 10

  def perform(subscription_id, form_params)
    form = SubscriptionForm.new(form_params)
    result = Subscriptions::Update.call(subscription_id:, form:)
    return if result.success?
    raise HubApi::Client::ServerError, result.error.to_s if result.error == :api_unavailable

    Rails.logger.error("Subscription update #{subscription_id} abandonné : #{result.error}")
  end
end
```

Dans les deux cas, c'est la **rejouabilité des étapes** qui rend le rejeu sûr — le déclencheur ne fait que ré-exécuter.

**Persister l'ID externe en local.** Le write local qui suit un call externe crée une fenêtre « créé chez l'API, non enregistré chez nous ». Elle est bénigne si l'ID est re-dérivable par clé naturelle (SIRET + code démarche…) : au rejeu, le rescue du conflit re-cherche la ressource et récupère l'ID. Logger l'ID externe avant le save local, pour que l'état reste corrigeable même sans rejeu.

Si une écriture n'est ni rejouable ni plaçable en dernier : pas de compensation pour autant — logger avec le contexte et laisser corriger manuellement, en documentant ce choix dans le code.

### Usage dans un controller

`context.fail!(error: :symbol)` passe un symbole via la clé de contexte `error:`, lisible directement par `result.error` (le `context` se comporte comme un OpenStruct, pas besoin de `result.context`). C'est au controller de traduire ce symbole en message utilisateur/API, jamais à l'interactor.

```ruby
def create
  result = DataPackages::Transmit.call(data_package: @data_package)

  if result.success?
    render "api/v1/data_packages/show", status: :ok
  else
    render json: error_response(result.error), status: :unprocessable_content
  end
end
```

Exemple complet de traduction côté controller (form HTML, mais la même table sert un rendu JSON) :

```ruby
# app/controllers/subscriptions_controller.rb
INTERACTOR_ERRORS = {
  organization_not_found: {field: :siret, key: "users.shared.organization_not_found"},
  user_exists:            {field: :email, key: "users.create.user_exists"},
  create_api_error:       {field: :base,  key: "users.create.api_error"}
}.freeze

def create
  result = Users::Create.call(user_form: @form)

  if result.success?
    redirect_to users_path, notice: t(".success")
  else
    apply_interactor_error(result)
    render :new, status: :unprocessable_content
  end
end

private

def apply_interactor_error(result)
  mapping = INTERACTOR_ERRORS.fetch(result.error)
  @form.errors.add(mapping[:field], t(mapping[:key]))
end
```

❌ **Anti-pattern** : muter `context.user_form.errors.add(...)` directement dans l'interactor pour aller plus vite. Ça couple la logique métier à la présentation et retire au controller la responsabilité de traduire l'échec — l'interactor ne connaît que des symboles, jamais des messages.

### Specs

Un fichier de spec par interactor et par organizer (`spec/interactors/...`).

```ruby
RSpec.describe DataPackages::Transmit::ValidateTransmission do
  describe ".call" do
    subject(:result) { described_class.call(data_package:) }

    context "when package is not draft" do
      let(:data_package) { create(:data_package, :transmitted) }

      it { is_expected.to be_failure }

      it "returns not_draft error" do
        expect(result.error).to eq(:not_draft)
      end
    end
  end
end
```

**Règles** :
- ✅ Nommage déduit du controller, **namespace inclus** : organizer `[Namespace::]<Ressource>::<Action>` = `[Namespace::]<Ressource>Controller#<action>`, noms d'étapes par intention
- ✅ Arborescence : `app/interactors/[<namespace>/]<ressource>/<action>.rb` (organizer) + `.../<action>/<étape>.rb` (steps) — interactor toujours namespacé sous son organizer
- ✅ Étape partagée → sous-namespace `shared` remonté au premier niveau couvrant tous les usages (ressource → namespace → global `HubEE`, racine nue seulement sans namespace de premier niveau), pas de duplication d'une même intention
- ✅ Bascule en organizer + interactor dès qu'on dépasse la complexité d'un scaffold, même pour un seul interactor
- ✅ Étapes ordonnées par irréversibilité croissante : locales (rollbackables) d'abord, calls externes rejouables ensuite, l'éventuel non-rejouable en dernier — jamais de rollback compensatoire vers une API externe, le rejeu de l'organizer est la récupération
- ✅ Erreurs symboliques : `context.fail!(error: :not_draft)` — le controller traduit en message utilisateur/API
- ✅ Specs : `described_class.call(...)`, matchers `be_success` / `be_failure`, vérifier `result.error`
- ❌ Pas de service object PORO pour la logique métier (les `app/services/` existants sont des adapters API)
- ❌ Pas de logique métier dans l'organizer (il ne fait qu'`organize`)

## Résolution des constantes namespacées

Une constante relative se résout lexicalement, de l'intérieur vers l'extérieur : depuis `module Users`, `Shared::X` désigne `Users::Shared::X` s'il existe, sinon Ruby remonte jusqu'à la racine et trouve `::Shared::X`. Si les deux existent, c'est le plus proche qui gagne — pour viser explicitement un niveau supérieur, écrire le chemin complet (`HubEE::Shared::X`).

Avec Zeitwerk (Rails 6+), cette résolution est **déterministe** : les `autoload` sont enregistrés d'avance, une constante est visible avant d'être chargée. C'est le classic autoloader (avant Rails 6) qui pouvait résoudre vers la mauvaise constante homonyme selon l'ordre de chargement — ce problème n'existe plus.

## Rescue scope

Garder le rescue au plus proche de la ligne qui peut lever l'exception. Si l'action API est au milieu d'une méthode, l'extraire dans une méthode privée avec son propre rescue.

```ruby
# ✅ Rescue isolé sur l'appel API
def autocomplete
  @records = fetch_autocomplete_records(params[:q].to_s.strip)
end

private

def fetch_autocomplete_records(query)
  return [] if query.length < MIN_LENGTH
  HubApi::Organization.search(name: query).records
rescue HubApi::Client::Error
  []
end

# ❌ Rescue qui englobe du code qui ne peut pas lever cette erreur
def autocomplete
  query = params[:q].to_s.strip
  @records = if query.length >= MIN_LENGTH
    HubApi::Organization.search(name: query).records
  else
    []
  end
rescue HubApi::Client::Error
  @records = []
end
```

### Double filet nil

Quand les appelants gardent déjà contre nil avec `x && f(x)`, un `rescue TypeError` dans la fonction
ne peut jamais être atteint. C'est du code mort.

Pour les fonctions utilitaires de robustesse (préfixe `safe_`, parsers, formateurs), la fonction est
défensive : elle accepte nil, et on retire les `&&` chez tous les appelants. C'est leur contrat :
absorber toute entrée sans exploser.

```ruby
# ❌ double filet — rescue TypeError inatteignable, && superflus
item["started_at"] && safe_parse_time(item["started_at"])

def safe_parse_time(str)
  Time.zone.parse(str)
rescue ArgumentError, TypeError   # TypeError ne peut jamais être levé ici
  nil
end

# ✅ la fonction est défensive, les appelants s'en remettent à elle
safe_parse_time(item["started_at"])

def safe_parse_time(str)
  Time.zone.parse(str)
rescue ArgumentError, TypeError
  nil
end
```

## Display methods pour données API externes

Quand on affiche des données issues d'une API externe, traiter tous les champs de façon identique : implémenter des méthodes `display_*` avec fallback pour chaque champ, sans conditions asymétriques.

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

## Fonctions pures

Quand une méthode est une fonction générique (parser, formateur, utilitaire de robustesse) sans lien
avec la logique métier d'un objet particulier, la déclarer avec `def self.` dans un module. Ce type
de logique n'appartient à aucune instance — l'exposer via `include` lui prête une appartenance
qu'elle n'a pas.

```ruby
# ❌ mixée par include — le spec doit instancier une classe fantôme
module HubApi::TimeParser
  def safe_parse_time(str) = ...
end
# spec : Class.new { include HubApi::TimeParser }.new.safe_parse_time("...")

# ✅ fonction de module — appelable directement
module HubApi
  module TimeParser
    def self.parse(str)
      Time.zone.parse(str)
    rescue ArgumentError
      nil
    end
  end
end
# spec    : HubApi::TimeParser.parse("2024-13-01")
# appelant: HubApi::TimeParser.parse(item["started_at"])
```

## Query Objects

Pour les requêtes complexes :

```ruby
# app/queries/subscriptions_query.rb
class SubscriptionsQuery
  def initialize(relation = Subscription.all)
    @relation = relation
  end

  def call(params = {})
    result = @relation
    result = filter_by_status(result, params[:status])
    result = filter_by_organization(result, params[:organization_id])
    result = search(result, params[:q])
    result.includes(:organization, :process)
  end

  private

  def filter_by_status(relation, status)
    return relation if status.blank?
    relation.where(status: status)
  end

  def filter_by_organization(relation, org_id)
    return relation if org_id.blank?
    relation.where(organization_id: org_id)
  end

  def search(relation, query)
    return relation if query.blank?
    relation.joins(:organization)
      .where("organizations.name ILIKE ?", "%#{query}%")
  end
end
```

## Réaffectation de variables et chaînage de méthodes

### Éviter de réaffecter la même variable à des valeurs successives

Préférer le chaînage ou l'extraction d'une méthode privée — la réaffectation successive rend le flux de données difficile à suivre.

```ruby
# ❌ users réaffecté, le flux de données est difficile à suivre
users = cached_organization_users.select { |u| u.has_process_access?(code) }
users = users.select { |u| u.email&.start_with?(query) } if query

# ✅ chaîné, flux linéaire
cached_organization_users
  .select { |u| u.has_process_access?(code) }
  .select { |u| query.blank? || u.email&.start_with?(query) }
```

### Chaîner plutôt que stocker des résultats intermédiaires

```ruby
# ❌ variables intermédiaires inutiles
filtered = subscriptions.select(&:active?)
names = filtered.map(&:name)
result = names.sort

# ✅ chaîné
subscriptions.select(&:active?).map(&:name).sort
```

### Chaînage conditionnel via `.then` ou des méthodes privées

```ruby
# ❌ condition qui réaffecte
result = collection.select { |x| x.valid? }
result = result.first(10) if paginate?

# ✅ méthode privée nommée
def filtered_collection
  collection
    .select(&:valid?)
    .then { |r| paginate? ? r.first(10) : r }
end
```

## Temps et fuseaux horaires

Utiliser `Time.current` partout, jamais `Time.now` qui ignore `config.time_zone` de Rails.

```ruby
# ❌ Time.now — retourne l'heure système, ignore le fuseau Rails
Time.now

# ✅ Time.current — respecte config.time_zone
Time.current
```

En test, figer le temps avec `travel_to` plutôt qu'en dépendre.

## Linting

StandardRB est l'unique source de vérité (pas de RuboCop, pas de débats). Le hook `post-edit-standardrb` du plugin le lance automatiquement après chaque Edit sur un fichier `.rb`.

```bash
# Vérification / correction manuelle
bundle exec standardrb
bundle exec standardrb --fix
```
