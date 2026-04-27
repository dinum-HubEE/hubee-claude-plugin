# hubee-claude-plugin

Plugin Claude Code partagé pour les projets HubEE.

## Installation

```bash
claude plugin marketplace add dinum-HubEE/hubee-claude-plugin
claude plugin install hubee-claude-plugin@hubee-claude-plugin
```

Puis activer dans `<projet>/.claude/settings.json` :

```json
{
  "enabledPlugins": {
    "hubee-claude-plugin@hubee-claude-plugin": true
  }
}
```

L'installation est automatisée pour les devs HubEE via le repo [`hubee-agent-vm-config`](https://gitlab.hubee.numerique.gouv.fr/hubee/hubee-agent-vm-config) (`setup.sh`) — le plugin est installé une fois, à `agent-vm setup`.

> Plugin interne : pas de versionning ni de tag — la branche `main` est la version courante.

## Contenu

### `skills/` (déclenchement automatique par description)

| Skill | Quand |
|---|---|
| `api-client` | Consommer l'API HubeeV1 ou un service externe (HTTP client) |
| `architecture` | Décisions de design Rails (database schema, service boundaries) |
| `authentication` | Keycloak OIDC (login, logout, sessions, tokens) |
| `build-fix` | Erreurs CI / build / tests Rails (override `superpowers:systematic-debugging`) |
| `commit` | Préparer un commit (Conventional Commits FR + bin/ci + clipboard handoff) |
| `e2e` | Tests system specs (Capybara/Selenium) + parcours RGAA |
| `execute` | Exécuter un plan step-by-step (override `superpowers:executing-plans`) |
| `explore-rails` | Naviguer un projet Rails route → controller → service → model → view |
| `finishing-branch` | Finaliser une branche, préparer la MR GitLab (override `superpowers:finishing-a-development-branch`) |
| `gitlab` | Lire issues/MR/board/fichiers de l'instance HubEE GitLab via `glab` |
| `hotwire` | Turbo Frames/Streams, Stimulus controllers |
| `plan` | Rédiger un plan d'implémentation (override `superpowers:writing-plans`) |
| `rails-patterns` | Models, controllers, services, queries Rails |
| `review` | Checklist review HubEE avant push/MR (Rails + RSpec + DSFR + RGAA + Keycloak) |
| `tdd-workflow` | TDD RSpec/FactoryBot/SimpleCov 80% (override `superpowers:test-driven-development`) |

### `rules/` (toujours appliquées)

`principles` (YAGNI > KISS > DRY > SOLID + Rule of Three) · `git-workflow` (Conventional Commits, branch naming) · `security` (sensitive files, SQL injection, XSS) · `agent-delegation` · `code-style` (StandardRB) · `testing` (TDD, RSpec) · `performance` (N+1, indexing, caching).

### `hooks/`

`pre-bash` (bloque `git commit`/`push`/`reset --hard` sans validation) · `pre-edit-secrets` (bloque édition `.env`, `master.key`) · `pre-edit-rspec-hint` (signale spec sans implem) · `post-edit-standardrb` (auto-format Ruby) · `on-stop` · `on-notification`.

### `agents/`

`explore` (navigation codebase) · `security` (vulnerabilités, OWASP).

## Conventions

- **Skills** : nom anglais, contenu rédigé en français pour le métier
- **Override de superpowers** par référence (pas de fork — quand superpowers évolue, on en hérite) : `tdd-workflow`, `build-fix`, `plan`, `execute`, `finishing-branch`
- **Pas de commande slash** : déclenchement uniquement par description de la skill (skills-first)
- **TDD obligatoire** sur le code Rails

## Activer le plugin sur un nouveau projet HubEE

### Pré-requis

Le plugin doit être **installé** dans la VM/poste qui va lancer Claude. Si tu utilises [`hubee-agent-vm-config`](https://gitlab.hubee.numerique.gouv.fr/hubee/hubee-agent-vm-config), c'est automatique au `agent-vm setup`. Sinon, manuellement :

```bash
claude plugin marketplace add dinum-HubEE/hubee-claude-plugin
claude plugin install hubee-claude-plugin@hubee-claude-plugin
```

### Activation côté projet

Dans le `<projet>/.claude/settings.json` :

```json
{
  "enabledPlugins": {
    "hubee-claude-plugin@hubee-claude-plugin": true,
    "superpowers@claude-plugins-official": true,
    "dsfr-skill@dsfr-skill": true
  }
}
```

`dsfr-skill` est utile uniquement pour les projets HubEE avec UI (V1 Rails, V2 Rails à venir). Skip si projet sans UI Rails (ex : projet Java backend pur).

### Cas projet Rails (V1, V2 Hubee à venir)

Tout marche immédiatement. Les skills s'activent par contexte :
- Modif de `app/models/`, `app/controllers/`, `lib/` → `rails-patterns` actif
- Modif de `app/javascript/`, `app/views/` → `hotwire`, `dsfr-skill`, rule `frontend`
- Tests RSpec → `tdd-workflow`
- Demande de commit → `commit`
- Demande de plan → `plan` + `superpowers:writing-plans`
- etc.

### Cas projet Java HubEE

Aucun problème de pollution contextuelle attendu : les skills Rails ne se déclenchent que sur du contenu Rails (Gemfile, `.rb`, `app/`). Sur un projet Java, elles restent dormantes.

Skills/rules **génériques HubEE** qui s'appliqueront quand même :
- `principles` (YAGNI > KISS > DRY > SOLID, agnostique du langage)
- `git-workflow` (Conventional Commits, agnostique)
- `security` (sensitive files, generic OWASP)
- `agent-delegation`
- `commit`, `plan`, `execute`, `finishing-branch`, `gitlab`, `review` (méthodologie projet, agnostique)

Skills **dormantes** sur projet Java :
- `rails-patterns`, `hotwire`, `tdd-workflow`, `api-client`, `authentication`, `architecture`, `build-fix`, `e2e`, `explore-rails` (déclenchées par contenu Rails uniquement)

Si une pollution apparaissait quand même : ouvrir une issue, on splitterait le plugin en `core` + `rails`.
