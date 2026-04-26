# Agent Delegation Rules

Guidelines for when to delegate tasks to specialized agents.

## When to Delegate

### To `planning` Agent
- Complex features requiring architecture decisions
- Multi-file changes affecting multiple modules
- When unclear about implementation approach

### To `code-review` Agent
- After completing a feature
- Before creating a merge request
- When refactoring existing code

### To `tdd` Agent
- When implementing new features
- When fixing bugs (write failing test first)
- When adding new model or controller

### To `security` Agent
- When handling user input
- When implementing authentication/authorization
- When dealing with external APIs

### To `refactor` Agent
- When code duplication is detected
- When method/class is too long
- When code smells are identified

### To `docs` Agent
- When API changes are made
- When new features need documentation
- When README needs updating

## When NOT to Delegate

- Simple, single-file changes
- Minor bug fixes with obvious solutions
- Documentation-only changes
- Style/formatting changes

## Delegation Pattern

1. Identify the task complexity
2. Choose appropriate agent based on above criteria
3. Provide clear context and constraints
4. Review agent output before applying

## Agent Communication

When delegating, always provide:
- Clear task description
- Relevant file paths
- Constraints and requirements
- Expected output format
