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
| `choosing-a-pattern` | **Choix de pattern** : quel pattern écrire pour quel besoin |
| `models` | Conventions des modèles ActiveRecord (structure standard, validations à liste fermée, scopes) |
| `controllers` | Conventions des controllers RESTful (actions, strong params, Pundit, réponses) |
| `ruby-style` | Style de code Ruby transverse (nommage, commentaires, chaînage, blocks, error handling, temps, linting StandardRB) |
| `interactors` | Logique métier multi-étapes (gem interactor) : nommage, partage, rollback/ordonnancement, rejeu, specs |
| `query-objects` | Requête complexe (filtres conditionnels, recherche, jointures) dans `app/queries/` |
| `form-objects` | Objet formulaire : ce qui pilote l'opération, champs non soumis (rendu : `frontend-rails`) |
| `state-machine` | Cycle de vie / états contraints d'une ressource (gem AASM) |
| `review` | Checklist review HubEE avant push/MR (Rails + RSpec + DSFR + RGAA + Keycloak) |
| `security` | Audit sécurité Rails HubEE (SQL injection, XSS, mass assignment, Keycloak, brakeman) |
| `rspec-conventions` | Conventions d'écriture des specs RSpec, tous types (transverse + request/system ; cycle délégué à `superpowers:test-driven-development`) |
| `test-strategy` | Quoi/où tester + objectif de couverture SimpleCov 90% |

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

### Choix des patterns (source unique)

`choosing-a-pattern` **choisit le pattern** : cette skill détient à elle seule le « quel pattern écrire », frontière avec le cran en dessous incluse (query object vs scope de modèle, AASM vs `update` libre, interactor vs méthode de modèle). Elle ne contient **aucune convention de code** — le style Ruby transverse vit dans `ruby-style`, les conventions d'un pattern dans sa skill. Chaque skill de pattern (`controllers`, `models`, `interactors`, `query-objects`, `form-objects`, `state-machine`) ne couvre que le « **est-ce bien implémenté** » une fois le choix fait. Ne pas reformuler le seuil de bascule ailleurs — corps, checklist **ou** `description:` du frontmatter : deux copies = désync garantie dès que ce choix évolue. La `description:` garde un déclencheur de *situation* (« dès qu'une action index accumule des scopes conditionnels »), jamais une comparaison inter-pattern (« ou trop grosse pour un scope de modèle »).

**Corollaire sur les renvois.** Une skill ne renvoie que vers **`choosing-a-pattern`** (le choix de pattern) ou une skill **générique** — non nommée d'après un pattern : `ruby-style`, `security`, `frontend-rails`, `principles`, `hotwire`… Jamais vers une skill de pattern par son nom : cela présumerait le pattern d'arrivée, qui est la décision de `choosing-a-pattern` (ex. ✗ `state-machine` → `interactors` pour « logique qui déborde » ; ✓ `state-machine` → `choosing-a-pattern`). Exempts : `choosing-a-pattern` lui-même, et les index/méta qui énumèrent les skills par nature (`explore-rails`, `review`, `convention-audit`).

### Doctrine de handoff (médiation humaine)

**Claude PRÉPARE, le dev EXÉCUTE sur le host.** Toute commande à exécuter = un bloc ` ```bash ` mono-ligne, copier-collable tel quel. **JAMAIS** de blockquote ni de préfixe `>` : le `>` se copie avec la commande et la casse.

Pour du contenu multi-ligne (message de commit, description de MR/PR) : écrire un fichier via l'outil Write, puis fournir une commande mono-ligne qui le consomme (`git commit -F fichier`, `gh pr create --body-file fichier`).

Pas de `clipboard-copy` / OSC52 : l'agent-vm ne peut pas écrire dans le presse-papier du host.

#### Une commande, une étape sautable en moins

Toute **étape préalable** (`git reset`, `git fetch`, `bundle install`) est **intégrée à la première commande de la séquence** par `&&`, jamais fournie dans un bloc séparé. Un bloc distinct peut être sauté silencieusement — rien ne le signale — et les commandes suivantes s'exécutent alors sur un état non prévu, chacune paraissant réussir. Un `git reset` non collé avant une séquence de commits fait par exemple partir des fichiers déjà indexés dans le **premier** commit, cassant tous les suivants.

Corollaire : quand une séquence dépasse ~3 blocs, ne pas la découper — fournir une **commande unique** qui boucle sur des fichiers numérotés.

```bash
git reset --soft main && git reset && ( for i in $(seq 1 10); do git add --pathspec-from-file=.commit-files-$i.tmp && git commit -F .commit-msg-$i.tmp || exit 1; done ) && rm .commit-files-*.tmp .commit-msg-*.tmp
```

La sous-shell `( … )` garantit qu'un échec interrompt la séquence **sans** déclencher le `rm` final : les fichiers restent en place pour diagnostiquer et reprendre.

> **Ne pas compter sur le hook `pre-commit`** pour rattraper une séquence partie de travers : `bin/ci` valide le **working tree**, pas le contenu du commit. Il passe au vert sur une série de commits individuellement cassés.

Les skills `commit`, `finishing-branch` et `gitlab` **référencent** cette section au lieu de redire le principe.

## Publier un changement

Pas de versionnage manuel. Le plugin n'a pas de champ `version` dans son manifeste : chaque commit SHA est une nouvelle version automatique (cf. [plugins-reference#version-management](https://code.claude.com/docs/en/plugins-reference#version-management)). `claude plugin update hubee-claude-plugin@hubee-claude-plugin` diffuse n'importe quel commit pushé sur `main`.
