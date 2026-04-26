# hubee-claude-plugin

Plugin Claude Code partagé pour les projets HubEE.

## Installation

Ajouter à `~/.claude/settings.json` (user-scope) ou `<projet>/.claude/settings.json` (projet) :

```json
{
  "enabledPlugins": {
    "hubee-claude-plugin@gitlab.hubee.numerique.gouv.fr/hubee/hubee-claude-plugin": true
  }
}
```

L'installation est automatisée pour les devs HubEE via le repo [`hubee-agent-vm-config`](https://gitlab.hubee.numerique.gouv.fr/hubee/hubee-agent-vm-config) (`setup.sh`).

> Plugin interne : pas de versionning ni de tag — la branche `main` est la version courante.

## Contenu

### `skills/` (déclenchement automatique par description)

| Skill | Quand |
|---|---|
| `api-client` | Consommer l'API HubeeV1 ou un service externe (HTTP client) |
| `architecture` | Décisions de design Rails (database schema, service boundaries) |
| `authentication` | Keycloak OIDC (login, logout, sessions, tokens) |
| `build-fix` | Erreurs CI / build / tests Rails (override `superpowers:systematic-debugging`) |
| `e2e` | Tests system specs (Capybara/Selenium) + parcours RGAA |
| `hotwire` | Turbo Frames/Streams, Stimulus controllers |
| `rails-patterns` | Models, controllers, services, queries Rails |
| `tdd-workflow` | TDD RSpec/FactoryBot/SimpleCov 80% (override `superpowers:test-driven-development`) |

### `rules/` (toujours appliquées)

`principles` (YAGNI > KISS > DRY > SOLID + Rule of Three) · `git-workflow` (Conventional Commits, branch naming) · `security` (sensitive files, SQL injection, XSS) · `agent-delegation` · `code-style` (StandardRB) · `testing` (TDD, RSpec) · `performance` (N+1, indexing, caching).

### `hooks/`

`pre-bash` (bloque `git commit`/`push`/`reset --hard` sans validation) · `pre-edit-secrets` (bloque édition `.env`, `master.key`) · `pre-edit-rspec-hint` (signale spec sans implem) · `post-edit-standardrb` (auto-format Ruby) · `on-stop` · `on-notification`.

### `agents/`

`explore` (navigation codebase) · `security` (vulnerabilités, OWASP).

## Conventions

- **Skills** : nom anglais (`commit`, `plan`, `review`), contenu rédigé en français pour le métier
- **Override de superpowers** : `tdd-workflow` étend `superpowers:test-driven-development`, `build-fix` étend `superpowers:systematic-debugging`. À venir : `plan`/`execute`/`finishing-branch` étendront les skills équivalentes superpowers (par **référence**, pas de fork — quand superpowers évolue, on en hérite).
- **Pas de commande slash** : déclenchement uniquement par description de la skill (skills-first)
- **TDD obligatoire** sur le code Rails

## Statut

Squelette initial migré depuis le portail admin V1. Skills à venir (rédigées au fil des besoins) : `commit`, `plan`, `execute`, `finishing-branch`, `gitlab`, `review`, `clipboard-handoff`.
