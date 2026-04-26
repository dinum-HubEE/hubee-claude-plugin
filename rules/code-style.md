# Code Style Rules

## Philosophy

1. **The Rails Way** - Convention over configuration
2. **StandardRB** - Zero config linting, no debates
3. **Explicit > Clever** - Code should be readable
4. **DRY, but not too DRY** - Avoid premature abstraction

## Ruby Conventions

### Naming

```ruby
# Classes: PascalCase
class UserSubscription; end

# Methods/variables: snake_case
def calculate_total
  user_count = 42
end

# Constants: SCREAMING_SNAKE_CASE
MAX_RETRY_COUNT = 3

# Predicates: end with ?
def active?; end

# Dangerous methods: end with !
def destroy!; end
```

### Class Structure

Order matters:
1. Constants
2. Associations
3. Validations
4. Scopes
5. Callbacks (avoid if possible)
6. Class methods
7. Instance methods
8. Private methods

```ruby
class Organization < ApplicationRecord
  # Constants
  STATUSES = %w[active inactive pending].freeze

  # Associations
  has_many :subscriptions, dependent: :destroy
  belongs_to :parent, optional: true

  # Validations
  validates :siret, presence: true, uniqueness: true
  validates :name, presence: true

  # Scopes
  scope :active, -> { where(status: "active") }
  scope :by_name, ->(q) { where("name ILIKE ?", "%#{q}%") }

  # Class methods
  def self.find_by_siret!(siret)
    find_by!(siret: siret)
  end

  # Instance methods
  def full_identifier
    "#{siret} - #{name}"
  end

  private

  def normalize_siret
    siret&.gsub(/\s/, "")
  end
end
```

## Rails Conventions

### Controllers

- One action, one responsibility
- Use `before_action` for shared setup
- Use strong parameters
- Keep controllers thin

```ruby
class SubscriptionsController < ApplicationController
  before_action :set_subscription, only: %i[show edit update destroy]

  def index
    @subscriptions = policy_scope(Subscription)
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

  private

  def set_subscription
    @subscription = Subscription.find(params[:id])
  end

  def subscription_params
    params.require(:subscription).permit(:organization_id, :process_id)
  end
end
```

### Views

- Use Rails helpers (`link_to`, `form_with`, etc.)
- Extract partials for reusable components
- Use Turbo Frames for dynamic updates
- Keep logic out of views (use helpers or presenters)

## Variable Reassignment

Avoid reassigning the same variable to successive values. Prefer chaining or extracting a private method.

```ruby
# BAD — users reassigned, data flow is hard to follow
users = cached_organization_users.select { |u| u.has_process_access?(code) }
users = users.select { |u| u.email&.start_with?(query) } if query

# GOOD — chained, linear flow
cached_organization_users
  .select { |u| u.has_process_access?(code) }
  .select { |u| query.blank? || u.email&.start_with?(query) }
```

## Method Chaining

When transforming a collection step by step, chain methods instead of storing intermediate results.

```ruby
# BAD — unnecessary intermediate variables
filtered = subscriptions.select(&:active?)
names = filtered.map(&:name)
result = names.sort

# GOOD — chained
subscriptions.select(&:active?).map(&:name).sort
```

When conditional chaining is needed, use `.then` or extract a private method:

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

StandardRB is the single source of truth:

```bash
# Check style
bundle exec standardrb

# Auto-fix
bundle exec standardrb --fix
```

No custom RuboCop rules. No debates. Just StandardRB.

## Documentation

### Proactive README Updates

Update the README **automatically** (without being asked) when:

- A new `bin/*` script is created or modified
- A new Claude command (`/hubee-*`) is added
- The tech stack changes (major gem, Ruby/Rails version)
- The installation or development workflow changes
- A new tooling feature is added (worktrees, etc.)

### What Does NOT Require an Update

- Internal code changes (refactoring, bug fixes)
- Adding tests
- Claude configuration changes (rules, skills, agents)
- Style or linting changes
