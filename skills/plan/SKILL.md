---
name: plan
description: Rédiger un plan d'implémentation HubEE (override de superpowers:writing-plans avec conventions HubEE). Use when user asks to write a plan, design an approach, or before starting a multi-step implementation.
---

# Plan HubEE Skill

> **Override de `superpowers:writing-plans`.** Cette skill ajoute les conventions HubEE et délègue tout le reste (structure, granularité des tasks, format des steps, no placeholders, self-review) à la skill superpowers.

## Procédure

1. **Invoque `superpowers:writing-plans`** pour la méthodologie complète : structure de fichier, header obligatoire, granularité 2-5 min par step, code complet à chaque step, no placeholders, self-review final.

2. **Applique ces overrides HubEE par-dessus** :

### Localisation du plan

Au lieu de `docs/superpowers/plans/YYYY-MM-DD-<feature>.md`, sauvegarder dans :

```
.notes/<branch>/plan.md
```

Le dossier `.notes/` est gitignored (c'est un brouillon local, jamais commité). Format `<branch>` = nom de branche git (ex : `chore-claude-setup`, `feat-subscription-batch`).

Si la branche n'existe pas encore, le plan peut être à la racine `.notes/<feature-slug>/plan.md` en attendant.

### Langue

- **Contenu du plan en français** (titres, descriptions de tasks, justifications)
- **Noms techniques en anglais** : noms de skills, types Conventional Commits (`feat:`, `fix:`, etc.), noms de fichiers/classes
- Code et commentaires de code dans la convention du projet (anglais pour les comments Ruby HubEE)

### Branch naming HubEE

Le plan référence une branche au format Conventional Commits :

| Préfixe | Usage |
|---|---|
| `feat/` | Nouvelle fonctionnalité |
| `fix/` | Bug fix |
| `chore/` | Maintenance |
| `docs/` | Documentation |
| `refactor/` | Restructure sans changer le comportement |
| `test/` | Tests |

Slug en kebab-case court : `feat/subscription-batch-creation`, pas `feat/SubscriptionBatchCreation`.

### Commits référencés dans les steps

Quand un step inclut un commit, **invoque la skill `commit` du plugin HubEE** (pas un `git commit` direct dans le step). Exemple :

```markdown
- [ ] **Step N : Commit**

Invoque la skill `commit` (Conventional Commits FR + bin/ci automatique + clipboard handoff).
```

### CI mentionnée explicitement

Pour chaque task qui touche du code Ruby/Rails, prévoir un step dédié `bin/ci` avant le commit :

```markdown
- [ ] **Step N : Lancer bin/ci complet**

```bash
bin/ci
```

Expected : Style ✓, Security ✓, Tests ✓ (591 tests, 0 failure).
```

### Tests RSpec — référencer la skill HubEE

Quand un step écrit un test, mentionner les conventions du plugin :

```markdown
- [ ] **Step N : Écrire le spec**

Suivre la skill `tdd-workflow` du plugin HubEE (RSpec/FactoryBot/SimpleCov 80% mini, descriptions `it`/`describe` en anglais).
```

### Journal des sessions

Le plan inclut une section finale `## Journal des sessions` qu'on enrichit à chaque reprise (date, ce qui a été fait, ce qui reste). Pratique courante HubEE pour suivre les chantiers longs sur plusieurs sessions.

```markdown
## Journal des sessions

### Session 2026-04-26

- Décisions structurantes prises : ...
- Phase 1 terminée
- Bloqué sur : ...
- Prochaine étape : ...
```

## Anti-patterns HubEE

- ❌ Plan dans `docs/superpowers/plans/` (utiliser `.notes/<branch>/plan.md`)
- ❌ Plan en anglais (sauf code/identifiers)
- ❌ Branche sans préfixe Conventional (`my-feature`, `WIP`)
- ❌ Commits inline avec `git commit -m` (toujours invoquer `commit` skill)
- ❌ Step "écrire les tests" sans référencer `tdd-workflow`
