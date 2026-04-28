---
name: hubee-recap
description: Construire un résumé mensuel des développements HubEE à partir des MR/PR mergées (GitLab `gitlab.hubee.numerique.gouv.fr` + GitHub publics `datagouv/hubee` et `dinum-HubEE/hubee-claude-plugin`). La sortie met en avant des **Évolutions notables** synthétisées par thème, suivies d'une annexe détaillée. Use when user asks to summarize a month of development on HubEE (e.g. "résume-moi les développements sur HubEE en avril"), optionally scoped to a single repo.
---

# HubEE Recap Skill

> **Doctrine** : génère un résumé Markdown des **MR/PR mergées** sur la période, en agrégeant **GitLab HubEE** (groupe `hubee`, sous-groupes inclus) + **GitHub** (`datagouv/hubee`, `dinum-HubEE/hubee-claude-plugin`). La sortie est structurée en deux parties : **Évolutions notables** synthétisées par thème (sortie principale), puis détail par projet (annexe). Lançable depuis n'importe quel projet.

## Sources couvertes

| Plateforme | Hôte | Repos | CLI | Auth |
|---|---|---|---|---|
| GitLab | `gitlab.hubee.numerique.gouv.fr` | tout le groupe `hubee` (id 4, sous-groupes inclus) | `glab api` | déjà configurée localement |
| GitHub | `github.com` | `datagouv/hubee`, `dinum-HubEE/hubee-claude-plugin` | `curl` direct sur `api.github.com` (`gh api` exige un token même pour repos publics) | repos publics, anonyme OK (rate-limit 60/h, 2 requêtes nécessaires) |

## Quand cette skill s'active

- « résume-moi les développements sur HubEE en avril »
- « recap du mois dernier sur HubEE »
- « qu'est-ce qui a été livré ce mois-ci »
- « évolutions notables sur HubEE en mars »

## Étape 1 — Parser l'intention du user

Extraire du prompt :

| Élément | Comment | Exemple |
|---|---|---|
| **Mois** | Nom de mois français → numéro. Année implicite = courante. | « avril » → `2026-04` |
| **Scope** | « sur HubEE » ou rien → toutes sources. « sur le repo X » → un seul projet. « sur GitLab seulement » / « GitHub seulement » → restreindre. | `hubee-rails` |
| **Auteur** | « par Damien » → filtrer par auteur (optionnel) | — |

**Si ambigu** (mois absent, période flottante) : **demander avant d'appeler les API**.

Bornes ISO 8601 UTC :
- Début : `YYYY-MM-01T00:00:00Z`
- Fin : premier jour du mois suivant à `00:00:00Z` (borne exclusive)

## Étape 2 — Récupérer les MR/PR mergées

### 2a. GitLab (multi-projets, défaut)

```bash
glab api --paginate "groups/4/merge_requests?state=merged&scope=all&include_subgroups=true&updated_after=${SINCE}&per_page=100"
```

⚠️ **Le filtre `merged_after` / `merged_before` est silencieusement ignoré** sur l'endpoint groupe. Utiliser `updated_after` côté serveur, puis **filtrer côté client** sur `merged_at` strictement dans la période. Garder cette correction dans le code, c'est un piège.

Parsing : `glab --paginate` concatène les pages en `[...][...]`. Utiliser `python3` (pas `jq` — les titres MR contiennent parfois des caractères de contrôle non échappés qui cassent jq).

### 2b. GitLab (mono-projet)

```bash
glab api --paginate "projects/hubee%2F${REPO}/merge_requests?state=merged&updated_after=${SINCE}&per_page=100"
```

### 2c. GitHub (2 repos publics)

GitHub n'expose pas `merged_after`/`merged_before` sur `/repos/:o/:r/pulls`. Utiliser **Search Issues** :

```bash
curl -s "https://api.github.com/search/issues?q=repo:datagouv/hubee+is:pr+is:merged+merged:${START_DAY}..${END_DAY}&per_page=100"
curl -s "https://api.github.com/search/issues?q=repo:dinum-HubEE/hubee-claude-plugin+is:pr+is:merged+merged:${START_DAY}..${END_DAY}&per_page=100"
```

`gh api` exige un token même pour repos publics → utiliser `curl` directement sur `api.github.com` pour rester anonyme.

## Étape 3 — Normaliser et catégoriser

Structure commune par MR/PR :
```
{ source, project, iid, title, url, author, merged_at }
```

### Mapping d'identités GitHub ↔ GitLab

Un même contributeur apparaît sous deux noms différents : `Damien Le Thiec` côté GitLab (`author.name`) et `@damienlethiec` côté GitHub (`user.login`). **Les fusionner via une table d'alias** pour que le compteur de contributeurs ne double pas la même personne.

Table HubEE actuelle (à enrichir au fil de l'eau) :

| GitHub login | Nom canonique (GitLab) |
|---|---|
| `damienlethiec` | Damien Le Thiec |

Algorithme :
1. Pour chaque MR/PR GitHub, regarder le login (sans `@`).
2. Si le login est dans la table → remplacer `author` par le nom canonique.
3. Sinon → garder `@login` tel quel et **signaler dans le recap** au dev qu'un nouveau login est apparu (lui demander à qui il correspond pour enrichir la table).

L'enrichissement se fait en **éditant cette table dans le SKILL.md** lui-même (la skill est versionnée dans le plugin, donc l'ajout d'un alias profite à toute l'équipe).

