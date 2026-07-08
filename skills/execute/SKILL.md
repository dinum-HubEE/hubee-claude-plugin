---
name: execute
description: Exécuter un plan d'implémentation HubEE step-by-step (override de superpowers:executing-plans avec conventions HubEE). Use when a plan is written and ready to be executed task by task.
---

# Execute HubEE Skill

> **Override de `superpowers:executing-plans`.** Délègue toute la méthodologie d'exécution (lecture du plan, tracking via checkboxes, checkpoints user, progression task-by-task) à la skill superpowers. Cette skill ajoute uniquement les overrides HubEE.

## Procédure

1. **Invoque `superpowers:executing-plans`** pour la méthodologie complète.

2. **Applique ces overrides HubEE** :

### Skills HubEE pendant l'exécution

- Tout commit → invoquer la skill `commit` du plugin (jamais `git commit` direct, jamais bypass `bin/ci`)
- Tout test → suivre les skills `rspec-conventions` (+ `test-strategy` pour le périmètre) du plugin (RSpec/FactoryBot/SimpleCov, descriptions en anglais, RED-GREEN-REFACTOR)
