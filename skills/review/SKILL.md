---
name: review
description: Reviewer le code changé sur la branche courante avec une checklist HubEE (Rails patterns + RSpec + StandardRB + Keycloak + RGAA + DSFR). Use when user asks to review changes, before opening/marking-ready a MR, or before requesting human review.
---

# Review HubEE Skill

> Checklist de **review automatique avant push / avant MR** pour les projets HubEE Rails. Couvre les conventions techniques (Rails, RSpec, StandardRB), métier (Keycloak, API HubEE), et frontend (DSFR + RGAA).

## Procédure

### 1. État des changements

```bash
git fetch origin main
git log origin/main..HEAD --oneline
git diff origin/main..HEAD --stat
```

Identifier les fichiers modifiés/ajoutés/supprimés. Si beaucoup de fichiers (>20), proposer un découpage en plusieurs MR.

### 2. Vérifications techniques (toujours)

#### Rails patterns

- [ ] **Skinny controllers, fat models** : la logique métier est dans models / services, pas dans controllers
- [ ] **Service objects** dans `app/services/` quand un controller a >1 action complexe
- [ ] **N+1 queries** : `includes` / `preload` ajoutés pour les relations chargées en boucle (cf. `tdd-workflow` skill, on devrait avoir des specs avec `expect { ... }.to make_database_queries(count: N)`)
- [ ] **Strong Parameters** sur tous les controllers qui acceptent du POST/PATCH
- [ ] **i18n** : pas de strings UI hardcodées (utiliser `t(...)`), même pour les flash messages
- [ ] **Routes RESTful** : pas de routes custom sans bonne raison

#### Tests (cf. skill `tdd-workflow`)

- [ ] **Couverture** : toute nouvelle route a un request spec, tout nouveau service/model a un unit spec
- [ ] **Descriptions en anglais** : `it "..."` / `describe "..."` (cf. rule `testing` du plugin)
- [ ] **Pas de `binding.pry` / `puts` / `pp`** oubliés dans les specs
- [ ] **`Faker` ou `FactoryBot.build_stubbed`** pour les data, pas de fixtures globales
- [ ] **Coverage 80%+** (`COVERAGE=true bundle exec rspec` puis vérifier `coverage/index.html`)
- [ ] **Tests system** (Capybara/Selenium) pour tout nouveau parcours utilisateur

#### Style & Sécurité

