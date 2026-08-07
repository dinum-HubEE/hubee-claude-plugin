---
name: interactors
description: "Conventions des interactors et organizers HubEE (logique métier multi-étapes avec la gem interactor) : nommage déduit du controller, partage d'étapes, rollback et ordonnancement par irréversibilité, rejeu, traduction des erreurs côté controller, specs. À utiliser pour créer ou modifier de la logique métier dans app/interactors/."
globs:
  - "app/interactors/**/*.rb"
---

# Interactors & Organizers Skill

La logique métier multi-étapes utilise la gem [interactor](https://github.com/collectiveidea/interactor) (`gem "interactor"`). Pas de service objects PORO ad-hoc pour la logique métier.

**Quand passer en organizer + interactor** — c'est une décision de *choix de pattern*, tranchée par `choosing-a-pattern` (§ « Choisir un pattern »). Cette skill ne reprend pas le critère ; elle couvre le *comment* une fois la bascule décidée. Pour le style de code Ruby transverse (nommage, chaînage, error handling), voir `ruby-style`.

## Organizer

Un organizer orchestre des interactors atomiques, exécutés dans l'ordre. Il ne contient aucune logique lui-même.

> **Règle validée en pratique — ne pas assouplir.** « Toujours un organizer **et** un interactor, même pour un seul interactor » a guidé les refactors de la chaîne d'authentification ProConnect (`datagouv/hubee`) sans qu'aucune dérogation ne soit nécessaire.

```ruby
# app/interactors/data_packages/transmit.rb
module DataPackages
  class Transmit
    include Interactor::Organizer

    organize Transmit::ValidateTransmission,
      Transmit::ResolveRecipients,
      Transmit::CreateNotifications,
      Transmit::TransitionToTransmitted
  end
end
```

## Interactor

Chaque interactor = une étape atomique. Le `context` transporte les données entre étapes ; `context.fail!` interrompt la chaîne.

```ruby
# app/interactors/data_packages/transmit/validate_transmission.rb
module DataPackages
  class Transmit
    class ValidateTransmission
      include Interactor

      def call
        context.fail!(error: :not_draft) unless data_package.draft?
        context.fail!(error: :no_completed_attachments) unless data_package.has_completed_attachments?
      end

      private

      def data_package
        context.data_package
      end
    end
  end
end
```

## Nommage & namespaces

Le nommage se déduit du controller, et l'on nomme par **intention** (ce que l'étape veut faire), jamais par mécanique interne.

- **Organizer** : son namespace reflète le controller, **namespace du controller inclus**. `[Namespace::]Ressource::Action` = `[Namespace::]RessourceController#action`.
  - `UsersController#create` → `Users::Create` dans `app/interactors/users/create.rb`.
  - `Api::UsersController#create` → `Api::Users::Create` dans `app/interactors/api/users/create.rb`.
- **Interactors** : namespacés sous leur organizer. Chaque étape vit sous `<Organizer>::`.
  `app/interactors/users/create/validate_form.rb` → `Users::Create::ValidateForm`.
- **Noms par intention** : `ValidateForm`, `ResolveOrganization`, `UpdateHubApiSubscription` — l'intention métier, pas le comment.

## Partage — pas de duplication d'intention

Deux organizers qui ont besoin de la même intention ne dupliquent pas l'étape : on la partage sous un sous-namespace `shared`, **remonté au premier niveau qui couvre tous les usages**.

- Entre plusieurs actions d'une même ressource → `<Ressource>::Shared::<Étape>` dans `app/interactors/<ressource>/shared/`.
- Entre plusieurs ressources d'un même namespace → `<Namespace>::Shared::<Étape>` dans `app/interactors/<namespace>/shared/`.
- Transverse à plusieurs namespaces de premier niveau (ex. `Api` + `PortailV2`) → namespace global `HubEE::Shared::<Étape>` dans `app/interactors/hubee/shared/`.
- La racine nue `Shared::<Étape>` (`app/interactors/shared/`) n'est admise que si l'app n'a **aucun** namespace de premier niveau significatif. Dès qu'il en existe, le global passe par `HubEE::Shared`.

