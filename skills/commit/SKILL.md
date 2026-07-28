---
name: commit
description: Préparer un commit HubEE (Conventional Commits en français + bin/ci automatique + passation copier-collable). À utiliser quand l'utilisateur demande de commiter, après avoir terminé une feature/correctif/refactor, avant un push, ou quand des changements stagés sont prêts à être persistés.
---

# Commit HubEE

> **Doctrine** : Claude **prépare** le commit, le **dev exécute** sur le host (médiation humaine — la VM est en `--git-ro`, Claude ne peut de toute façon pas commiter). La passation suit la **Doctrine de handoff** du README : toute commande est fournie en bloc ` ```bash ` **mono-ligne** copier-collable (jamais de blockquote `>` autour d'une commande, jamais de `clipboard-copy`), et le contenu multi-ligne (message de commit) passe par un fichier écrit via l'outil `Write` puis référencé en mono-ligne (`git commit -F`). Le dev copie la commande dans son terminal host et valide.

## Quand cette skill s'active

- L'utilisateur dit explicitement "fais un commit", "prépare un commit", "commit ça"
- Une fonctionnalité/correctif/refactor vient d'être terminé et est prêt à être persisté
- Il y a des changements stagés ou non-stagés cohérents à commiter

## Étapes du processus

### 1. État de l'arbre de travail

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

C'est la règle stricte du projet (cf. règle `git-workflow` du plugin). Le commit n'est **jamais** proposé tant que `bin/ci` n'est pas vert.

**Si `bin/ci` échoue** :
- Identifier l'étape qui plante (Style, Security, Tests, etc.)
- Proposer le correctif au dev
- Re-lancer `bin/ci`
- Refuser de proposer le commit tant que c'est rouge (sauf si le dev demande explicitement de bypass — alors préciser **clairement** le risque)

### 3. Lire le contexte

Avant de rédiger le message, lire :
- Le ticket lié si visible (numéro de branche, mention dans le diff)
- Le `.notes/<branch>/tdd-session.md` ou `.notes/<branch>/plan.md` s'ils existent (contexte de la fonctionnalité)
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

**Body** : **concis, viser 2-5 lignes**.
- Body **omis** uniquement pour les commits totalement triviaux (typo, lint, renommage évident).
- Pour le reste (feat, fix, refactor, chore non-trivial) : **2-5 lignes de body** qui apportent un contexte utile :
  - Le **pourquoi** non-évident depuis le diff (décision de design, contrainte, ticket à régler)
  - Les **changements clés** en 1-3 puces courtes si le commit touche plusieurs choses
- **Plafond strict : 6 lignes de body** (hors `Refs:`). Si ça dépasse, c'est que ça appartient à la description de la MR, pas au commit. Reformule plus court.
- Wrapping à 72 caractères, séparé par une ligne vide après la description.
- Pas de redite du titre dans le body. Pas de paragraphe explicatif détaillé.
- Tickets liés : `Refs: #228` sur sa propre ligne en bas si pertinent.

**Exemple de bonne longueur** :
```
feat(subscriptions): permettre la création par lot

Endpoint POST /subscriptions/batch pour éviter les N+1 round-trips
des imports manuels. Validation SIRET en amont.

Refs: #228
```

**Pas de `Co-Authored-By: Claude`** — règle HubEE absolue (cf. règle `git-workflow`).

### 5. Présenter le message **avec** la commande copier-collable, en un seul tour

Présenter la proposition (récap fichiers + CI + message) **et** fournir directement la commande prête à coller de l'étape 6 dans le **même** message. **Pas de gate « tu valides ? »** : c'est le dev qui choisit — ou non — de coller la commande dans son terminal ; ce choix *est* la validation. Ne jamais s'arrêter pour attendre un « oui » avant de livrer la commande.

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

