---
name: explore-rails
description: Naviguer rapidement un projet Rails HubEE en suivant la chaîne route → controller → service → model → view → spec. Use when user asks "comment ça marche X", "où est Y", "trouve la logique de Z" dans une codebase Rails.
---

# Explore Rails HubEE Skill

> Stratégie d'**exploration ciblée** d'un projet Rails. Plus efficace que `grep -r` brut : suit la chaîne d'appel naturelle Rails. Combine bien avec l'agent `explore` du plugin (méthodologie générale).

## Quand utiliser cette skill

- "Comment ça marche, la création d'une subscription ?"
- "Où est gérée l'authentification Keycloak ?"
- "Trouve la logique qui valide les SIRET"
- "Montre-moi le flow d'un export CSV"
- "Quelle vue affiche la liste des organisations ?"

## Stratégie principale : top-down depuis la route

C'est l'**ordre canonique Rails** : URL → routes → controller → action → vue/service/model.

### Étape 1 : Trouver la route

```bash
bin/rails routes -g <pattern-ou-controller>
```

Exemples :
- `bin/rails routes -g subscription` → toutes les routes liées
- `bin/rails routes -g organizations#index` → action spécifique
- `bin/rails routes` puis pipe à `grep` pour des patterns plus complexes

Output Rails routes :
```
                Prefix Verb   URI Pattern                       Controller#Action
         subscriptions GET    /subscriptions(.:format)          subscriptions#index
                       POST   /subscriptions(.:format)          subscriptions#create
```

### Étape 2 : Ouvrir le controller correspondant

`Controller#Action` → `app/controllers/<controller>_controller.rb` (ou nested : `app/controllers/admin/<controller>_controller.rb`)

Lire l'action concernée :
- Quels params elle attend (`params.require(...)`, `permit(...)`)
- Quelles méthodes elle appelle (helpers, services, modèles)
- Quelle réponse elle rend (`render`, `redirect_to`, `respond_to`)
- `before_action` qui s'appliquent

### Étape 3 : Suivre les services / models / helpers appelés

Identifier dans le controller :
- Les **services** : `app/services/<...>.rb` (ex : `Subscriptions::Creator.new(params).call`)
- Les **models** : `app/models/<...>.rb` (ex : `Organization.find_by_siret(...)`)
- Les **helpers** : `app/helpers/<...>_helper.rb`
- Les **concerns** : `app/controllers/concerns/<...>.rb` ou `app/models/concerns/<...>.rb`

Pour chaque, ouvrir et lire la méthode concernée.

### Étape 4 : Suivre les views si l'action rend du HTML

Convention Rails : `app/views/<controller>/<action>.html.erb`.

Examples :
- `subscriptions#index` → `app/views/subscriptions/index.html.erb`
- Ne pas oublier les **partials** (`_<name>.html.erb`) référencés via `<%= render "partial_name" %>`

Pour les **Turbo Frames / Streams**, chercher `<turbo-frame id="...">` dans la vue + l'action qui répond en `*.turbo_stream.erb`.

### Étape 5 : Trouver les specs correspondants

Convention de nommage RSpec :
- Controller `app/controllers/X_controller.rb` → `spec/requests/X_spec.rb` (le projet utilise request specs, pas controller specs)
- Service `app/services/X.rb` → `spec/services/X_spec.rb`
- Model `app/models/X.rb` → `spec/models/X_spec.rb`
- View → souvent pas de spec direct, couvert par system spec dans `spec/system/`

Lire les specs donne souvent **plus d'info sur l'usage attendu** que le code lui-même.

## Stratégies alternatives

### Bottom-up : depuis un terme métier

Si on ne connaît pas la route mais juste un mot métier (ex : "SIRET", "subscription", "Keycloak") :

