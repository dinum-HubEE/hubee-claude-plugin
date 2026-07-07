---
name: convention-audit
description: À utiliser quand on veut auditer la cohérence d'un projet entier vis-à-vis des conventions, principes et style du plugin (audit global, mise en conformité, repérer les incohérences de convention dans toute la base) — au-delà d'une simple review de diff.
---

# Audit de conventions

## Principe

Audit **global** de la cohérence d'un projet avec les conventions du plugin. C'est la skill `review` appliquée à **tout le projet** au lieu d'un diff, et orientée **cohérence intra-projet** : repérer là où le projet **se contredit lui-même** (deux patterns pour la même chose) ou s'écarte d'une convention, sur l'ensemble de la base.

**Règle fondatrice : cette skill ne recopie AUCUNE règle.** Elle **charge les skills de convention et confronte le code à leur version actuelle**. Recopier les règles ici les ferait diverger (elles ne seraient jamais à jour) et rendrait l'audit incomplet. En déférant aux skills, l'audit reste complet et fidèle par construction.

## Quand l'utiliser / quand pas

- **Oui** : audit périodique, avant un gros refacto, prise en main d'un projet, « est-ce que la base est cohérente ? ».
- **Non — review d'un diff avant MR** → skill `review`.
- **Non — règles mécaniques** (indentation, casse, `frozen_string_literal`) → StandardRB les couvre déjà ; ne pas les ré-auditer (cf. frontière de responsabilité du README).

## Méthode

### 1. Délimiter le périmètre

Tout le projet par défaut, ou un sous-arbre ciblé. Lister les fichiers par type.

### 2. Charger les skills de **convention** (pas de process)

Critère : **« COMMENT le code doit être écrit »** → audité ; **« workflow / quoi faire quand »** → ignoré.

- **Audités** : `principles`, `rails-patterns`, `interactors`, `tdd-workflow` (conventions), `frontend-rails`, `api-client`, `hotwire`, `authentication`, `security`, `performance`.
- **Ignorés** (process) : `commit`, `review`, `finishing-branch`, `plan`, `execute`, `gitlab`, `explore-rails`, `build-fix`.

**REQUIS** : réutiliser la **table de routage de la skill `review`** pour associer chemins → skills (single-source, pas de copie). **Charger** chaque skill applicable ; ne jamais recopier ses règles ici.

### 3. Confronter le projet à la version ACTUELLE de chaque skill

Pour chaque dimension, chercher :
- les **violations claires** d'une convention ;
- surtout les **incohérences intra-projet** : la même chose faite de deux façons (mesurer la **prévalence** — « 70 % en A, 30 % en B »).

### 4. Classer chaque constat

- **Cosmétique** = non-ambigu, **zéro décision de fond**, alignement mécanique sur une convention claire → **appliqué d'office dans la PR de correctif**.
- **Fond** = nécessite un **arbitrage** (quel pattern standardiser, incohérence architecturale, abstraction discutable) → **rapport uniquement**, l'utilisateur tranche.

### 5. Produire le rapport d'arbitrage

Écrire un **fichier** `docs/audits/audit-conventions-AAAA-MM-JJ.md` (pas seulement dans le chat — pour arbitrer à tête reposée et tracer). **Grouper par décision à prendre**, pas par occurrence. Pour chaque point de fond : prévalence, skill concerné, recommandation, impact estimé.

### 6. Après arbitrage → PR de correctif

PR **claire et dédiée** (cosmétique + décisions validées), **séparée des features**, `bin/ci` vert. Handoff via les skills `commit` / `finishing-branch`.

## Couverture (anti-oubli)

- Lister explicitement les zones/dimensions **couvertes ET non couvertes** — jamais de troncature silencieuse (un audit qui dit « tout est cohérent » alors qu'il a sauté une zone est pire que pas d'audit).
- Gros projet : traiter **par zone/dimension**, éventuellement en fan-out (**superpowers:dispatching-parallel-agents**).

## Format du rapport

```markdown
# Audit de conventions — <projet> — AAAA-MM-JJ

**Périmètre couvert** : [zones/dimensions] · **Non couvert** : [...]
**Skills de convention confrontés** : [liste]

## 🔧 Cosmétique (appliqué d'office dans la PR)
- [Skill] <constat> — N occurrences

## ⚖️ Fond (à arbitrer)
### <Décision à prendre>
- **Skill** : … · **Prévalence** : 70 % A / 30 % B · **Reco** : …
- **Impact** : <fichiers / risque>

## ✅ Conforme
- [Dimensions où le projet est cohérent]
```

## Anti-patterns

- ❌ Recopier les règles d'un skill ici → elles dérivent. **Charger le skill, confronter à sa version actuelle.**
- ❌ Ré-auditer ce que StandardRB couvre (mécanique).
- ❌ Noyer le rapport sous 200 constats → **hiérarchiser par décision**, mesurer la prévalence.
- ❌ Auditer des skills de **process**.
- ❌ Appliquer des changements de **fond** sans arbitrage de l'utilisateur.
- ❌ Committer sur `main` : tout passe par une **PR** relue.
- ❌ Conclure « cohérent » sans dire ce qui n'a **pas** été couvert.
