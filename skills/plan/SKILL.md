---
name: plan
description: Rédiger un plan d'implémentation HubEE (override de superpowers:writing-plans avec conventions HubEE). Use when user asks to write a plan, design an approach, or before starting a multi-step implementation.
---

# Plan HubEE Skill

> **Override de `superpowers:writing-plans`.** Délègue toute la méthodologie (structure de fichier, granularité 2-5 min par step, code complet, no placeholders, self-review) à la skill superpowers. Cette skill ajoute uniquement les overrides HubEE.

## Procédure

1. **Invoque `superpowers:writing-plans`** pour la méthodologie complète.

2. **Applique ces overrides HubEE** :

### Langue

Plan rédigé en **français** (titres, descriptions des tasks, justifications). Noms techniques en anglais (skills, types Conventional Commits, classes, fichiers).

### Branch naming

Branche au format Conventional Commits, slug en kebab-case court :

| Préfixe | Exemple |
|---|---|
| `feat/` | `feat/subscription-batch-creation` |
| `fix/` | `fix/auth-token-refresh` |
| `chore/` | `chore/update-dependencies` |
| `docs/` | `docs/api-guide` |
| `refactor/` | `refactor/extract-keycloak-client` |
| `test/` | `test/subscription-specs` |

### Skills HubEE référencées dans les steps

- Steps "commit" → invoquer la skill `commit` du plugin (pas `git commit` direct dans le step)
- Steps "écrire un test" → suivre la skill `tdd-workflow` du plugin (RSpec/FactoryBot/SimpleCov, descriptions en anglais)
