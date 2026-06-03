---
name: performance
description: Database and Rails performance patterns. Use when reviewing or writing ActiveRecord queries, designing data access (eager loading, indexing, batch processing), optimizing slow paths, deciding what to cache, or moving slow operations to background jobs. Especially useful before merging changes that touch model queries, controller index actions, or anything that loops over records.
---

# Performance Skill

## Database

### N+1 Queries

Always use eager loading to avoid N+1 queries.

```ruby
# BAD — N+1 query
@subscriptions = Subscription.all
@subscriptions.each { |s| puts s.organization.name }

# GOOD — eager loading
@subscriptions = Subscription.includes(:organization)
@subscriptions.each { |s| puts s.organization.name }
```

The `bullet` gem detects N+1 in development. Add to the Gemfile if not already present.

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

- Use `select` to limit columns when full records aren't needed
- Use `pluck` for single-value extraction (no AR objects allocated)
- Use `find_each` for batch processing (default batch size 1000, configurable)

```ruby
# Memory-efficient batch processing
Organization.find_each(batch_size: 100) do |org|
  process(org)
end

# pluck instead of map(&:id) when you just need IDs
Subscription.active.pluck(:id) # => [1, 2, 3]
```

## Caching

```ruby
# Fragment caching in views — auto-keyed on the record's updated_at
<% cache @organization do %>
  <%= render @organization %>
<% end %>

# Low-level caching
Rails.cache.fetch("organization/#{id}/stats", expires_in: 1.hour) do
  calculate_expensive_stats
end
```

Russian-doll caching works automatically when nested `cache` blocks are used and the inner record's `touch:` keeps the outer key fresh.

## Background Jobs

Move slow external calls and notifications out of the request cycle.

```ruby
# BAD — blocking request
def create
  @subscription = Subscription.create!(params)
  NotificationMailer.subscription_created(@subscription).deliver_now
  SyncService.sync_to_api(@subscription) # slow external API
end

# GOOD — non-blocking
def create
  @subscription = Subscription.create!(params)
  NotificationJob.perform_later(@subscription.id)
  ApiSyncJob.perform_later(@subscription.id)
end
```

Pass IDs to jobs, never AR instances (GlobalID re-loads anyway, and IDs serialize safely).

## What to check in dev / before merging

- Rails console query log (`ActiveRecord::Base.logger = Logger.new(STDOUT)`)
- Browser DevTools → Network tab → check redundant requests
- `bullet` gem alerts in dev logs
- For an index loop: ensure `.includes(...)` covers everything iterated in the view
