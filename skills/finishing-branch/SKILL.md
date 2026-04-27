---
name: finishing-branch
description: Finaliser une branche de développement HubEE et préparer la MR GitLab (override de superpowers:finishing-a-development-branch). Use when implementation is complete, all tests pass, and ready to integrate.
---

# Finishing Branch HubEE Skill

> **Override de `superpowers:finishing-a-development-branch`.** Délègue à la skill superpowers pour la méthodologie (vérification finale, options merge/PR/cleanup, structure du résumé). Cette skill ajoute le pattern **GitLab** spécifique HubEE (au lieu de GitHub) + conventions HubEE.

## Procédure

1. **Invoque `superpowers:finishing-a-development-branch`** pour la méthodologie complète : vérifications finales (tests, lint, security), structure de la description, présentation des options d'intégration.

2. **Applique ces overrides HubEE** :

### GitLab MR, pas GitHub PR

L'instance HubEE est `gitlab.hubee.numerique.gouv.fr` (cf. skill `gitlab` pour les détails sur `glab`). Tous les outils et commandes ciblent **MR GitLab** :
- Création : `glab mr create ...` (jamais `gh pr create`)
- Lecture/lookup : `glab api` ou `glab mr view`
- Référence : « MR » dans la description, pas « PR »

### Lecture du ticket source avant rédaction

Si la branche est nommée selon une convention `<type>/<ticket-slug>` ou si un ticket est mentionné dans `.notes/<branch>/plan.md`, **lire le ticket en amont** via la skill `gitlab` du plugin HubEE :

```bash
glab issue view <ticket-iid> --repo hubee/<projet>
# ou
glab api "projects/hubee%2F<projet>/issues/<iid>"
```

Reprendre les éléments clés (objectif, critères d'acceptation, contexte métier) dans la description de la MR.

### Titre MR — Conventional Commits français

Format identique aux commits (cf. skill `commit`) :

```
type(scope): description courte au présent à l'impératif
```

Exemples :
- `feat(subscriptions): permettre la création par lot`
- `fix(auth): corriger le refresh transparent du token`
- `chore(claude): adopter Claude Code via plugin partagé`

Si la MR reste en cours, préfixer par `Draft: ` (GitLab le reconnaît).

### Description MR — template HubEE

```markdown
## Contexte

[1-2 paragraphes : pourquoi cette MR existe, ticket source, problème métier]

## Changements

- [Liste à puces des changements clés, par module]
- [Référence aux fichiers importants]
- [Décisions techniques notables et leur justification]

## Tests

- [x] CI verte (X tests, Y% coverage)
- [x] Tests manuels effectués : ...
- [ ] Tests à reproduire par le reviewer : ...

## Critères d'acceptation (du ticket)

- [x] Critère 1
- [x] Critère 2
- [ ] Critère 3 (à valider par X)

## Refs

- Ticket source : #<iid>
- Sous-tickets regroupés (si applicable) : #X #Y
- Repos liés (plugin, config, etc.) : ...
```

### Médiation humaine pour la création de la MR

`glab mr create` est une **action externe** (création de ressource sur le repo partagé). Conformément à la doctrine HubEE :
- **Préparer** la commande complète avec titre + description
- **Pousser dans le clipboard** via `clipboard-copy` pour exécution sur le host

Exemple de handoff :

```bash
cat <<'EOF' | clipboard-copy
glab mr create \
  --title "Draft: feat(subscriptions): permettre la création par lot" \
  --description "$(cat <<'DESC'
## Contexte
[...]
DESC
)" \
  --target-branch main \
  --remove-source-branch
EOF
```

Puis informer le user :

> ✅ Commande `glab mr create` copiée dans ton clipboard. Colle (`Cmd+V`) sur ton host pour créer la MR. Vérifie le titre + description avant d'exécuter.

### Si la MR existe déjà

Si la branche a déjà une MR ouverte (cas typique : MR créée auto par GitLab au 1er push) :
- Ne pas créer de doublon
- Mettre à jour titre + description via `glab api ... -X PUT --field title=... --field description=...`
- Préparer cette commande et pousser dans le clipboard pareil

### Push hors VM

`git push` se fait sur le host (médiation humaine, doctrine §2.2). Préparer la commande pour le clipboard si la branche n'a pas encore été push :

```bash
cat <<'EOF' | clipboard-copy
git push -u origin <branch-name>
EOF
```

### Cleanup après merge

Une fois la MR mergée :
- Supprimer la branche locale (`git branch -d <branch>` après `git fetch && git branch -d`)
- Le `--remove-source-branch` côté GitLab a déjà supprimé la branche remote
- Archiver le `.notes/<branch>/` local (le déplacer ou le supprimer selon préférence du dev)

## Anti-patterns HubEE

- ❌ `gh pr create` (utiliser `glab mr create`)
- ❌ Titre/description en anglais
- ❌ Exécuter `glab mr create` directement sans clipboard handoff
- ❌ Créer une nouvelle MR si une est déjà ouverte sur la branche
- ❌ Push direct depuis la VM (toujours via clipboard handoff vers le host)
- ❌ Marquer "Ready for review" sans valider que CI verte côté GitLab pipeline
