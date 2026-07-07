# hubee-claude-plugin

Plugin Claude Code partagé pour les projets HubEE.

## Installation

```bash
claude plugin marketplace add dinum-HubEE/hubee-claude-plugin
claude plugin install hubee-claude-plugin@hubee-claude-plugin
```

## Mise à jour

Les 4 plugins HubEE (`hubee-claude-plugin`, `superpowers@claude-plugins-official`, `dsfr-skill@dsfr-skill`, `claude-hud@claude-hud`) sont mis à jour **automatiquement à chaque `agent-vm claude`**. Aucune action manuelle nécessaire. Pas de bump de version manuel : le plugin n'a pas de champ `version`, chaque commit SHA sur `main` est une nouvelle version (cf. [plugins-reference#version-management](https://code.claude.com/docs/en/plugins-reference#version-management)).

Le mécanisme : à chaque lancement, la VM exécute en best-effort :

```bash
claude plugin update claude-hud@claude-hud                   2>/dev/null || true
claude plugin update superpowers@claude-plugins-official     2>/dev/null || true
claude plugin update dsfr-skill@dsfr-skill                   2>/dev/null || true
claude plugin update hubee-claude-plugin@hubee-claude-plugin 2>/dev/null || true
```

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
| `rails-patterns` | Conventions Rails génériques (naming, modèles, controllers, error handling) **+ routeur** de choix de pattern |
| `interactors` | Logique métier multi-étapes (gem interactor) : nommage, partage, rollback/ordonnancement, rejeu, specs |
| `query-objects` | Requête complexe (filtres conditionnels, recherche, jointures) dans `app/queries/` |
| `form-objects` | Objet formulaire : ce qui pilote l'opération, champs non soumis (rendu : `frontend-rails`) |
| `state-machine` | Cycle de vie / états contraints d'une ressource (gem AASM) |
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

## Contribuer au plugin

### Frontière de responsabilité (StandardRB vs plugin vs hooks)

Chaque règle a un seul responsable. Ne pas dupliquer une règle d'une couche à l'autre.

| Type de règle | Qui s'en charge |
|---|---|
| Mécanique / syntaxique / déterministe (indentation, casse, `frozen_string_literal`) | StandardRB |
| Jugement / sémantique / intention (Capybara vs Nokogiri, « 1 cas = 1 `it` ») | Plugin (skills) |
| Décision d'équipe non exprimable en cop | Plugin (skills) |
| Faits structurels/contextuels au moment d'un outil (spec sans impl, fichier sensible) | Hooks |

**Règle d'or** : si StandardRB l'enforce déjà, ne pas le mettre dans un skill (token gaspillé + moins fiable — StandardRB corrige, un skill ne fait qu'espérer). Les hooks ne ré-encodent jamais un pattern de convention déjà décrit dans un skill (sinon duplication de connaissance). Un skill se mesure à sa **densité de signal** pour le modèle, pas à sa lisibilité humaine : un mur de texte dilue l'attention.

**Le plugin est cross-app.** Il n'encode que des conventions valables pour **toutes** les apps HubEE. Toute règle spécifique à une app (schéma de données, architecture de persistance, parcours métier) appartient au `CLAUDE.md` de cette app, **pas** au plugin partagé : une règle qui suppose l'architecture d'une seule app produirait un faux positif ailleurs.

### Doctrine de handoff (médiation humaine)

**Claude PRÉPARE, le dev EXÉCUTE sur le host.** Toute commande à exécuter = un bloc ` ```bash ` mono-ligne, copier-collable tel quel. **JAMAIS** de blockquote ni de préfixe `>` : le `>` se copie avec la commande et la casse.

Pour du contenu multi-ligne (message de commit, description de MR/PR) : écrire un fichier via l'outil Write, puis fournir une commande mono-ligne qui le consomme (`git commit -F fichier`, `gh pr create --body-file fichier`).

Pas de `clipboard-copy` / OSC52 : l'agent-vm ne peut pas écrire dans le presse-papier du host.

Les skills `commit`, `finishing-branch` et `gitlab` **référencent** cette section au lieu de redire le principe.

## Publier un changement

Pas de versionnage manuel. Le plugin n'a pas de champ `version` dans son manifeste : chaque commit SHA est une nouvelle version automatique (cf. [plugins-reference#version-management](https://code.claude.com/docs/en/plugins-reference#version-management)). `claude plugin update hubee-claude-plugin@hubee-claude-plugin` diffuse n'importe quel commit pushé sur `main`.
