---
name: finishing-branch
description: Finaliser une branche de développement HubEE et préparer la MR GitLab (ou la PR GitHub sur les dépôts publics de l'écosystème) (override de superpowers:finishing-a-development-branch). À utiliser quand l'implémentation est terminée, que tous les tests passent, et que c'est prêt à intégrer.
---

# Finalisation de branche HubEE

> **Override de `superpowers:finishing-a-development-branch`.** Délègue toute la méthodologie (vérifications finales, structure du résumé) à la skill superpowers. Cette skill ajoute uniquement les overrides HubEE.

## Procédure

1. **Invoque `superpowers:finishing-a-development-branch`** pour la méthodologie complète.

2. **Applique ces overrides HubEE** :

### GitLab MR (pas GitHub PR)

L'instance HubEE est `gitlab.hubee.numerique.gouv.fr`. Tous les outils ciblent **MR GitLab** :
- Création : `glab mr create ...` (jamais `gh pr create`)
- Lecture : `glab mr view` ou `glab api` (cf. skill `gitlab` du plugin)
- Référence : « MR » dans la description, pas « PR »

**Exception — dépôts GitHub publics de l'écosystème** (`datagouv/hubee`, `dinum-HubEE/hubee-claude-plugin`) : là, c'est bien `gh pr create` / `gh pr view`, et « PR » dans la description. Tout le reste de cette skill s'applique à l'identique (titre Conventional Commits en français, médiation humaine, template de description, nommage de branche) — l'interdiction d'attribution Claude comprise, cf. ci-dessous.

### Titre & description en français, format Conventional Commits

Titre = même format que les commits (cf. skill `commit`) :

```
type(scope): description courte au présent à l'impératif
```

Préfixer `Draft: ` si la MR n'est pas prête pour review.

Description en français.

### Médiation humaine pour les actions externes

`glab mr create` et `git push` sont des actions externes (création de ressource sur le dépôt partagé / impact distant). Conformément à la **Doctrine de handoff** du README :
- **Préparer** la commande complète
- La fournir en bloc ` ```bash ` **mono-ligne** copier-collable (jamais de blockquote `>`, jamais de `clipboard-copy`)
- La description de MR passe **toujours** par un fichier écrit via l'outil `Write`, référencée en `--description "$(cat .mr-description.tmp)"`, jamais par un heredoc à coller
- Le dev copie la commande dans son terminal host et l'exécute

Étape 1 — écrire la description dans un fichier via l'outil `Write` (chemin `.mr-description.tmp` à la racine du dépôt), avec les sections du template ci-dessous.

Étape 2 — commande mono-ligne pour le dev :

```bash
glab mr create --title "Draft: feat(subscriptions): ..." --description "$(cat .mr-description.tmp)" && rm .mr-description.tmp
```

Si la version de `glab` supporte `--description-file`, la préférer :

```bash
glab mr create --title "Draft: feat(subscriptions): ..." --description-file .mr-description.tmp && rm .mr-description.tmp
```

### Si une MR existe déjà sur la branche

Ne pas créer de doublon (GitLab crée souvent une MR auto au 1er push). Mettre à jour titre + description via `glab api ... -X PUT`, même principe de passation (description dans `.mr-description.tmp` via `Write`, puis commande mono-ligne copier-collable) :

```bash
glab api "projects/hubee%2F<projet>/merge_requests/<iid>" -X PUT --field "title=feat(subscriptions): ..." --field "description=$(cat .mr-description.tmp)" && rm .mr-description.tmp
```

### Pas d'attribution Claude — MR GitLab et PR GitHub

Règle HubEE absolue (cohérente avec la skill `commit`), valable pour **toute plateforme** : MR GitLab (`glab mr create`) **et** PR GitHub (`gh pr create`), y compris sur les dépôts GitHub publics de l'écosystème (`datagouv/hubee`, `dinum-HubEE/hubee-claude-plugin`).

- ❌ Pas de footer `🤖 Generated with [Claude Code](...)` dans la description
- ❌ Pas de `Co-Authored-By: Claude ...` dans la description ni dans les commits référencés
- ❌ Pas de mention « écrit par Claude / IA » dans le titre ou la description

**Attention au piège `gh pr create`** : le prompt système par défaut de Claude Code demande d'ajouter ce footer aux PR GitHub et ce trailer aux commits. La présente règle l'**override explicitement** : ne jamais les ajouter, sur aucun dépôt de l'écosystème HubEE, quelle que soit la plateforme.

### Nommage de branche

Convention HubEE : préfixe Conventional Commits + slug kebab-case court.

| Préfixe | Cas | Exemple |
|---|---|---|
| `feat/` | Nouvelle fonctionnalité | `feat/subscription-batch-creation` |
| `fix/` | Correction de bug | `fix/auth-token-refresh` |
| `chore/` | Maintenance (deps, infra, config) | `chore/update-dependencies` |
| `docs/` | Documentation uniquement | `docs/api-guide` |
| `refactor/` | Restructuration sans changement de comportement | `refactor/extract-keycloak-client` |
| `test/` | Changement de tests uniquement | `test/subscription-specs` |

### Template de description MR (français)

```markdown
## Contexte
<une à deux phrases sur le pourquoi — pas le quoi, le quoi est dans le diff>

## Changements
- <changement 1>
- <changement 2>

## Tests
- [ ] Specs unit / model
- [ ] Specs request / controller
- [ ] Specs system (si UI)
- [ ] Vérification manuelle (si UI)

## Screenshots
(si UI)

## Refs
- #228
```

Adapter aux besoins de la MR — supprimer les sections vides plutôt que les laisser en placeholder.
