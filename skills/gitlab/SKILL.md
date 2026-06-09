---
name: gitlab
description: Lire issues, MR, board, labels et fichiers depuis l'instance GitLab HubEE via la CLI glab. À utiliser quand l'utilisateur demande de lire un ticket/issue/MR, de consulter un statut de board, de vérifier un label, ou de récupérer un fichier depuis un autre dépôt HubEE.
---

# GitLab HubEE

> Skill **lecture seule** pour interagir avec `gitlab.hubee.numerique.gouv.fr` depuis Claude (dans la VM agent-vm). Toute opération d'écriture (commenter, modifier, créer une MR) suit la **médiation humaine** : Claude prépare une commande copier-collable en bloc ` ```bash ` mono-ligne (cf. **Doctrine de handoff** du README), le dev l'exécute sur son host.

## Pré-requis

Cette skill suppose que :
- `glab` est installé dans la VM (fourni par `setup.sh` du dépôt `hubee-agent-vm-config`)
- `glab auth login` a été fait dans `~/.agent-vm/runtime.sh` perso avec un PAT scopes `read_api` + `read_repository`
- `glab config set --global host gitlab.hubee.numerique.gouv.fr` a été fait (sinon glab cherche sur gitlab.com par défaut → 404 / Unauthenticated)

Vérifier rapidement :
```bash
glab auth status   # → ✓ Logged in to gitlab.hubee.numerique.gouv.fr
glab config get host   # → gitlab.hubee.numerique.gouv.fr
```

Si l'un échoue : signaler à l'utilisateur qu'il doit configurer son `~/.agent-vm/runtime.sh` (cf. README de `hubee-agent-vm-config`).

## Cas d'usage

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

### Lister les issues ouvertes d'un dépôt

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

### Lire un fichier d'un autre dépôt HubEE

Quand on veut consulter le code d'un autre projet HubEE (ex : voir comment le projet Java implémente l'auth Keycloak) sans cloner :

```bash
# Le chemin doit être encodé en URL dans l'API
glab api "projects/hubee%2F<projet>/repository/files/<path-url-encodé>/raw?ref=main"
```

Exemple : lire `app/services/keycloak/client.rb` du portail admin :
```bash
glab api "projects/hubee%2Fadmin-portal/repository/files/app%2Fservices%2Fkeycloak%2Fclient.rb/raw?ref=main"
```

### Lister les fichiers d'un dépôt (structure)

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

### Encodage URL du chemin de dépôt

Toutes les API GitLab attendent le chemin encodé : `/` → `%2F`. Donc `hubee/admin-portal` → `hubee%2Fadmin-portal`.

### Dépôts courants HubEE

| Dépôt | Description |
|---|---|
| `hubee/admin-portal` | Portail d'administration (Rails 8.1, V1) |
| `hubee/hubee-agent-vm-config` | Config partagée agent-vm (ce dépôt) |
| (autres à compléter au fil des projets) | |

> Pour le plugin Claude HubEE, c'est sur **GitHub** : `dinum-HubEE/hubee-claude-plugin` (pas GitLab — l'instance interne n'a pas d'accès internet sortant pour mirror push).

### Ne pas confondre les niveaux d'API

- **`glab issue view`** : commande haut-niveau, output formaté pour humain
- **`glab api projects/...`** : API REST brute, output JSON, plus précis pour Claude qui parse

Pour Claude, **préférer `glab api`** quand on veut extraire des données (jq).

## Écriture (avec médiation humaine)

Si l'utilisateur demande de **modifier** quelque chose (commenter une issue, fermer une MR, ajouter un label), Claude **prépare la commande** en bloc ` ```bash ` **mono-ligne** copier-collable (cf. **Doctrine de handoff** du README — jamais de `clipboard-copy`, jamais de blockquote `>` autour de la commande) — le dev l'exécute sur le host (où il a son PAT scope écriture). Le message d'une commande d'écriture (note, commentaire) passe **toujours** par un fichier écrit via l'outil `Write`, référencé en mono-ligne (`--message "$(cat .gl-note.tmp)"`).

Exemple : commenter une issue (écrire d'abord le message dans `.gl-note.tmp` via l'outil `Write`) :

```bash
glab issue note 228 --repo hubee/admin-portal --message "$(cat .gl-note.tmp)" && rm .gl-note.tmp
```

Puis informer :

> ✅ Commande prête. Colle la commande dans ton terminal host pour publier le commentaire (ton PAT host a sans doute le scope `api` write).

Si l'utilisateur a configuré le wrapper `glab-board` (Project Access Token write scopé sur un seul dépôt, cf. `runtime.sh.example`), il peut éventuellement exécuter directement dans la VM — mais Claude ne devrait pas présumer.

## Erreurs courantes

| Erreur | Cause | Correctif |
|---|---|---|
| `404 Not Found` | host par défaut = gitlab.com | `glab config set --global host gitlab.hubee.numerique.gouv.fr` |
| `Unauthenticated` | pas d'auth ou mauvais host | `glab auth login --hostname gitlab.hubee.numerique.gouv.fr --token "..."` |
| `Unknown flag: --hostname` | flag pas supporté sur cette sous-commande | utiliser `GITLAB_HOST=...` inline ou config par défaut |
| `Could not send telemetry data: 401` | warning bénin glab essaie gitlab.com pour télémétrie | ignorer |
| `403 Forbidden` sur écriture | scope du PAT trop restreint | besoin scope `api` (avec `write_*`) sur le host, pas dans la VM |
