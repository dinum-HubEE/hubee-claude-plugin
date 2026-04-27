---
name: finishing-branch
description: Finaliser une branche de développement HubEE et préparer la MR GitLab (override de superpowers:finishing-a-development-branch). Use when implementation is complete, all tests pass, and ready to integrate.
---

# Finishing Branch HubEE Skill

> **Override de `superpowers:finishing-a-development-branch`.** Délègue toute la méthodologie (vérifications finales, structure du résumé) à la skill superpowers. Cette skill ajoute uniquement les overrides HubEE.

## Procédure

1. **Invoque `superpowers:finishing-a-development-branch`** pour la méthodologie complète.

2. **Applique ces overrides HubEE** :

### GitLab MR (pas GitHub PR)

L'instance HubEE est `gitlab.hubee.numerique.gouv.fr`. Tous les outils ciblent **MR GitLab** :
- Création : `glab mr create ...` (jamais `gh pr create`)
- Lecture : `glab mr view` ou `glab api` (cf. skill `gitlab` du plugin)
- Référence : « MR » dans la description, pas « PR »

### Titre & description en français, format Conventional Commits

Titre = même format que les commits (cf. skill `commit`) :

```
type(scope): description courte au présent à l'impératif
```

Préfixer `Draft: ` si la MR n'est pas prête pour review.

Description en français.

### Médiation humaine pour les actions externes

`glab mr create` et `git push` sont des actions externes (création de ressource sur le repo partagé / impact remote). Conformément à la doctrine :
- **Préparer** la commande complète
- **Pousser dans le clipboard** via `clipboard-copy` (OSC52)
- Le dev exécute sur son host

Exemple :

```bash
cat <<'EOF' | clipboard-copy
glab mr create --title "Draft: feat(subscriptions): ..." --description "$(cat <<'DESC'
## Contexte
...
DESC
)"
EOF
```

### Si une MR existe déjà sur la branche

Ne pas créer de doublon (GitLab crée souvent une MR auto au 1er push). Mettre à jour titre + description via `glab api ... -X PUT --field title=... --field description=...`, et pousser cette commande dans le clipboard pareil.