**Catégoriser pour les évolutions notables** :

- **Bruit à exclure des notables** (mais à garder dans l'annexe) :
  - `author == "renovate-bot"` ou `"Renovate Bot"` ou `"dependabot"`
  - Titre matchant `chore(deps)`, `chore(docker)`, `Update <lib> to v...`, `bump <dep>`, `Update <something> Docker tag`, `Update digest`
- **Notables candidats** :
  - Préfixes Conventional Commits : `feat(...)`, `fix(...)` significatifs, `refactor(...)` substantiels
  - Auteurs humains
  - Ne pas confondre `feat` mineur (label, copy edit) avec une évolution notable — utiliser le jugement à partir du titre

## Étape 4 — Format de sortie Markdown

### Structure : Évolutions notables groupées PAR REPO avec sous-titres thématiques

```markdown
# Résumé HubEE — Avril 2026

**Période** : 2026-04-01 → 2026-04-28
**Sources** : GitLab `hubee` (sous-groupes inclus) + GitHub `datagouv/hubee`, `dinum-HubEE/hubee-claude-plugin`
**Total** : 48 MR/PR mergées sur 10 projets — **23 évolutions** + **25 bumps de dépendances**

---

## Évolutions notables par repo

### hubee/admin-portal (GitLab) — 14 évolutions

#### Authentification & Keycloak

- **Refresh transparent du token Keycloak expiré via le refresh token** ([!87](url)) — Julien Anne
- **`ServiceAccountClient` pour l'authentification `client_credentials`** ([!78](url)) — Julien Anne
- ...

#### Refactors HTTP client

- **Hiérarchies d'erreurs HTTP par namespace** ([!76](url)) — Julien Anne
- ...

#### Outillage dev

- **Adoption de Claude Code via le plugin partagé `hubee-claude-plugin`** ([!96](url)) — Damien Le Thiec
- ...

### hubee/hub-api (GitLab) — 4 évolutions

#### Montées de versions

- **Tomcat 10.1.54** ([!34](url)) — Julien Anne
- ...

#### Outillage dev

- **`mise.toml` + `.agent-vm.runtime.sh` pour java/maven en VM** ([!36](url)) — Damien Le Thiec

### hubee/batch-* (GitLab) — 4 évolutions (patch coordonné)

#### Observabilité

- **Ping Hyperping au démarrage et à la fin de job** déployé sur les 4 batchs : [batch-notification-email!1](url), [batch-notifications-from-hub!1](url), [batch-organizations-from-hub!1](url), [batch-processes-from-hub!1](url) — Damien Le Thiec

### datagouv/hubee (GitHub) — 1 évolution

#### Notifications

- **Feature: add notifications** ([#15](url)) — Damien Le Thiec

---

## Maintenance & bumps de dépendances

- **hubee/admin-portal** — 14 bumps renovate-bot : Ruby 4.0.3, Puma v8, ...
- **hubee/hub-api** — 8 bumps renovate-bot : Spring Boot 3.5.13, ...
- **hubee/renovate-ci** — 1 bump : Renovate v43.139.6

---

## Contributeurs

- **Julien Anne** — 16
- **Damien Le Thiec** — 7
- **Bastien Ogier** — 2
- *renovate-bot* — 23 (mises à jour de dépendances)
```

### Règles de formatage

**Hiérarchie de titres** :

- `#` Titre du recap (1 seul)
- `##` Sections principales : « Évolutions notables par repo », « Maintenance & bumps de dépendances », « Contributeurs »
- `###` Repo : `### {project} ({GitLab|GitHub}) — N évolution(s)`
- `####` Sous-titre thématique à l'intérieur d'un repo (regroupe les bullets par thème)

**Pas d'emoji** dans les titres ni en début de bullets. Le rendu doit être propre et copiable dans n'importe quel outil (mail, doc, ticket).

**Section « Évolutions notables par repo »** (cœur du recap) :

- Tri repos : **par nombre d'évolutions notables décroissant** (pas par volume total — le but est de mettre en valeur les repos qui ont vraiment bougé).
- Si plusieurs `batch-*` ont reçu le **même patch coordonné**, les fusionner sous un titre groupe `### hubee/batch-* (GitLab)` avec un seul bullet et liens multiples. Sinon, garder une section par repo.
- **Sous-titres thématiques `####` à l'intérieur d'un repo** : grouper les évolutions par thème pour faciliter la lecture quand un repo en a beaucoup. Thèmes typiques HubEE :
  - Authentification & Keycloak
  - Refactors HTTP client / services / domain
  - Plateforme & infrastructure
  - Observabilité
  - Outillage dev
  - Bugfixes
  - Montées de versions
  - Notifications
  - Sécurité (CVE, contrôle d'accès, audit)
- Si un repo a **2 évolutions ou moins**, on peut omettre les sous-titres `####` et lister directement les bullets sous le `###` du repo.
- **Format bullet** : `Titre humain reformulé ([!iid](url)) — Auteur`
  - **Pas de gras sur le titre**. Texte simple. Le gras est réservé aux noms de contributeurs et à des éléments de la section synthèse maintenance/header.
  - L'iid est dans le lien sous forme `!123` (GitLab) ou `#123` (GitHub) — courte référence.
  - Le titre peut être reformulé depuis le titre brut de la MR si plus clair (ex: `feat(keycloak): ajouter ServiceAccountClient pour l'authentification client_credentials` → `ServiceAccountClient pour l'authentification \`client_credentials\``). Ne pas garder le préfixe Conventional Commits dans le titre humain.
- Si un repo n'a **aucune** évolution notable (que des bumps), ne pas afficher de section `###` pour lui ici — il ira dans la maintenance.

**Section « Maintenance & bumps de dépendances »** :

- **Pas la liste détaillée**, juste une synthèse : 1 bullet par repo concerné avec un compteur et 3-5 mots-clés sur ce qui a bougé.
- Repos sans bump : pas affichés.
- Si un repo a **uniquement** des bumps (aucune évolution notable), il apparaît ici uniquement.

**Section « Contributeurs »** : compteur tri descendant. Bots en italique en bas avec mention `(mises à jour de dépendances)`.

**Suppression** : plus d'« Annexe — détail par projet » exhaustive. Si le user veut le détail de toutes les MR d'un repo, il clique sur les liens ou demande explicitement.

## Étape 5 — Présentation au dev

**Sortir le recap dans un bloc de code fenced ```` ```markdown ... ``` ```` ** pour que le user puisse le copier-coller tel quel ailleurs (ticket, mail, doc Notion, etc.). Le rendu en chat affiche alors la source brute, et `clic-droit → copier le bloc` ou simple sélection donne le markdown copiable.

Format de la sortie :

````
```markdown
# Résumé HubEE — {Mois} {Année}

**Période** : ...
...

[contenu complet du recap]
```
````

**Ne pas** écrire dans un fichier sauf demande explicite. **Ne pas** répéter le recap rendu en plus du bloc — un seul bloc fenced suffit.

Si le user demande explicitement à voir le rendu (« montre-moi le rendu HTML/visuel »), sortir une deuxième fois sans le fence.

## Cas particuliers

- **Aucune MR/PR sur la période** : « Aucune MR/PR mergée sur HubEE en {mois} ». Vérifier les bornes de date.
- **`glab` non authentifié (401)** : `glab auth login --hostname gitlab.hubee.numerique.gouv.fr`.
- **Mois en cours** : préciser `(mois en cours, partiel)` dans le header et borner à la veille de la date courante.
- **Période > 1 mois** : possible mais signaler le coût d'API. Valider avant.
- **MR mergée puis revertée** : reste comptée (recap d'activité, pas d'état final).
- **Travail pushé directement sur `main`** (pas de MR) : non couvert. Mentionner dans une note finale courte si on en a connaissance (ex : commits du repo plugin lui-même).
- **Scope « GitLab seulement » / « GitHub seulement » / mono-repo** : restreindre la requête + ajuster le périmètre du header.

## Anti-patterns à éviter

- ❌ Mettre les évolutions notables en annexe et le détail brut en haut — la sortie principale doit être les notables, pas la liste brute
- ❌ Grouper par thème transversal au lieu de par repo (le repo concerné doit être visible immédiatement — c'est l'unité de lecture). Le thème vient en `####` à l'intérieur du repo, pas comme axe principal de la sortie
- ❌ Ajouter des emojis dans les titres ou en début de bullets (`### 🟦 ...`, `- 🔐 ...`) — le rendu doit rester propre et copiable partout
- ❌ Mettre les titres de MR/PR en gras (`- **Titre** (...)`) — les titres restent en texte simple, le gras est réservé aux noms et au header
- ❌ Splitter le préfixe Conventional Commits hors du titre dans la liste maintenance (`chore(deps) [titre](url)` ❌ → `[chore(deps): titre](url)` ✅, mais en réalité on n'a plus de liste détaillée maintenance)
- ❌ Inclure les MR `chore(deps)` renovate dans les évolutions notables
- ❌ Lister 6 fois la même évolution parce qu'elle est sur 6 batchs (fusionner)
- ❌ Filtrer côté serveur avec `merged_after` sur l'endpoint `groups/:id/merge_requests` (silencieusement ignoré)
- ❌ Utiliser `gh api` pour les repos publics anonymes (exige un token) — basculer sur `curl api.github.com` direct
- ❌ Compter `@damienlethiec` (GitHub) et `Damien Le Thiec` (GitLab) comme deux contributeurs distincts — appliquer la table d'alias avant agrégation
- ❌ Inférer le mois sans demander si le user a écrit « le mois dernier » sans contexte clair
- ❌ Tronquer l'annexe « pour la lisibilité » — le user veut le détail
- ❌ Ajouter une signature `🤖 Generated with Claude Code` au résumé (règle HubEE)
