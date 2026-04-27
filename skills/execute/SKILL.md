---
name: execute
description: Exécuter un plan d'implémentation HubEE step-by-step (override de superpowers:executing-plans avec conventions HubEE). Use when a plan is written and ready to be executed task by task.
---

# Execute HubEE Skill

> **Override de `superpowers:executing-plans`.** Délègue à la skill superpowers pour la méthodologie d'exécution (lecture du plan, tracking via checkboxes, checkpoints user, progression task-by-task). Cette skill ajoute uniquement les overrides HubEE.

## Procédure

1. **Invoque `superpowers:executing-plans`** pour la méthodologie complète : lecture du plan, exécution séquentielle des tasks, tracking des checkboxes `[ ]` → `[x]`, checkpoints de validation user.

2. **Applique ces overrides HubEE** :

### Plan localisé dans `.notes/<branch>/plan.md`

Au lieu de `docs/superpowers/plans/...`, lire `.notes/<branch>/plan.md` (cf. skill `plan` du plugin HubEE).

### Commits entre tasks

Entre chaque task ou groupe de tasks cohérent, **invoquer la skill `commit`** du plugin HubEE (au lieu de `git commit` direct). La skill `commit` :
- Lance `bin/ci` automatiquement
- Refuse de commiter si CI rouge
- Pousse la commande dans le clipboard host (médiation humaine)

### TDD

Pour les steps "écrire un test" / "implémenter", suivre la skill `tdd-workflow` du plugin HubEE (RSpec/FactoryBot/SimpleCov, RED-GREEN-REFACTOR, descriptions en anglais).

### Validation user à chaque task

Conformément à la doctrine HubEE (médiation humaine), demander une **validation explicite** au user :
- Avant tout commit
- Avant toute action destructive (`git rebase`, `git reset`, suppression de fichier)
- Avant tout push (sera traité par la skill `finishing-branch` à la fin)
- À chaque checkpoint majeur du plan (fin de phase, choix architectural)

Ne pas enchaîner les tasks silencieusement même si elles sont "évidentes" — le rythme HubEE est : faire 1 task → valider → faire la suivante.

### Mise à jour du journal

À la fin de chaque session, mettre à jour le `## Journal des sessions` du plan :
- Date du jour
- Tasks accomplies
- Décisions prises pendant l'exécution
- Bloqueurs rencontrés
- Prochaine étape pour la reprise

### Détection de divergence avec le plan

Si pendant l'exécution une décision du plan se révèle inadaptée (ex : approche technique qui ne marche pas, ressource externe absente) :
- **Stopper l'exécution**
- Documenter la divergence dans le plan
- Re-invoquer la skill `plan` pour mettre à jour
- Reprendre l'exécution une fois le plan amendé et validé

Ne jamais exécuter en silence un plan qui ne correspond plus à la réalité.

## Anti-patterns HubEE

- ❌ Enchaîner 5 tasks sans checkpoint user
- ❌ `git commit` direct (toujours invoquer la skill `commit`)
- ❌ Skipper `bin/ci` pour aller plus vite
- ❌ Modifier le plan en silence (toute divergence doit être consignée)
- ❌ Marquer une task `[x]` sans avoir vraiment vérifié le résultat
