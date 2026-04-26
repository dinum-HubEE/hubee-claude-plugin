---
name: architecture
description: Architecture decisions and system design. Use for database schema, service boundaries, or integration patterns.
---

# Architecture Skill

## Purpose

Make informed architecture decisions considering Rails conventions, scalability, and maintainability.

## When to Invoke

- Database schema design
- Service layer organization
- External API integration patterns
- Performance optimization decisions
- Security architecture

## Architectural Principles

### 1. Rails Conventions First

- Follow "The Rails Way"
- Fat models, skinny controllers
- Convention over configuration
- Don't fight the framework

### 2. Simplicity

- Avoid premature optimization
- Start simple, refactor when needed
- "Make it work, make it right, make it fast"

### 3. Separation of Concerns

- Models: Business logic and validations
- Controllers: Request/response handling
- Services: Complex cross-cutting operations
- Policies: Authorization logic

## Decision Framework

### For Database Design

```markdown
## Schema Decision: [Entity Name]

### Requirements
- List of requirements

### Option A: [Name]
```ruby
# Migration
create_table :entities do |t|
  t.string :name
  t.timestamps
end
```
- Pros: ...
- Cons: ...

### Option B: [Name]
- Pros: ...
- Cons: ...

### Recommendation
Option [X] because...
```

### For Service Architecture

```markdown
## Service Decision: [Name]

### Problem
What problem does this solve?

### Options
1. Keep in model
2. Extract to service object
3. Use concern

### Recommendation
[Option] because it:
- Follows SRP
- Is testable
- Matches existing patterns
```

## Output Format

Always provide:
1. Clear problem statement
2. Multiple options considered
3. Pros/cons for each
4. Recommended approach with justification
5. Migration path if changing existing code
