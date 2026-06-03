# hubee-claude-plugin

Plugin Claude Code partagé pour les projets HubEE.

## Installation

```bash
claude plugin marketplace add dinum-HubEE/hubee-claude-plugin
claude plugin install hubee-claude-plugin@hubee-claude-plugin
```

Pour les devs HubEE qui utilisent [`hubee-agent-vm-config`](https://gitlab.hubee.numerique.gouv.fr/hubee/hubee-agent-vm-config), c'est automatique au `agent-vm setup`.

## Mise à jour

Les 4 plugins HubEE (`hubee-claude-plugin`, `superpowers@claude-plugins-official`, `dsfr-skill@dsfr-skill`, `claude-hud@claude-hud`) sont mis à jour **automatiquement à chaque `agent-vm claude`**. Aucune action manuelle nécessaire. Pas de bump de version manuel : le plugin n'a pas de champ `version`, chaque commit SHA sur `main` est une nouvelle version (cf. [plugins-reference#version-management](https://code.claude.com/docs/en/plugins-reference#version-management)).

Le mécanisme : à chaque lancement, la VM exécute en best-effort :

```bash
claude plugin update claude-hud@claude-hud                   2>/dev/null || true
claude plugin update superpowers@claude-plugins-official     2>/dev/null || true
claude plugin update dsfr-skill@dsfr-skill                   2>/dev/null || true
claude plugin update hubee-claude-plugin@hubee-claude-plugin 2>/dev/null || true
```

(défini dans [`hubee-agent-vm-config`](https://gitlab.hubee.numerique.gouv.fr/hubee/hubee-agent-vm-config))

Si tu veux forcer un refresh **en cours de session** (sans attendre le prochain lancement) :

```
claude plugin marketplace update
claude plugin update hubee-claude-plugin@hubee-claude-plugin
/exit
```

Puis relancer `agent-vm --git-ro claude`. Le `/exit` est obligatoire — les skills ne se rechargent pas à chaud.

**Re-baker le template Lima** (optionnel, ~1× par mois ou si `hubee-agent-vm-config` a changé) :

```bash
cd ~/.agent-vm && git pull && agent-vm setup
```

5-10 min. Embarque dans le template Lima les dernières versions des plugins + la dernière config partagée. Sans rebake, l'auto-update au lancement rattrape immédiatement n'importe quelle VM (y compris après `agent-vm rm`).

## Activation côté projet

Dans `<projet>/.claude/settings.json` :

```json
{
  "enabledPlugins": {
    "hubee-claude-plugin@hubee-claude-plugin": true,
    "superpowers@claude-plugins-official": true,
    "dsfr-skill@dsfr-skill": true
  }
}
```

`dsfr-skill` est utile uniquement si le projet a une UI Rails. Skip sinon (projet Java backend pur, lib, etc.).

## Skills

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
| `frontend-rails` | DSFR + Rails (dsfr-form_builder, hidden_field anti-pattern, Hotwire dans ERB DSFR) |
| `gitlab` | Lire issues/MR/board/fichiers de l'instance HubEE GitLab via `glab` |
| `hotwire` | Turbo Frames/Streams, Stimulus controllers |
| `hubee-recap` | Résumé mensuel des MR/PR mergées sur HubEE (GitLab interne + GitHub publics), avec « Évolutions notables » par thème |
| `performance` | DB / Rails performance (N+1, indexing, pluck/find_each, caching, jobs) |
| `plan` | Rédiger un plan d'implémentation (override `superpowers:writing-plans`) |
| `principles` | Pousser back contre l'over-abstraction (YAGNI > KISS > DRY > SOLID, Rule of Three, Semantic DRY) |
| `rails-patterns` | Models, controllers, services, queries, naming, method chaining |
| `review` | Checklist review HubEE avant push/MR (Rails + RSpec + DSFR + RGAA + Keycloak) |
| `security` | Audit sécurité Rails HubEE (SQL injection, XSS, mass assignment, Keycloak, brakeman) |
| `tdd-workflow` | TDD RSpec/FactoryBot/SimpleCov 80% (override `superpowers:test-driven-development`) |

## Hooks

`pre-bash` (bloque git destructifs), `pre-edit-secrets` (bloque édition `.env` / `master.key` / `credentials.yml.enc`), `pre-edit-rspec-hint`, `post-edit-standardrb` (StandardRB auto-fix), `on-stop`, `on-notification`.

## Conventions

- Skills : nom anglais, contenu en français
- Override de superpowers par référence (pas de fork — quand superpowers évolue, on en hérite)
- Pas de commande slash (skills-first, déclenchement par description)
- TDD obligatoire sur le code Rails

## Publier un changement

Pas de versionnage manuel. Le plugin n'a pas de champ `version` dans son manifeste : chaque commit SHA est une nouvelle version automatique (cf. [plugins-reference#version-management](https://code.claude.com/docs/en/plugins-reference#version-management)). `claude plugin update hubee-claude-plugin@hubee-claude-plugin` diffuse n'importe quel commit pushé sur `main`.
