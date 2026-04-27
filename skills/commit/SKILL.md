---
name: commit
description: Préparer un commit HubEE (Conventional Commits en français + bin/ci automatique + handoff clipboard). Use when the user asks to commit, after completing a feature/fix/refactor, before pushing, or when staged changes are ready to be persisted.
---

# Commit HubEE Skill

> **Doctrine** : Claude **prépare** le commit, le **dev exécute** sur le host (médiation humaine — la VM est en `--git-ro`, Claude ne peut de toute façon pas commiter). La commande de commit est poussée dans le **clipboard du host** via `clipboard-copy` (OSC52). Le dev colle (`Cmd+V`) sur son terminal host et valide.

## Quand cette skill s'active

- Le user dit explicitement "fais un commit", "prépare un commit", "commit ça"
- Une feature/fix/refactor vient d'être terminée et est prête à être persistée
- Il y a des changements stagés ou non-stagés cohérents à commiter

## Étapes du workflow

### 1. État du working tree

Lancer en parallèle :
```bash
git status
git diff --stat
git diff --cached --stat   # si déjà des changements stagés
```

Vérifier mentalement :
- Les modifs forment-elles **un seul commit cohérent** ? Sinon proposer un découpage en plusieurs commits.
- Y a-t-il des fichiers à NE PAS commiter ? (.env, master.key, secrets, fichiers générés type tmp/, log/) → si oui, signaler au dev.
- Y a-t-il des `console.log`, `binding.pry`, `debugger`, `puts` de debug oubliés ? → signaler.

### 2. CI locale (bin/ci) — **OBLIGATOIRE avant tout commit**

```bash
bin/ci
```

C'est la règle stricte du projet (cf. `git-workflow` rule du plugin). Le commit n'est **jamais** proposé tant que `bin/ci` n'est pas vert.

**Si `bin/ci` échoue** :
- Identifier l'étape qui plante (Style, Security, Tests, etc.)
- Proposer le fix au dev
- Re-lancer `bin/ci`
- Refuser de proposer le commit tant que c'est rouge (sauf si le dev demande explicitement de bypass — alors préciser **clairement** le risque)

### 3. Lire le contexte

Avant de rédiger le message, lire :
- Le ticket lié si visible (numéro de branche, mention dans le diff)
- Le `.notes/<branch>/tdd-session.md` ou `.notes/<branch>/plan.md` s'ils existent (contexte de la feature)
- Les commits précédents de la branche (`git log main..HEAD --oneline`) pour cohérence stylistique

### 4. Rédiger le message — Conventional Commits **en français**

Format strict :

```
type(scope): description courte au présent à l'impératif

Body multi-lignes optionnel en français qui explique le POURQUOI plutôt
que le QUOI (le quoi est dans le diff).

- Liste à puces si plusieurs points
- Référence au ticket si pertinent

Refs: #228 #229
```

**Types autorisés** :

| Type | Quand |
|---|---|
| `feat` | Nouvelle fonctionnalité utilisateur |
| `fix` | Correction de bug |
| `chore` | Maintenance (deps, config, build, infra) |
| `docs` | Documentation uniquement |
| `refactor` | Restructure sans changer le comportement |
| `test` | Ajout/modification de tests sans changement code |
| `style` | Reformatage (pas de logique modifiée) |
| `perf` | Amélioration de performance |

**Scope** : module/composant touché. Exemples HubEE : `auth`, `subscriptions`, `organizations`, `processes`, `agent-vm`, `claude-container`, `keycloak`, `api`, `deps`.

**Description** :
- 50-72 caractères max
- Présent impératif : "ajoute" pas "ajouté", "corrige" pas "corrigé"
- Pas de point final
- Minuscule au début

**Body** :
- Wrapping à 72 caractères
- Sépare par une ligne vide après la description
- Explique le **pourquoi** (le diff montre le quoi)
- Mentionne les tickets liés (`Refs: #228`)

**Pas de `Co-Authored-By: Claude`** — règle HubEE absolue (cf. `git-workflow` rule).

### 5. Présenter le message au dev pour validation

Format de présentation :