```bash
# Rechercher la déclaration la plus probable d'abord
rg "class \w*Siret" --type ruby
rg "module Keycloak" --type ruby

# Puis usage
rg "SIRET" --type ruby --type erb -l   # liste de fichiers
rg -A2 "SIRET" app/models/   # contexte autour
```

Privilégier `rg` (ripgrep) à `grep -r` (plus rapide, ignore .git, gitignore-aware).

### Par fichier : "qui appelle ce code ?"

```bash
# Qui invoque la classe MyClass ?
rg "MyClass" --type ruby -l

# Qui invoque la méthode #my_method ?
rg "\.my_method\b" --type ruby
rg "\.my_method!" --type ruby   # variante !
```

### Points d'entrée métier : propres à l'app

Les routes/ressources métier dépendent de l'app (le plugin est cross-app). Pour les
découvrir : `bin/rails routes` + le `CLAUDE.md` de l'app. Note : toutes les apps
HubEE ne sont pas en Rails — ailleurs, la méthode de navigation est à adapter.

## Convention de structure HubEE

```
app/
├── controllers/
│   ├── application_controller.rb       (auth, exceptions)
│   ├── concerns/                        (Authentication, etc.)
│   └── <resource>_controller.rb         (RESTful)
├── models/
│   ├── application_record.rb
│   └── concerns/                        (modules réutilisables)
├── services/
│   ├── <namespace>/                     (ex: Keycloak::, Subscriptions::)
│   └── <namespace>/<action>.rb          (ex: Keycloak::LogoutUrlBuilder)
├── interactors/                         (logique métier, gem interactor)
│   ├── <resource>/<action>.rb           (organizer, = <Resource>Controller#<action>)
│   ├── <resource>/<action>/<step>.rb    (interactor, étape atomique)
│   └── <resource>/shared/<step>.rb      (étape partagée entre actions)
├── views/
│   ├── layouts/
│   ├── shared/                          (partials cross-controllers)
│   └── <controller>/
└── javascript/
    └── controllers/                     (Stimulus, fichier par controller)

lib/
├── http_client.rb                       (module HTTP générique)
├── hub_api/                             (API HubeeV1)
│   ├── client.rb
│   └── <resource>.rb                    (Data.define)
└── keycloak/
    ├── client.rb
    └── user.rb

spec/
├── requests/                            (controllers = request specs HubEE)
├── models/
├── services/
├── interactors/                        (un spec par organizer + par étape)
├── system/                              (E2E Capybara)
├── factories/                           (FactoryBot)
└── support/                             (helpers, shared examples)
```

## Avant de plonger : ne pas oublier les skills HubEE

Beaucoup de questions sur l'architecture sont **déjà répondues dans les skills du plugin** :

| Question | Skill |
|---|---|
| "Comment marche l'auth Keycloak ?" | `authentication` |
| "Comment écrire un service appelant une API externe ?" | `api-client` |
| "Comment ajouter du Turbo / Stimulus ?" | `hotwire` |
| "Comment écrire une spec X ?" | `tdd-workflow` |
| "Quel pattern écrire pour X ?" / "Conventions controller, modèle ?" | `rails-patterns` (routeur) |
| "Logique métier / interactor / organizer ?" | `interactors` |
| "Requête complexe / query object ?" | `query-objects` |
| "Objet formulaire ?" | `form-objects` |
| "Cycle de vie / états / AASM ?" | `state-machine` |
| "Décision d'architecture ?" | `architecture` |

**Toujours vérifier ces skills d'abord** plutôt que de re-explorer la codebase si la doc existe déjà.

## Anti-patterns Claude

- ❌ Faire `find . -type f` direct (lent, bruité)
- ❌ Cat un controller entier pour trouver une méthode (utiliser `rg` + lire le bon range)
- ❌ Inventer une convention de nommage (toujours partir de `bin/rails routes`)
- ❌ Skipper la lecture des specs quand on cherche le comportement attendu
- ❌ Re-explorer un sujet déjà documenté dans une skill du plugin