_(La commande copier-collable de l'étape 6 suit immédiatement, dans le même message.)_
```

Si le dev demande ensuite un ajustement (message, découpage, fichiers), reprendre à l'étape 4 et re-livrer message + commande. Sinon, il colle la commande quand il veut — ou pas.

### 6. Écrire le message dans un fichier + commande mono-ligne

**Doctrine de handoff** : coller une commande `git commit -m` multi-ligne dans un terminal casse les retours à la ligne. La solution robuste est d'écrire le message dans un fichier du dépôt via l'outil `Write`, puis de fournir au dev une commande **mono-ligne** sans aucun caractère à échapper.

**Étape 1 — écrire le fichier** (via l'outil `Write`, **pas** `cat <<EOF` en bash) :

```
Chemin : <racine-du-dépôt>/.commit-msg.tmp
Contenu :
feat(subscriptions): permettre la création par lot

Endpoint POST /subscriptions/batch pour éviter les N+1 round-trips
des imports manuels. Validation SIRET en amont.

Refs: #228
```

**Étape 2 — commande mono-ligne pour le dev — méthode unique « toujours par fichier »** :

Toujours passer la liste des fichiers via fichier avec `git add --pathspec-from-file=` (jamais énumérer les chemins en arguments). Écrire les chemins (un par ligne) dans `.commit-files.tmp` via l'outil `Write`, puis :

```bash
git add --pathspec-from-file=.commit-files.tmp && git commit -F .commit-msg.tmp && rm .commit-files.tmp .commit-msg.tmp
```

Toujours **une seule ligne** sur le host, peu importe le nombre de fichiers. Pas d'échappement des chemins (gère les espaces/accents). Requiert Git ≥ 2.25.

**Éviter `git add .` ou `git add -A`** : risque d'inclure secrets / binaires / fichiers non intentionnels. Toujours lister explicitement les chemins dans `.commit-files.tmp`.

Le `&&` enchaîne stage → commit → cleanup ; si une étape plante, les suivantes ne tournent pas (les fichiers `.tmp` restent → permet de débugger sans réécrire le message).

**Étape préalable intégrée, jamais dans un bloc séparé.** Si la séquence exige un préalable (`git reset` parce que des `git mv` sont déjà indexés, `git fetch`, `bundle install`), il s'enchaîne par `&&` dans la **même** commande — cf. « Une commande, une étape sautable en moins » (Doctrine de handoff, README). Un bloc `git reset` distinct peut être sauté sans que rien ne le signale : les fichiers déjà indexés partent alors dans le **premier** commit et cassent tous les suivants, chacun paraissant réussir.

**Multi-commits dans la même session** : nommer les fichiers `.commit-files-1.tmp` / `.commit-msg-1.tmp`, `.commit-files-2.tmp` / `.commit-msg-2.tmp`, etc. Au-delà de ~3 commits, ne pas livrer un bloc par commit — livrer **une commande unique** qui boucle sur les fichiers numérotés :

```bash
( for i in $(seq 1 10); do git add --pathspec-from-file=.commit-files-$i.tmp && git commit -F .commit-msg-$i.tmp || exit 1; done ) && rm .commit-files-*.tmp .commit-msg-*.tmp
```

La sous-shell `( … )` fait qu'un échec interrompt la boucle **sans** déclencher le `rm` final : les `.tmp` restent en place pour diagnostiquer et reprendre au bon indice.

Puis informer le dev :

> ✅ Message écrit dans `.commit-msg.tmp`. Colle la commande ci-dessus dans ton terminal host pour committer. Le `bin/ci` a déjà été passé localement, pas besoin de le relancer côté host.

**Le fichier `.commit-msg*.tmp` doit rester non-tracké**. Le supprimer après le commit (déjà inclus via `&& rm` dans la commande). Le pattern `*.commit-msg*.tmp` peut être ajouté au `.gitignore` global si nécessaire, mais en pratique le `&& rm` suffit.

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

_(Les commandes des deux commits, dans l'ordre, suivent immédiatement.)_
```

Fournir directement les commandes copier-collables sans attendre de validation du découpage — un bloc par commit jusqu'à ~3, une commande unique qui boucle au-delà (voir § précédent), tout préalable enchaîné par `&&` dans le premier bloc. Si le dev préfère un autre découpage, il le dit et on re-livre.

## Erreurs courantes à signaler

- **Branche `main`/`master`** : avertir mais ne pas bloquer (le hook `pre-bash` le fait déjà côté Claude). Suggérer une branche de fonctionnalité si pertinent.
- **`git commit --amend`** : refuser sans validation explicite (rewrite l'historique). Si le commit est déjà push, c'est destructif.
- **Fichiers `.env*`, `master.key`, `credentials.yml.enc`, `config/credentials/`** : refuser de les inclure (`pre-edit-secrets` hook le fait déjà mais double-check).
- **Fichiers binaires lourds** (>1 MB) sans bonne raison : signaler.

## Anti-patterns Claude doit éviter

- ❌ Lancer `git commit` directement (la médiation humaine impose la passation par fichier)
- ❌ S'arrêter sur un « tu valides ? » et attendre un « oui » avant de livrer la commande — la commande accompagne toujours la proposition ; c'est le dev qui décide de la coller ou non
- ❌ Donner une commande `git commit -m "..."` multi-ligne au dev — les retours à la ligne se cassent au collage. Utiliser `git commit -F .commit-msg.tmp` mono-ligne
- ❌ Livrer une étape préalable (`git reset`, `git fetch`) dans un bloc séparé — elle s'enchaîne par `&&` dans la première commande, sinon elle peut être sautée en silence et tout ce qui suit tourne sur un état non prévu
- ❌ Mettre `Co-Authored-By: Claude` dans le message
- ❌ Bypass `bin/ci` sans demande explicite du dev
- ❌ Proposer un message en anglais
- ❌ `git commit -m "wip"` ou messages vagues
- ❌ Mentionner numérotation interne PR/issue inexistante
- ❌ `--no-verify` sans avertir
- ❌ Body verbeux (> 6 lignes) qui paraphrase le diff ou rejoue le contenu de la MR
- ❌ Pas de body du tout sur un commit non-trivial — un contexte court (2-5 lignes) aide la relecture six mois plus tard
