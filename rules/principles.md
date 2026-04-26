# Development Principles

Apply these principles to all code produced. Priority when in conflict: **YAGNI > KISS > DRY > SOLID**.

Why this order: a principle applied in isolation always sounds wise, but principles conflict. When
they do, favor the one that keeps the codebase smaller and simpler *today*. Applying SOLID to code
we don't yet need (YAGNI) produces abstractions that will be refactored anyway. Applying DRY to
two blocks that look the same but mean different things (Semantic DRY) couples unrelated concepts
and makes them harder to change. Simplicity first, structure only when it pays.

## SOLID

### S — Single Responsibility

A class/method has one reason to change. A model does not make HTTP calls, a service does not render views.

```ruby
# BAD — model handles business logic AND external call
class Subscription < ApplicationRecord
  def activate!
    update!(status: "active")
    HubeeApi.new.post("/subscriptions", id: id) # not its job
  end
end

# GOOD — each class has one responsibility
class Subscription < ApplicationRecord
  def activate!
    update!(status: "active")
  end
end

class SubscriptionActivator
  def call(subscription)
    subscription.activate!
    HubeeApi.new.post("/subscriptions", id: subscription.id)
  end
end
```

### O — Open/Closed

Code is open for extension, closed for modification. Add behavior without touching existing code.

```ruby
# BAD — adding a format requires modifying the existing method
class ExportService
  def call(format)
    if format == :csv then export_csv
    elsif format == :pdf then export_pdf # touching existing code
    end
  end
end

# GOOD — extend by adding a new class, not by modifying existing ones
class CsvExportService
  def call = export_csv
end

class PdfExportService
  def call = export_pdf
end
```

### L — Liskov Substitution

Any subclass must be substitutable for its parent without altering expected behavior. Do not override a method to change its contract.

```ruby
# BAD — subclass raises where parent returns nil, breaking callers
class ApiClient
  def find(id) = nil # returns nil when not found
end

class StrictApiClient < ApiClient
  def find(id) = raise NotFoundError # changes the contract
end

# GOOD — subclass preserves the contract
class CachedApiClient < ApiClient
  def find(id)
    cache.fetch(id) { super }
  end
end
```

### I — Interface Segregation

Prefer several focused modules over a fat one. A class should not be forced to implement methods it does not need.

```ruby
# BAD — one fat concern forces all includers to carry unused methods
module Exportable
  def to_csv = ...
  def to_pdf = ...
  def to_xml = ...
end

# GOOD — focused modules, include only what you need
module CsvExportable
  def to_csv = ...
end

module PdfExportable
  def to_pdf = ...
end

class Subscription < ApplicationRecord
  include CsvExportable # only what is needed
end
```

### D — Dependency Inversion

Depend on abstractions, not concrete implementations. Inject dependencies rather than instantiating them directly.

```ruby
# BAD — hard-coded dependency, impossible to stub in tests
class SubscriptionActivator
  def call(subscription)
    HubeeApi.new.post("/subscriptions", id: subscription.id)
  end
end

# GOOD — dependency injected, easy to swap or stub
class SubscriptionActivator
  def initialize(api_client: HubeeApi.new)
    @api_client = api_client
  end

  def call(subscription)
    @api_client.post("/subscriptions", id: subscription.id)
  end
end

# In spec/services/subscription_activator_spec.rb:
# SubscriptionActivator.new(api_client: double("api", post: true))
```

## YAGNI — You Aren't Gonna Need It

Only implement what is needed now, not what might be needed someday.

```ruby
# BAD — generic config system built "just in case"
class Subscription < ApplicationRecord
  def self.find_with_options(id, cache: false, fallback: nil, locale: :fr)
    # complex logic nobody asked for
  end
end

# GOOD — implement exactly what is needed
class Subscription < ApplicationRecord
  def activate! = update!(status: "active")
end
```

## KISS — Keep It Simple, Stupid

Favor the simplest solution that works, avoid accidental complexity.

```ruby
# BAD — clever but hard to read
active_orgs = orgs.each_with_object({}) { |o, h| h[o.id] = o if o.status == "active" }

# GOOD — simple and explicit
active_orgs = orgs.select(&:active?)
```

## DRY — Don't Repeat Yourself

Every piece of knowledge has a single, unambiguous representation — but without premature abstraction.

```ruby
# BAD — same logic duplicated in two places
def admin_label = "[#{siret}] #{name}"
def export_label = "[#{siret}] #{name}"

# GOOD — single source of truth
def label = "[#{siret}] #{name}"
alias admin_label label
alias export_label label
```

### Rule of Three — wait until you see it three times

Don't extract on the second occurrence. Duplication is cheap, wrong abstraction is expensive: once
you've extracted a helper, every future variation has to either fit the helper or break it.

Two occurrences may share shape by coincidence. A third occurrence is evidence of a pattern.

```ruby
# First use — just write it
def admin_label = "[#{siret}] #{name}"

# Second use — duplicate, don't extract yet
def export_label = "[#{siret}] #{name}"

# Third use with the same shape — now extract
def label = "[#{siret}] #{name}"
alias admin_label label
alias export_label label
alias search_label label
```

Corollary: if the third occurrence shows the shape is *almost* the same but with a twist
(different separator, conditional field), that's a signal the abstraction is not ready — keep
duplicating until the right shape emerges.

### Semantic DRY — coincidence of value ≠ same knowledge

Two things that share the same value are **not** the same thing if they have distinct semantic
roles. DRY applies to *knowledge* (one business rule → one place), not to structural coincidences.

Before factoring two identical-looking values, ask: "do they represent the same concept?"
If no → keep them separate, even if their current values match.

```ruby
# BAD — same URL today, merged into one (false DRY)
KEYCLOAK_URL = ENV.fetch("KEYCLOAK_BASE_URL") # used for both portal login and user management

# GOOD — two semantic roles, two variables, independently evolvable
KEYCLOAK_OIDC_URL  = ENV.fetch("KEYCLOAK_BASE_URL")  # authenticates portal admins (OIDC)
KEYCLOAK_ADMIN_URL = ENV.fetch("KEYCLOAK_BASE_URL")  # manages HubeeV1 end-user accounts
```

## Self-check before proposing code

You pattern-match on "best practices" from training data and tend to **over-abstract**: service
objects where a model method would do, dependency injection where hard-coding is fine, generic
configuration where a literal works. These principles exist to push back against that reflex.

Before proposing code, check yourself:

- **YAGNI first.** Is this abstraction needed *today* by an actual caller, or does it prepare for
  a hypothetical future? If future, cut it.
- **KISS over SOLID.** A Rails controller calling `.update!` directly is often better than a
  service object wrapping the same line. Resist the reflex to split.
- **Rule of Three before DRY.** If only two places share a shape, don't factor them out yet.
- **Semantic DRY.** Two values with the same string are not the same knowledge.

If you're about to extract a class, add a strategy pattern, or introduce a gem to avoid three
lines of duplication — push back against yourself and keep the simpler version.
