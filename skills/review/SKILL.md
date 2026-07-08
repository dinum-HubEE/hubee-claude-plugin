---
name: review
description: Passer en revue le code modifié sur la branche courante en confrontant le diff aux skills de domaine autoritaires (méthode + routage), sans dupliquer leurs règles. À utiliser quand on demande de relire des changements, avant d'ouvrir ou de marquer une MR prête, ou avant de demander une review humaine.
---

# Revue de code HubEE

> Revue **avant push / avant MR** pour les projets HubEE. Ce skill n'est **pas une checklist figée** : c'est une **méthode** qui délimite le diff, **associe** chaque chemin modifié au skill de domaine qui fait autorité, et confronte le diff à la **version actuelle complète** de ce skill. Le seul contenu propre à la revue = la table de routage + les vérifications natives qui n'existent dans aucun skill de domaine. La table de routage ci-dessous est orientée **Rails** (cas le plus courant chez HubEE) ; la méthode reste valable pour d'autres stacks, en routant vers leurs propres conventions.

## Méthode

### 1. Délimiter le diff

```bash
git fetch origin main
git log origin/main..HEAD --oneline
git diff origin/main..HEAD --stat
```

Lister les fichiers **modifiés / ajoutés / supprimés**. C'est le périmètre exact de la revue.

### 2. Associer les chemins aux skills de domaine

Pour chaque fichier du diff, identifier le ou les skills de domaine concernés via la **table de routage** ci-dessous.

### 3. Charger les skills de domaine concernés

Charger réellement chaque skill associé (pas une copie mentale). Le contenu autoritaire des règles vit **dans ces skills**, pas ici.

### 4. Confronter le diff à la VERSION ACTUELLE du skill

Lire le diff ligne à ligne et le confronter au **contenu actuel complet** du skill chargé. C'est volontairement plus complet et sans dérive qu'une checklist recopiée : si un skill de domaine gagne une règle demain, la revue l'applique automatiquement, sans qu'on ait à la reporter ici.

### 5. Trier les constats

Classer chaque écart en **✅ OK / ⚠️ attention / 🛑 bloquant / suggestion** (voir format de sortie dans les vérifications natives).

## Table de routage

Le diff touche ces chemins → charger ces skills et confronter le diff à leur contenu actuel.

| Le diff touche… | → charger |
|---|---|
| `app/models/`, `app/services/` | `models`, `ruby-style`, `principles` |
| `app/controllers/` | `controllers`, `choosing-a-pattern`, `ruby-style` |
| `app/interactors/` | `interactors`, `principles` |
| `spec/**` | `rspec-conventions`, `test-strategy` |
| `app/views/`, `app/helpers/`, `app/javascript/`, `app/assets/` | `frontend-rails`, `dsfr-skill`, RGAA |
| `sessions_controller`, `app/services/keycloak/`, `omniauth`, `concerns/authentication` | `authentication`, `security` |
| `lib/http_client`, `lib/hub_api`, `lib/keycloak` | `api-client` |
| `.claude/`, `.agent-vm.runtime.sh`, `.claude-container/` | vérifications agent-vm (ci-dessous) |

Mention rapide pour ne rien oublier : diff touche des vues ? → `frontend-rails` + `dsfr-skill` + RGAA. Diff touche des specs ? → `rspec-conventions` (+ `test-strategy` pour le périmètre). Ne **pas** recopier le détail des règles ici : on les lit dans le skill chargé.

## Vérifications natives

Ces vérifications n'existent dans **aucun** skill de domaine : elles sont propres à la revue et restent concrètes ici.

### Verrou `bin/ci`

- `bin/ci` passe en local : **Style ✓ / Sécurité ✓ / Tests ✓ / Brakeman 0**. Tant que le verrou n'est pas vert, la revue ne valide pas.

### Hygiène du diff

- Pas de **TODO/FIXME** ajoutés sans ticket associé.
- Pas de **N+1** introduit (relation chargée en boucle sans `includes`/`preload`).
- Pas de **secrets** dans le diff : `.env*`, `master.key`, `credentials.yml.enc`. Pas de **gros binaires** sans raison. Le hook `pre-edit-secrets` du plugin l'empêche — à revérifier ici.

### Vérifications agent-vm

Si le diff touche `.claude/`, `.agent-vm.runtime.sh`, `.claude-container/` :

- Pas d'**identifiants en dur** (token, mot de passe, clé).
- `permissions.deny` **cohérent** avec la doctrine.
- `.gitignore` **à jour** (`.env`, `.claude/settings.local.json`, etc.).
- Si modif `setup.sh` : reste **impersonnel** (pas de nom propre en dur).

### Taille de la MR

- Si **> 20 fichiers** modifiés, proposer un **découpage en plusieurs MR**.

### Cohérence avec le plugin

Pour chaque écart ⚠️ ou 🛑 identifié, distinguer sa cause :

- **La convention est documentée** dans le skill de domaine chargé → l'écart est actionnable normalement (signaler + proposer le fix), rien de plus à faire.
- **La convention est absente ou ambiguë** dans le skill (le diff fait quelque chose de raisonnable que le skill ne couvre pas, ou le contourne parce que l'exemple du skill est incomplet) → signaler l'écart **ET** noter le gap de documentation dans la section "🔧 Évolutions plugin suggérées" en fin de rapport, avec le skill concerné et la règle à préciser. Ne pas ouvrir de PR sur le plugin soi-même depuis une revue de projet — se contenter de le noter.

Cette section est **optionnelle** : ne l'inclure que si un gap a été identifié pendant la revue.

### Format de sortie

```markdown
## Revue de la branche `<nom-de-branche>`

**Périmètre** : N commits, M fichiers (+X -Y lignes)
**Skills consultés** : [liste des skills de domaine chargés via la table de routage]
**CI locale** : ✅ verte | ❌ rouge ([détail])

### ✅ Points OK
- [Bonnes pratiques constatées]

### ⚠️ Points d'attention
- [À relire humainement, non bloquant]

### 🛑 Bloquants
- [À corriger AVANT push]

### Suggestions
- [Améliorations optionnelles]

### 🔧 Évolutions plugin suggérées (si applicable)
- `<skill>` : <gap constaté et règle à préciser>
```

### Politique de sortie

- **S'il y a un bloquant** : ne pas proposer la MR tant qu'il n'est pas levé (sauf **dérogation explicite** de l'utilisateur).
- **Si aucun bloquant** : suggérer d'enchaîner sur la skill `finishing-branch` pour préparer la MR.

## Anti-patterns Claude

- ❌ Marquer la revue "✅ tout va bien" sans avoir lu les fichiers en détail ni chargé les skills de domaine associés.
- ❌ Recopier ici les règles d'un skill de domaine (Rails, RSpec, RGAA, DSFR, Keycloak, HttpClient) : elles dérivent et donnent une fausse confiance. **Charger le skill et confronter à sa version actuelle.**
- ❌ Lister 50 détails mineurs sans hiérarchiser.
- ❌ Proposer un refacto majeur en revue (ce n'est pas le moment : ouvrir une issue à la place).
- ❌ Ignorer les vérifications UI/RGAA si le diff touche des vues (routage `app/views/` → `frontend-rails` + `dsfr-skill` + RGAA, obligatoire).
- ❌ Enchaîner sur `finishing-branch` automatiquement sans avoir validé que les bloquants sont levés.