```ruby
# Subscriptions::Create et Subscriptions::Update ont tous deux besoin de résoudre l'organisation.
# app/interactors/subscriptions/shared/resolve_organization.rb
module Subscriptions
  module Shared
    class ResolveOrganization
      include Interactor

      def call
        context.organization = HubApi::Organization.find(context.siret)
      rescue HubApi::Client::Error
        context.fail!(error: :organization_not_found)
      end
    end
  end
end
```

❌ Recopier une intention quasi identique sous deux namespaces d'action (`Subscriptions::Create::ResolveOrganization` **et** `Subscriptions::Update::ResolveOrganization`) : c'est le signal d'un `Shared` à extraire.

**Discriminant** : comparer les *intentions*, pas les corps de méthode. Deux étapes peuvent produire un appel identique sans être la même étape — « résoudre X » (le résultat alimente la suite) et « vérifier que X existe » (le résultat est jeté) sont deux intentions distinctes, et les mutualiser ferait porter à l'une une responsabilité que son appelant n'a pas. Si les deux étapes ne peuvent pas partager le même nom par intention, il n'y a pas de `Shared` à extraire.

```ruby
# Même appel, mêmes rescue, mêmes symboles d'erreur — et pourtant deux étapes distinctes.
Users::Create::ResolveOrganization        # pose context.organization, consommé par l'étape suivante
Users::Update::EnsureOrganizationExists   # vérifie l'existence, jette le résultat
```

Quand deux étapes se ressemblent à ce point sans être mutualisables, documenter la distinction dans chacune : c'est ce commentaire qui empêche une revue ou un audit ultérieur de reproposer l'extraction.

### Factoriser de la logique, pas une étape entière

Partager une **étape complète** passe par un `Shared::` (ci-dessus) — c'est l'idiome de la gem, à préférer par défaut. Quand on veut seulement mutualiser un **morceau de logique métier non trivial** entre interactors, sans en faire une étape à part entière, on le factorise dans un **concern d'interactor**, pas dans un service PORO : toute la logique complexe transite par des interactors (voir skill `principles`), donc le partage aussi.

Règle : **l'étape garde la responsabilité du `context.fail!`.** Le concern ne porte que la logique métier, hors du `rescue` ; il n'appelle jamais `context.fail!` lui-même. Un module qui fait `context.fail!` sans être un interactor crée un couplage implicite — il ne fonctionne que hosté dans un `Interactor`. Dans ce cas, préférer une vraie étape partagée `Shared::`.

❌ Réserver le concern à une logique qui le mérite. Une seule ligne ou une intention triviale (`HubApi::Organization.find(siret:)`) se recopie dans chaque étape — ni concern ni `Shared` pour ça (Rule of Three, skill `principles`).

```ruby
# app/interactors/concerns/subscription_payload.rb — logique métier partagée, aucun context.fail!
# (app/interactors/concerns ajouté aux autoload paths, comme app/models/concerns)
module SubscriptionPayload
  private

  # Plusieurs règles métier : mapping des champs, normalisation, valeurs par défaut.
  def build_payload(form, organization)
    {
      siret: organization.siret,
      raison_sociale: organization.name,
      code_demarche: form.code_demarche,
      contact_email: form.contact_email.to_s.downcase.strip,
      actif: form.actif.nil? ? true : form.actif
    }
  end
end

# Create et Update incluent le même concern ; chacun garde son call + son fail!.
module Subscriptions
  class Update
    class UpdateHubApiSubscription
      include Interactor
      include SubscriptionPayload

      def call
        HubApi::Subscription.update(id: context.subscription_id,
                                    payload: build_payload(context.form, context.organization))
      rescue HubApi::Client::Error
        context.fail!(error: :update_rejected)   # le fail! reste dans l'étape
      end
    end
  end
end
```

## Rollback

`rollback` est appelé sur les étapes déjà réussies (en ordre inverse) quand une étape **suivante** fait `context.fail!` — pas sur une exception levée, d'où le pattern `rescue` ⇒ `fail!`. À définir sur les étapes qui écrivent localement :

```ruby
def call
  context.notifications = create_notifications
end

def rollback
  context.notifications.each(&:destroy)
end
```

**API externe : jamais de rollback compensatoire.** Une compensation s'exécute dans le chemin d'échec, là où l'API vient de flancher — elle a toutes les chances d'échouer aussi. À la place, une règle d'ordonnancement :

