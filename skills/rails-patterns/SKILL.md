---
name: rails-patterns
description: Rails conventions, model patterns, controller patterns, service objects. Use when creating models, controllers, or Rails features.
globs:
  - "app/models/**/*.rb"
  - "app/controllers/**/*.rb"
  - "app/services/**/*.rb"
  - "app/interactors/**/*.rb"
---

# Rails Patterns Skill

## Naming conventions

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

## Model Patterns

### Standard Model Structure

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

  # === Callbacks (use sparingly) ===
  after_create :notify_organization

  # === Class Methods ===
  def self.for_dashboard
    includes(:organization, :process).active.recent.limit(10)
  end

  # === Instance Methods ===
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

## Controller Patterns

### RESTful Controller

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

## Service Objects

For complex business logic that doesn't fit in models:

```ruby
# app/services/subscription_creator.rb
class SubscriptionCreator
  def initialize(organization:, process:, user:)
    @organization = organization
    @process = process
    @user = user
  end

  def call
    Subscription.transaction do
      subscription = create_subscription
      create_event(subscription)
      notify_stakeholders(subscription)
      subscription
    end
  end

  private

  attr_reader :organization, :process, :user

  def create_subscription
    Subscription.create!(
      organization: organization,
      process: process,
      created_by: user
    )
  end

  def create_event(subscription)
    Event.create!(
      subscription: subscription,
      event_type: "created",
      user: user
    )
  end

  def notify_stakeholders(subscription)
    NotificationJob.perform_later(subscription.id)
  end
end

# Usage in controller
def create
  @subscription = SubscriptionCreator.new(
    organization: Organization.find(params[:organization_id]),
    process: Process.find(params[:process_id]),
    user: current_user
  ).call

  redirect_to @subscription
rescue ActiveRecord::RecordInvalid => e
  @subscription = e.record
  render :new, status: :unprocessable_entity
end
```

## Commentaires CSS sur les patterns réutilisables

Quand un pattern CSS est générique (combobox, autocomplete, widget partagé), commenter en listant ses usages actuels. Avec l'aide de l'IA ces commentaires restent maintenus et sont précieux pour savoir quoi retester en cas de modification.

```css
/* autocomplete : pattern de combobox réutilisable (email-autocomplete, organization-autocomplete) */
.autocomplete-wrapper { ... }
```

## Partials

### Feature-specific, pas `shared/`

Placer les partials dans le dossier de la feature qui les définit. N'utiliser `shared/` que si le partial est réellement utilisé par plusieurs features sans lien logique. Un partial "commun à deux formulaires d'une même resource" reste dans le dossier de la resource.

```
# ✅
app/views/organizations/_autocomplete_input.html.erb
app/views/users/_search.html.erb

# ❌ trop générique
app/views/shared/_organization_autocomplete.html.erb
app/views/shared/_search_form.html.erb
```

### Strict locals (Rails 7.1+)

Toujours déclarer les locals attendus par un partial avec la magic comment `locals:`. Cela documente le contrat et rend Rails strict sur les variables passées.

```erb
<%# locals: (f:, search_form:) %>
<%# locals: (subscription:, editable: false) %>
```

### Minimiser les locals

Ne passer que ce qui varie réellement entre les usages. Les champs, namespaces i18n et classes CSS hardcodés dans le partial sont préférables à des locals dynamiques prématurés.

```erb
<%# ✅ Locals réduits au strict nécessaire %>
<%# locals: (f:, search_form:) %>

<%# ❌ Locals qui anticipent des usages hypothétiques %>
<%# locals: (f:, search_form:, name_field:, siret_field:, label_name:, name_col_class: "fr-col-12 fr-col-md-6") %>
```

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

## Sémantique dans les vues

Préférer les méthodes du form object aux variables d'instance brutes pour exprimer l'intention.

```erb
<%# ✅ Sémantique claire %>
<% if !@search_form.search_requested? %>
  <%# hint initial %>
<% elsif @users.empty? %>
  <%# aucun résultat %>
<% end %>

<%# ❌ Valeur nil comme signal d'état %>
<% if @users.nil? %>
  <%# hint initial %>
<% elsif @users.empty? %>
  <%# aucun résultat %>
<% end %>
```

## Query Objects

For complex queries:

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

## Variable Reassignment & Method Chaining

### Avoid reassigning the same variable to successive values

Prefer chaining or extracting a private method — successive reassignment makes the data flow hard to follow.

```ruby
# BAD — users reassigned, data flow is hard to follow
users = cached_organization_users.select { |u| u.has_process_access?(code) }
users = users.select { |u| u.email&.start_with?(query) } if query

# GOOD — chained, linear flow
cached_organization_users
  .select { |u| u.has_process_access?(code) }
  .select { |u| query.blank? || u.email&.start_with?(query) }
```

### Chain instead of storing intermediate results

```ruby
# BAD — unnecessary intermediate variables
filtered = subscriptions.select(&:active?)
names = filtered.map(&:name)
result = names.sort

# GOOD — chained
subscriptions.select(&:active?).map(&:name).sort
```

### Conditional chaining via `.then` or private methods

```ruby
# BAD — condition that reassigns
result = collection.select { |x| x.valid? }
result = result.first(10) if paginate?

# GOOD — named private method
def filtered_collection
  collection
    .select(&:valid?)
    .then { |r| paginate? ? r.first(10) : r }
end
```

## Linting

StandardRB is the single source of truth (no RuboCop, no debates). The plugin's `post-edit-standardrb` hook runs it automatically after every Edit on `.rb` files.

```bash
# Manual check / fix
bundle exec standardrb
bundle exec standardrb --fix
```
