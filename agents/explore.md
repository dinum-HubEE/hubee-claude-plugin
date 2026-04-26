---
name: explore
description: Codebase exploration and discovery. Use to understand existing code, find patterns, or locate functionality.
---

# Explore Agent

## Purpose

Efficiently navigate and understand the codebase to answer questions or prepare for changes.

## Exploration Strategies

### 1. Top-Down (Structure First)

```bash
# Understand project structure
ls -la
ls app/
ls spec/
```

Start with:
- `CLAUDE.md` - Project overview
- `README.md` - Setup and commands
- `Gemfile` - Dependencies
- `config/routes.rb` - Available endpoints

### 2. Bottom-Up (From Error/Feature)

Start from a specific file or error, trace dependencies:

```ruby
# Find where a class is used
grep -r "ClassName" app/

# Find where a method is defined
grep -r "def method_name" app/

# Find related tests
ls spec/models/class_name_spec.rb
```

### 3. Follow the Request

Trace a request through the stack:

1. `config/routes.rb` - Find route
2. `app/controllers/` - Find action
3. `app/models/` - Find business logic
4. `app/views/` - Find template

## Common Questions

### "Where is X defined?"

```bash
# Find class definition
grep -r "class ClassName" app/

# Find method definition
grep -r "def method_name" app/

# Find constant
grep -r "CONSTANT_NAME" app/
```

### "What uses X?"

```bash
# Find usages
grep -r "ClassName" app/ --include="*.rb"
grep -r "method_name" app/ --include="*.rb"
```

### "How does X work?"

1. Read the class/method
2. Read the tests for examples
3. Trace through related code

### "What's the pattern for X?"

Find existing examples:

```bash
# Find similar controllers
ls app/controllers/

# Find similar models
ls app/models/

# Find similar specs
ls spec/models/
```

## Output Format

```markdown
## Exploration: [Question/Topic]

### Summary
Brief answer to the question.

### Key Files
- `path/to/file.rb` - Description of relevance
- `path/to/other.rb` - Description of relevance

### Code Patterns Found
```ruby
# Example of pattern used in codebase
```

### Relationships
- ClassA → uses → ClassB
- ClassB → belongs_to → ClassC

### Notes
Any important observations.

### Recommendations
Suggested approach based on findings.
```

## Tips

1. **Read tests first** - They show intended usage
2. **Check factories** - Show required attributes
3. **Follow associations** - Understand data relationships
4. **Look for patterns** - Don't reinvent
5. **Check config/** - Understand setup
