---
name: gitlab
description: Lire issues, MR, board, labels et fichiers depuis l'instance GitLab HubEE via la CLI glab. Use when user asks to read a ticket/issue/MR, look up a board status, check a label, or fetch a file from another HubEE repo.
---

# GitLab HubEE Skill

> Skill **lecture seule** pour interagir avec `gitlab.hubee.numerique.gouv.fr` depuis Claude (dans la VM agent-vm). Toute opération d'écriture (commenter, modifier, créer une MR) suit la **médiation humaine** via clipboard handoff.

## Pré-requis

Cette skill suppose que :
- `glab` est installé dans la VM (fourni par `setup.sh` du repo `hubee-agent-vm-config`)
- `glab auth login` a été fait dans `~/.agent-vm/runtime.sh` perso avec un PAT scopes `read_api` + `read_repository`
- `glab config set --global host gitlab.hubee.numerique.gouv.fr` a été fait (sinon glab cherche sur gitlab.com par défaut → 404 / Unauthenticated)

Vérifier rapidement :
```bash
glab auth status   # → ✓ Logged in to gitlab.hubee.numerique.gouv.fr
glab config get host   # → gitlab.hubee.numerique.gouv.fr
```

Si l'un échoue : signaler au user qu'il doit configurer son `~/.agent-vm/runtime.sh` (cf. README de `hubee-agent-vm-config`).

## Patterns d'usage

### Lire un ticket / une issue

```bash
glab issue view <iid> --repo hubee/<projet>
# ou via API directe (plus de détails JSON) :
glab api "projects/hubee%2F<projet>/issues/<iid>" | jq
```

Exemple : lire l'issue #228 du portail admin :
```bash
glab issue view 228 --repo hubee/admin-portal
```

### Lister les issues ouvertes d'un repo

```bash
glab issue list --repo hubee/<projet>
glab issue list --repo hubee/<projet> --label "en cours"
glab issue list --repo hubee/<projet> --assignee @me
```

### Lire une MR

```bash
glab mr view <iid> --repo hubee/<projet>
glab mr diff <iid> --repo hubee/<projet>   # voir le diff
```

### Lister les MR d'une branche

```bash
glab mr list --repo hubee/<projet> --source-branch <branch-name>
```

### Lire un fichier d'un autre repo HubEE

Quand on veut consulter le code d'un autre projet HubEE (ex : voir comment le projet Java implémente l'auth Keycloak) sans cloner :

```bash
# Le path doit être URL-encodé dans l'API
glab api "projects/hubee%2F<projet>/repository/files/<path-url-encodé>/raw?ref=main"
```

Exemple : lire `app/services/keycloak/client.rb` du portail admin :
```bash
glab api "projects/hubee%2Fadmin-portal/repository/files/app%2Fservices%2Fkeycloak%2Fclient.rb/raw?ref=main"
```

### Lister les fichiers d'un repo (structure)

```bash
glab api "projects/hubee%2F<projet>/repository/tree?recursive=true&per_page=100"
```

### Board / labels

```bash
glab label list --repo hubee/<projet>
# Le board complet n'est pas natif glab — passer par l'API :
glab api "projects/hubee%2F<projet>/boards"
glab api "projects/hubee%2F<projet>/boards/<board-id>/lists"
```

## Conventions HubEE

### URL encoding du path repo

Toutes les API GitLab attendent le path encodé : `/` → `%2F`. Donc `hubee/admin-portal` → `hubee%2Fadmin-portal`.

### Repos courants HubEE

| Repo | Description |
|---|---|
| `hubee/admin-portal` | Portail d'administration (Rails 8.1, V1) |
| `hubee/hubee-agent-vm-config` | Config partagée agent-vm (ce repo) |
| (autres à compléter au fil des projets) | |

> Pour le plugin Claude HubEE, c'est sur **GitHub** : `dinum-HubEE/hubee-claude-plugin` (pas GitLab — l'instance interne n'a pas d'accès internet sortant pour mirror push).

### Ne pas confondre les niveaux d'API

- **`glab issue view`** : commande haut-niveau, output formaté pour humain
- **`glab api projects/...`** : API REST brute, output JSON, plus précis pour Claude qui parse

Pour Claude, **préférer `glab api`** quand on veut extraire des données (jq).

## Patterns d'écriture (avec médiation humaine)

Si le user demande de **modifier** quelque chose (commenter une issue, fermer une MR, ajouter un label), Claude **prépare la commande** et la **pousse dans le clipboard** — le dev exécute sur le host (où il a son PAT scope écriture).

Exemple : commenter une issue :

```bash
cat <<'EOF' | clipboard-copy
glab issue note 228 \
  --repo hubee/admin-portal \
  --message "Implémenté dans la MR !96, en review"
EOF
```

Puis informer :

> ✅ Commande copiée dans ton clipboard. Colle (`Cmd+V`) sur ton host pour publier le commentaire (ton PAT host a sans doute le scope `api` write).

Si le user a configuré le wrapper `glab-board` (Project Access Token write scopé sur un seul repo, cf. `runtime.sh.example`), il peut éventuellement exécuter directement dans la VM — mais Claude ne devrait pas présumer.

## Erreurs courantes

| Erreur | Cause | Fix |
|---|---|---|
| `404 Not Found` | host par défaut = gitlab.com | `glab config set --global host gitlab.hubee.numerique.gouv.fr` |
| `Unauthenticated` | pas d'auth ou mauvais host | `glab auth login --hostname gitlab.hubee.numerique.gouv.fr --token "..."` |
| `Unknown flag: --hostname` | flag pas supporté sur cette sous-commande | utiliser `GITLAB_HOST=...` inline ou config par défaut |
| `Could not send telemetry data: 401` | warning bénin glab essaie gitlab.com pour télémétrie | ignorer |
| `403 Forbidden` sur écriture | scope du PAT trop restreint | besoin scope `api` (avec `write_*`) sur le host, pas dans la VM |
