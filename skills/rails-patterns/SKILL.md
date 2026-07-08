---
name: rails-patterns
description: "Conventions Rails génériques (nommage, modèles, controllers, style Ruby, error handling, temps, linting) ET routeur de choix de pattern : quel pattern écrire pour quel besoin (controller direct, méthode de modèle, interactor, query object, form object, state machine, vue). À utiliser pour créer n'importe quel fichier Rails ou pour décider où placer une logique."
globs:
  - "app/**/*.rb"
---

# Rails Patterns Skill

Cette skill est le **socle** des conventions Ruby/Rails génériques **et le routeur** qui oriente vers le bon pattern. Commencer par « Choisir un pattern » pour décider *quoi écrire*, puis appliquer les conventions génériques ci-dessous.

## Choisir un pattern

Table de décision *orientée écriture* (« quel pattern écrire »). Complémentaire de la table *navigation* de la skill `explore-rails` (« où est X »).

| Besoin | Pattern | Skill |
|---|---|---|
| Action triviale / CRUD scaffold | Logique **directement dans le controller** | *(ce fichier, § Controllers)* |
| Une étape simple, liée à une entité | **Méthode de modèle** (YAGNI, pas de sur-abstraction) | `principles` |
| Logique métier **au-dessus du scaffold** (multi-étapes, orchestration) | **Organizer + Interactor** (`app/interactors/`), même pour un seul interactor | `interactors` |
| Requête complexe (filtres conditionnels, recherche, jointures) | **Query Object** (`app/queries/`) | `query-objects` |
| Formulaire multi-champs / validation hors modèle | **Form Object** (`app/forms/`) | `form-objects` |
| Cycle de vie / états contraints d'une ressource | **State Machine (AASM)** | `state-machine` |
| Rendu, formulaire DSFR, interactions client | Vues / Turbo / Stimulus | `frontend-rails`, `hotwire` |
| Client API externe / adapter d'infrastructure | Module dans `lib/<client>/` | `api-client`, `authentication` |

**Le seuil central est la complexité, pas le nombre d'étapes.** Tant qu'on reste au niveau d'un scaffold (CRUD direct, une ou deux lignes triviales), la logique reste dans le controller. Dès qu'on le dépasse, on bascule vers le pattern dédié sans attendre d'avoir « assez » de matière pour le justifier — en particulier, on passe en organizer + interactor dès la première étape métier non triviale, pas de service object PORO ad-hoc.

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

> **Cycle de vie / états contraints** (transitions entre statuts) : ne pas empiler des `update` libres, modéliser avec AASM → skill `state-machine`.

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

Dès que la logique d'une action dépasse le scaffold, elle sort du controller — voir « Choisir un pattern » ci-dessus.

## Résolution des constantes namespacées

Une constante relative se résout lexicalement, de l'intérieur vers l'extérieur : depuis `module Users`, `Shared::X` désigne `Users::Shared::X` s'il existe, sinon Ruby remonte jusqu'à la racine et trouve `::Shared::X`. Si les deux existent, c'est le plus proche qui gagne — pour viser explicitement un niveau supérieur, écrire le chemin complet (`HubEE::Shared::X`).

Avec Zeitwerk (Rails 6+), cette résolution est **déterministe** : les `autoload` sont enregistrés d'avance, une constante est visible avant d'être chargée. C'est le classic autoloader (avant Rails 6) qui pouvait résoudre vers la mauvaise constante homonyme selon l'ordre de chargement — ce problème n'existe plus.

## Error handling

### Rescue scope

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

### Ne pas imbriquer les blocks

Un block dans un block noie l'intention. **Deux niveaux d'imbrication au maximum, jamais trois** (StandardRB ne le voit pas — cops `Metrics/*` désactivés —, c'est à nous de tenir la règle). Et même à deux niveaux, on allège :

- **Minimum** : un `do…end` sur le block externe, pour que l'imbrication saute aux yeux.
- **Mieux** : extraire le block interne dans une **méthode nommée** par intention, qui fait disparaître l'imbrication.

```ruby
# ❌ deux blocks imbriqués en accolades — intention noyée
users.each { |u| u.roles.each { |r| grants << Grant.new(user: u, role: r, scope: default_scope(u)) } }

# ✅ acceptable — do…end externe, l'imbrication est lisible
users.each do |u|
  u.roles.each { |r| grants << Grant.new(user: u, role: r, scope: default_scope(u)) }
end

# ✅✅ mieux — le block interne devient une méthode
users.each { |u| grant_all_roles(u) }

def grant_all_roles(user)
  user.roles.each { |role| grants << Grant.new(user:, role:, scope: default_scope(user)) }
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