> **Ordonner les étapes par irréversibilité croissante** — rien de non-rejouable n'a d'étape après lui.

- **Étapes locales d'abord** : rollbackables de façon fiable.
- **Puis les calls externes rejouables** : update (PUT complet, idempotent par nature), `find_or_create`, create avec rescue du conflit (`ConflictError`…) qui retrouve l'existant par sa clé naturelle au lieu de doublonner. Ils peuvent être suivis d'autres étapes : si l'une échoue, on ré-exécute l'organizer entier — les étapes déjà faites no-op ou repoussent à l'identique, les manquantes tournent enfin.
- **L'éventuel call non-rejouable en dernier** : rien après lui → aucun état partiel externe possible, aucune compensation à écrire. Deux non-rejouables dans la même opération = signal de conception : en rendre un rejouable, ou découper l'opération.

```ruby
module Subscriptions
  class Update
    include Interactor::Organizer

    organize Update::ValidateForm,        # local — pur calcul
      Shared::ResolveOrganization,        # externe en lecture — rejouable
      Update::SaveAuditTrail,             # local — rollbackable
      Update::UpdateHubApiSubscription    # externe — en dernier, pas de rollback
  end
end
```

```ruby
# app/interactors/subscriptions/update/update_hub_api_subscription.rb
module Subscriptions
  class Update
    class UpdateHubApiSubscription
      include Interactor

      # Pas de rollback : une compensation échouerait pour les mêmes raisons que
      # le call (réseau, 5xx). Son échec fait fail! → rollback des étapes locales
      # → retour à l'état initial. Et le PUT complet est idempotent : ré-exécuter
      # l'organizer repousse le même payload, sans effet de bord.
      def call
        HubApi::Subscription.update(id: context.subscription_id, payload: context.form.to_payload)
      rescue HubApi::Client::ServerError => e
        Rails.logger.error("Subscription update failed for #{context.subscription_id}: #{e.message}")
        context.fail!(error: :api_unavailable)   # transitoire — un rejeu peut réussir
      rescue HubApi::Client::Error => e
        Rails.logger.error("Subscription update rejected for #{context.subscription_id}: #{e.message}")
        context.fail!(error: :update_rejected)   # 4xx — rejouer redonnerait le même refus
      end
    end
  end
end
```

**Comment se rejoue l'organizer.** Le rejeu n'est pas un mécanisme à part : c'est ré-appeler `.call` avec les **mêmes entrées**. Deux déclencheurs selon le contexte :

```ruby
# Action interactive : l'échec ré-affiche le formulaire, la resoumission EST le
# rejeu. Suffisant si un humain est là et que l'état partiel peut attendre.
def update
  result = Subscriptions::Update.call(subscription_id: params[:id], form: @subscription_form)

  if result.success?
    redirect_to edit_subscription_path(params[:id]), notice: t(".success")
  else
    flash.now[:alert] = t(".#{result.error}")
    render :edit, status: :unprocessable_content
  end
end
```

```ruby
# Complétion à garantir (webhook, batch — personne pour resoumettre) : job qui
# rejoue jusqu'au succès. `.call` avale le fail! → re-lever pour armer retry_on.
# Ne re-lever que l'erreur transitoire (:api_unavailable) : rejouer un refus
# métier (4xx) redonnerait le même refus.
class UpdateSubscriptionJob < ApplicationJob
  retry_on HubApi::Client::ServerError, wait: :polynomially_longer, attempts: 10

  def perform(subscription_id, form_params)
    form = SubscriptionForm.new(form_params)
    result = Subscriptions::Update.call(subscription_id:, form:)
    return if result.success?
    raise HubApi::Client::ServerError, result.error.to_s if result.error == :api_unavailable

    Rails.logger.error("Subscription update #{subscription_id} abandonné : #{result.error}")
  end
end
```

Dans les deux cas, c'est la **rejouabilité des étapes** qui rend le rejeu sûr — le déclencheur ne fait que ré-exécuter.

**Persister l'ID externe en local.** Le write local qui suit un call externe crée une fenêtre « créé chez l'API, non enregistré chez nous ». Elle est bénigne si l'ID est re-dérivable par clé naturelle (SIRET + code démarche…) : au rejeu, le rescue du conflit re-cherche la ressource et récupère l'ID. Logger l'ID externe avant le save local, pour que l'état reste corrigeable même sans rejeu.