```markdown
## Commit proposé

**Fichiers** (3 modifiés, 1 supprimé) :
- M  app/controllers/subscriptions_controller.rb
- M  spec/requests/subscriptions_spec.rb
- M  config/routes.rb
- D  app/services/legacy_subscription_creator.rb

**CI** : ✅ verte (591 tests, 0 failure, brakeman clean)

**Message** :
```
feat(subscriptions): permettre la création par lot

Ajoute un endpoint POST /subscriptions/batch qui accepte un tableau
d'organizations et crée les abonnements correspondants en une seule
transaction. Évite les N+1 round-trips API que faisaient les imports
manuels.

- Nouveau service Subscriptions::BatchCreator
- Validation des SIRET avant création
- Specs request + service

Refs: #228
```

**Tu valides ?**
```

Attendre validation explicite du dev avant l'étape suivante.

### 6. Pousser la commande dans le clipboard host

Une fois le dev valide, pousser **uniquement la commande** dans son clipboard pour qu'il colle dans son terminal host :

```bash
cat <<'EOF' | clipboard-copy
git add app/controllers/subscriptions_controller.rb \
        spec/requests/subscriptions_spec.rb \
        config/routes.rb \
        app/services/legacy_subscription_creator.rb && \
git commit -m "feat(subscriptions): permettre la création par lot

Ajoute un endpoint POST /subscriptions/batch qui accepte un tableau
d'organizations et crée les abonnements correspondants en une seule
transaction. Évite les N+1 round-trips API que faisaient les imports
manuels.

- Nouveau service Subscriptions::BatchCreator
- Validation des SIRET avant création
- Specs request + service

Refs: #228"
EOF
```

Puis informer le dev :

> ✅ Commande copiée dans ton clipboard. Colle-la dans ton terminal host (`Cmd+V` puis `Entrée`) pour committer. Le `bin/ci` a déjà été passé localement, pas besoin de le relancer côté host.

> **Si le dev ne voit pas la commande coller** : son terminal ne supporte pas OSC52 (vérifier Ghostty / iTerm2 settings → "Allow programs to access clipboard"). Fallback : afficher la commande dans le chat pour copier-coller manuel.

### 7. Cas particulier : multi-commits

Si les modifs forment **plusieurs commits cohérents** (ex : refactor + feature qui s'appuie dessus), proposer un découpage explicite :

```markdown
## Découpage proposé en 2 commits

### Commit 1 — refactor
- M  app/services/legacy_subscription_creator.rb (extraction)
- M  spec/services/subscriptions/creator_spec.rb

```
refactor(subscriptions): extraire la création dans un service dédié

[...body...]
```

### Commit 2 — feat
- A  app/services/subscriptions/batch_creator.rb
- M  app/controllers/subscriptions_controller.rb
- M  spec/requests/subscriptions_spec.rb

```
feat(subscriptions): permettre la création par lot

[...body...]
```

**Tu valides ce découpage ?**
```

Le dev valide le découpage avant qu'on enchaîne sur 2 cycles `bin/ci` + clipboard.

## Erreurs courantes à signaler

- **Branche `main`/`master`** : avertir mais ne pas bloquer (`pre-bash` hook le fait déjà côté Claude). Suggérer une feature branch si pertinent.
- **`git commit --amend`** : refuser sans validation explicite (rewrite l'historique). Si le commit est déjà push, c'est destructif.
- **Fichiers `.env*`, `master.key`, `credentials.yml.enc`, `config/credentials/`** : refuser de les inclure (`pre-edit-secrets` hook le fait déjà mais double-check).
- **Fichiers binaires lourds** (>1 MB) sans bonne raison : signaler.

## Anti-patterns Claude doit éviter

- ❌ Lancer `git commit` directement (la médiation humaine impose le clipboard handoff)
- ❌ Mettre `Co-Authored-By: Claude` dans le message
- ❌ Bypass `bin/ci` sans demande explicite du dev
- ❌ Proposer un message en anglais
- ❌ `git commit -m "wip"` ou messages vagues
- ❌ Mentionner numérotation interne PR/issue inexistante
- ❌ `--no-verify` sans avertir