- [ ] `bin/ci` passe en local (Style ✓, Security ✓, Tests ✓, Brakeman 0 warning)
- [ ] Pas de `binding.pry`, `byebug`, `debugger`, `console.log` dans le code de prod
- [ ] Pas de fichiers `.env*`, `master.key`, `credentials.yml.enc` dans le diff (le hook `pre-edit-secrets` du plugin l'empêche, mais double-check)
- [ ] Pas de TODO/FIXME ajoutés sans ticket associé
- [ ] Pas de gros fichiers binaires sans bonne raison

### 3. Vérifications métier HubEE

#### Keycloak / Auth

Si le diff touche `app/controllers/sessions_controller.rb`, `app/services/keycloak/`, `config/initializers/omniauth.rb`, ou `app/controllers/concerns/authentication.rb` :

- [ ] Vérifier que `authenticate_user!` est bien dans le `ApplicationController` ou les controllers protégés
- [ ] Pas de bypass d'auth pour des "tests rapides"
- [ ] Refresh token géré (cf. `feat/session-keepalive` historique)
- [ ] Tester en mode dégradé (Keycloak unreachable, token expiré)
- [ ] Cf. skill `authentication` du plugin pour les patterns

#### API HubEE / HttpClient

Si le diff touche `lib/http_client.rb`, `lib/hub_api/`, ou `lib/keycloak/{client,user}.rb` :

- [ ] Architecture en 3 couches respectée (objets métier `Data.define` / client spécialisé / `HttpClient` module — cf. skill `api-client`)
- [ ] Erreurs HTTP gérées (timeout, 4xx, 5xx) — pas de `raise` sec sans contexte
- [ ] Pas de URL hardcodée → utiliser `ENV[...]`

#### Données métier (cf. CLAUDE.md projet)

- **Organization** identifié par SIRET
- **Process** = type de flux
- **Subscription** lie Organization à Process
- Aucune donnée métier persistée localement (le portail consomme l'API HubeeV1)

Vérifier qu'aucune migration n'introduit une persistance métier (sauf cas explicite documenté).

### 4. Vérifications frontend (si UI touchée)

Si le diff touche `app/views/`, `app/javascript/`, `app/helpers/`, `app/assets/` :

#### DSFR (mandatory)

Cf. rule `frontend` du plugin et skill `dsfr-skill` (plugin tiers).

- [ ] **Classes `fr-*`** utilisées (pas de Tailwind ni styles custom sans bonne raison)
- [ ] **Helpers `dsfr_*`** dans les forms (`dsfr_text_field`, `dsfr_email_field`, `dsfr_submit`)
- [ ] **`Dsfr::FormBuilder`** comme builder par défaut (déjà configuré dans `application.rb`)
- [ ] **Pas de couleurs custom** (charte gouvernementale, DSFR seul)
- [ ] **Pas d'install npm** (DSFR via gems Ruby uniquement)

#### RGAA 4.1 (mandatory)

- [ ] **ARIA attributes** appropriés sur les composants interactifs
- [ ] **Navigation clavier** fonctionnelle (Tab, Enter, Escape)
- [ ] **Labels explicites** sur tous les form inputs (pas de placeholder qui sert de label)
- [ ] **Contraste suffisant** (DSFR le garantit si on n'override pas)
- [ ] **Headings hiérarchiques** (`<h1>` unique, `<h2>` cohérents)
- [ ] **Skip links** présents si layout complexe
- [ ] **Annonce des actions dynamiques** (Turbo Stream avec `aria-live`)

#### Hidden fields (cf. rule `frontend`)

- [ ] **Aucun `hidden_field` redondant** : si la valeur peut être résolue côté serveur (depuis params, session, association), retirer le hidden field

### 5. Vérifications agent-vm spécifiques

Si le diff touche `.claude/`, `.agent-vm.runtime.sh`, `.claude-container/` :

- [ ] Pas de credentials hardcodés (token, password, clé)
- [ ] `permissions.deny` cohérent avec la doctrine (cf. skill `commit` pour les patterns)
- [ ] `.gitignore` à jour (`.env`, `.claude/settings.local.json`, etc.)
- [ ] Si modif `setup.sh` : doit rester impersonnel (pas de "Damien Le Thiec" hardcodé)

### 6. Output du review

Format de présentation au user :

```markdown
## Review de la branche `<branch-name>`

**Périmètre** : N commits, M fichiers (+X -Y lignes)
**CI locale** : ✅ verte | ❌ rouge ([détail])

### ✅ Points OK
- [Liste des bonnes pratiques constatées]

### ⚠️ Points d'attention
- [Liste des choses à reviewer humainement, pas bloquant]

### 🛑 Bloquants
- [Liste des choses à corriger AVANT push]

### Suggestions
- [Améliorations optionnelles]
```

Si **aucun bloquant** : suggérer d'enchaîner sur la skill `finishing-branch` pour préparer la MR.
Si **bloquants** : refuser de proposer la MR tant qu'ils ne sont pas levés (sauf override explicite du user).

## Anti-patterns Claude

- ❌ Marquer le review "✅ tout va bien" sans avoir lu les fichiers en détail
- ❌ Lister 50 nitpicks sans hiérarchiser
- ❌ Suggérer un refacto majeur dans un review (ce n'est pas le moment, ouvrir une issue à la place)
- ❌ Skipper les checks UI/RGAA si le diff touche des views (la rule `frontend` est mandatory)
- ❌ Enchaîner sur `finishing-branch` automatiquement sans valider que les bloquants sont levés
