---
name: build-fix
description: Fix build errors, test failures, and CI issues. Use when tests fail or CI is broken.
---

> **Override de `superpowers:systematic-debugging`** : cette skill ajoute les patterns Rails (bundle, rspec, db:migrate, brakeman) au framework de debug systématique de superpowers. Quand les deux sont disponibles, suivre cette skill HubEE pour les erreurs Rails, garder superpowers comme fallback générique.

# Build Fix Skill

## Purpose

Diagnose and fix build failures, test errors, and CI issues quickly.

## Diagnosis Process

### 1. Identify the Error

```bash
# Run the failing command
bundle exec rspec

# Or full CI
bin/ci
```

### 2. Categorize the Error

| Category | Symptoms | Common Fixes |
|----------|----------|--------------|
| **Syntax Error** | `SyntaxError`, unexpected token | Fix Ruby syntax |
| **Missing Method** | `NoMethodError`, undefined method | Add method or fix typo |
| **Missing Constant** | `NameError`, uninitialized constant | Require file or fix class name |
| **Test Failure** | Expected vs Got mismatch | Fix implementation or test |
| **Database Error** | Migration, schema issues | Run migrations |
| **Dependency Error** | Gem not found | Bundle install |

### 3. Fix Strategies

#### Syntax Errors

```bash
# Find the exact error
bundle exec ruby -c app/models/broken.rb
```

#### Test Failures

```bash
# Run just the failing test
bundle exec rspec spec/path/to/spec.rb:LINE

# With verbose output
bundle exec rspec spec/path/to/spec.rb:LINE --format documentation
```

#### Database Issues

```bash
# Reset test database
RAILS_ENV=test bin/rails db:drop db:create db:migrate

# Check pending migrations
bin/rails db:migrate:status
```

#### Dependency Issues

```bash
# Update bundle
bundle install

# Clear cache if needed
bundle clean --force
bundle install
```

### 4. Verify Fix

```bash
# Run the specific test
bundle exec rspec spec/path/to/spec.rb

# Then full suite
bundle exec rspec

# Then full CI
bin/ci
```

## Common Error Patterns

### Factory Not Found

```
KeyError: Factory not registered: "subscription"
```

Fix: Create factory in `spec/factories/subscriptions.rb`

### Missing Column

```
ActiveRecord::StatementInvalid: SQLite3::SQLException: no such column
```

Fix: Run migrations or add column

### Unpermitted Parameters

```
ActionController::UnpermittedParameters
```

`action_on_unpermitted_parameters` vaut `:raise` en test et développement : un champ de formulaire **soumis mais retiré du `permit`** fait planter, pas juste un log. Trois sorties selon l'intention :

- param légitime → l'ajouter au `permit` ;
- reçu mais non voulu dans le form object → `.except(:x)` après le `permit` ;
- champ purement client (aide de saisie pilotée par Stimulus, jamais exploité côté serveur) → ne pas le soumettre via `name: nil` (Rails omet alors l'attribut `name`, le champ n'est pas envoyé).

```erb
<%# champ d'aide à la saisie non soumis : le name est omis %>
<%= f.text_field :organization_name, name: (submitted ? f.field_name(:organization_name) : nil) %>
```

### StandardRB Violations

```bash
# Auto-fix style issues
bundle exec standardrb --fix
```

## Output Format

```markdown
## Build Fix: [Error Summary]

### Error
```
Exact error message
```

### Diagnosis
- Root cause identified
- Why it happened

### Fix Applied
- File: change made
- File: change made

### Verification
```bash
$ bundle exec rspec
.....

5 examples, 0 failures
```

### Prevention
How to avoid this in the future.
```
