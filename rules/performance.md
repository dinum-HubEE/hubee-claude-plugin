# Performance Rules

## Database

### N+1 Queries

Always use eager loading to avoid N+1 queries:

```ruby
# BAD - N+1 query
@subscriptions = Subscription.all
@subscriptions.each { |s| puts s.organization.name }

# GOOD - Eager loading
@subscriptions = Subscription.includes(:organization)
@subscriptions.each { |s| puts s.organization.name }
```

### Indexing

Add indexes for:
- Foreign keys
- Columns used in `WHERE` clauses
- Columns used in `ORDER BY` clauses
- Columns used in `GROUP BY` clauses

```ruby
class AddIndexToSubscriptions < ActiveRecord::Migration[8.1]
  def change
    add_index :subscriptions, :organization_id
    add_index :subscriptions, :status
    add_index :subscriptions, [:organization_id, :process_id], unique: true
  end
end
```

### Query Optimization

- Use `select` to limit columns when possible
- Use `pluck` for simple value extraction
- Use `find_each` for batch processing

```ruby
# Memory efficient batch processing
Organization.find_each(batch_size: 100) do |org|
  process(org)
end
```

## Caching

Use Rails caching appropriately:

```ruby
# Fragment caching in views
<% cache @organization do %>
  <%= render @organization %>
<% end %>

# Low-level caching
Rails.cache.fetch("organization/#{id}/stats", expires_in: 1.hour) do
  calculate_expensive_stats
end
```

## Background Jobs

Move slow operations to background:

```ruby
# BAD - Blocking request
def create
  @subscription = Subscription.create!(params)
  NotificationMailer.subscription_created(@subscription).deliver_now
  SyncService.sync_to_api(@subscription)  # Slow external API
end

# GOOD - Non-blocking
def create
  @subscription = Subscription.create!(params)
  NotificationJob.perform_later(@subscription.id)
  ApiSyncJob.perform_later(@subscription.id)
end
```

## Asset Performance

- Tailwind CSS purges unused classes in production
- Use import maps for JavaScript (no bundler overhead)
- Lazy load images when possible

## Monitoring

Check these in development:
- `rails console` query logging
- Browser DevTools Network tab
- `bullet` gem for N+1 detection (add to Gemfile if needed)