Si une écriture n'est ni rejouable ni plaçable en dernier : pas de compensation pour autant — logger avec le contexte et laisser corriger manuellement, en documentant ce choix dans le code.

## Usage dans un controller

`context.fail!(error: :symbol)` passe un symbole via la clé de contexte `error:`, lisible directement par `result.error` (le `context` se comporte comme un OpenStruct, pas besoin de `result.context`). C'est au controller de traduire ce symbole en message utilisateur/API, jamais à l'interactor.

```ruby
def create
  result = DataPackages::Transmit.call(data_package: @data_package)

  if result.success?
    render "api/v1/data_packages/show", status: :ok
  else
    render json: error_response(result.error), status: :unprocessable_content
  end
end
```

Exemple complet de traduction côté controller (form HTML, mais la même table sert un rendu JSON) :

```ruby
# app/controllers/subscriptions_controller.rb
INTERACTOR_ERRORS = {
  organization_not_found: {field: :siret, key: "users.shared.organization_not_found"},
  user_exists:            {field: :email, key: "users.create.user_exists"},
  create_api_error:       {field: :base,  key: "users.create.api_error"}
}.freeze

def create
  result = Users::Create.call(user_form: @form)

  if result.success?
    redirect_to users_path, notice: t(".success")
  else
    apply_interactor_error(result)
    render :new, status: :unprocessable_content
  end
end

private

def apply_interactor_error(result)
  mapping = INTERACTOR_ERRORS.fetch(result.error)
  @form.errors.add(mapping[:field], t(mapping[:key]))
end
```

❌ **Anti-pattern** : muter `context.user_form.errors.add(...)` directement dans l'interactor pour aller plus vite. Ça couple la logique métier à la présentation et retire au controller la responsabilité de traduire l'échec — l'interactor ne connaît que des symboles, jamais des messages.

## Specs

Un fichier de spec par interactor et par organizer (`spec/interactors/...`).

```ruby
RSpec.describe DataPackages::Transmit::ValidateTransmission do
  describe ".call" do
    subject(:result) { described_class.call(data_package:) }

    context "when package is not draft" do
      let(:data_package) { create(:data_package, :transmitted) }

      it { is_expected.to be_failure }

      it "returns not_draft error" do
        expect(result.error).to eq(:not_draft)
      end
    end
  end
end
```

**Règles** :
- ✅ Nommage déduit du controller, **namespace inclus** : organizer `[Namespace::]<Ressource>::<Action>` = `[Namespace::]<Ressource>Controller#<action>`, noms d'étapes par intention
- ✅ Arborescence : `app/interactors/[<namespace>/]<ressource>/<action>.rb` (organizer) + `.../<action>/<étape>.rb` (steps) — interactor toujours namespacé sous son organizer
- ✅ Étape partagée → sous-namespace `shared` remonté au premier niveau couvrant tous les usages (ressource → namespace → global `HubEE`, racine nue seulement sans namespace de premier niveau), pas de duplication d'une même intention — le discriminant est l'identité d'**intention**, pas la ressemblance des corps de méthode
- ✅ Mutualiser un morceau de logique (pas une étape entière) → concern d'interactor dans `app/interactors/concerns/`, pas un service PORO ; le `context.fail!` reste dans l'étape, jamais dans le concern
- ✅ Une fois la bascule décidée (par `choosing-a-pattern`), toujours un organizer **et** un interactor, même pour un seul interactor
- ✅ Étapes ordonnées par irréversibilité croissante : locales (rollbackables) d'abord, calls externes rejouables ensuite, l'éventuel non-rejouable en dernier — jamais de rollback compensatoire vers une API externe, le rejeu de l'organizer est la récupération
- ✅ Erreurs symboliques : `context.fail!(error: :not_draft)` — le controller traduit en message utilisateur/API
- ✅ Specs : `described_class.call(...)`, matchers `be_success` / `be_failure`, vérifier `result.error`
- ❌ Pas de service object PORO pour la logique métier (les `app/services/` existants sont des adapters API)
- ❌ Pas de logique métier dans l'organizer (il ne fait qu'`organize`)
