# Git Workflow Rules

## Critical Rule

> **NEVER commit or push without explicit user validation.**

This is non-negotiable. Always ask for confirmation before any `git commit` or `git push`.

## Branch Naming

| Prefix | Use Case | Example |
|--------|----------|---------|
| `feat/` | New feature | `feat/subscription-list` |
| `fix/` | Bug fix | `fix/login-redirect` |
| `docs/` | Documentation | `docs/api-guide` |
| `refactor/` | Code refactoring | `refactor/extract-service` |
| `test/` | Test changes | `test/subscription-specs` |
| `chore/` | Maintenance | `chore/update-deps` |

## Conventional Commits

Format: `type(scope): description`

```
feat(subscriptions): add list view with filters
fix(auth): handle expired tokens
docs(readme): add setup instructions
refactor(api): extract HTTP client
test(organizations): add validation specs
chore(deps): update rails to 8.1.3
```

### Types

- `feat` - New feature (triggers minor version bump)
- `fix` - Bug fix (triggers patch version bump)
- `docs` - Documentation only
- `style` - Code style (formatting, no logic change)
- `refactor` - Code refactoring
- `test` - Adding or updating tests
- `chore` - Maintenance tasks

### Scope (optional)

Module or component affected: `auth`, `subscriptions`, `api`, `deps`, etc.

## Commit Workflow

### Before Committing

1. Check status: `git status`
2. Review changes: `git diff`
3. **Run CI locally: `bin/ci`** (MANDATORY - never skip)
4. Fix any issues before proceeding
5. **Ask user for validation**

> **Important** : Ne jamais proposer de commit si `bin/ci` n'a pas été exécuté avec succès.

### Commit Message Example

```
feat(subscriptions): add organization filter

- Add dropdown filter component
- Implement Ransack search
- Add request specs for filtering

Refs: #123
```

## Merge Requests (GitLab)

### Title

Same format as commits:
```
feat(subscriptions): add CRUD operations
```

### Description Template

```markdown
## Summary
Brief description of changes.

## Changes
- Change 1
- Change 2

## Testing
- [ ] Unit tests added
- [ ] Request specs added
- [ ] Manual testing done

## Screenshots
(if applicable)

## AI Prompts
(if applicable - include key prompts used to generate this code)
```

## Protected Operations

These require explicit user confirmation:
- `git commit` - Always ask for message validation
- `git push` - Always ask before pushing
- `git merge` - Always ask before merging
- `git rebase` - Always ask before rebasing

## Commit Message Rules

- **No Co-Authored-By**: NEVER add Claude as co-author in commits
- Keep messages concise and focused on the "why"
- Use imperative mood ("add feature" not "added feature")

## Destructive Operations

NEVER execute without explicit user request:
- `git reset --hard`
- `git push --force`
- `git checkout -- .`
- `git clean -fd`
- `git branch -D`
