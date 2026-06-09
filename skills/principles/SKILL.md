---
name: principles
description: Appliquer les principes de développement (YAGNI > KISS > DRY > SOLID) avant de proposer du code ou un refacto. À utiliser pour concevoir du nouveau code, proposer des abstractions, extraire des helpers/services, ou juger si un changement ajoute une complexité nécessaire. Particulièrement utile pour résister aux réflexes de sur-abstraction (service objects prématurés, injection de dépendances sans appelant, configuration générique). Inclut la Rule of Three (ne pas extraire à la 2e duplication) et le Semantic DRY (coïncidence de valeur ≠ même connaissance).
globs:
  - "app/**/*.rb"
  - "lib/**/*.rb"
---

# Principes de développement

Appliquer ces principes à tout le code produit. Priorité en cas de conflit : **YAGNI > KISS > DRY > SOLID**.

Pourquoi cet ordre : un principe pris isolément semble toujours sage, mais les principes entrent en
conflit. Quand c'est le cas, privilégier celui qui garde la codebase plus petite et plus simple
*aujourd'hui*. Appliquer SOLID à du code dont on n'a pas encore besoin (YAGNI) produit des
abstractions qui seront de toute façon refactorées. Appliquer DRY à deux blocs qui se ressemblent
mais signifient des choses différentes (Semantic DRY) couple des concepts indépendants et les rend
plus difficiles à faire évoluer. La simplicité d'abord, la structure seulement quand elle paie.

## SOLID

### S — Single Responsibility

Une classe/méthode n'a qu'une seule raison de changer. Un model ne fait pas d'appels HTTP, un service ne rend pas de vues.

```ruby
# ❌ le model gère la logique métier ET l'appel externe
class Subscription < ApplicationRecord
  def activate!
    update!(status: "active")
    HubeeApi.new.post("/subscriptions", id: id) # pas son rôle
  end
end

# ✅ chaque classe a une seule responsabilité
class Subscription < ApplicationRecord
  def activate!
    update!(status: "active")
  end
end

class SubscriptionActivator
  def call(subscription)
    subscription.activate!
    HubeeApi.new.post("/subscriptions", id: subscription.id)
  end
end
```

### O — Open/Closed

Le code est ouvert à l'extension, fermé à la modification. Ajouter du comportement sans toucher au code existant.

```ruby
# ❌ ajouter un format impose de modifier la méthode existante
class ExportService
  def call(format)
    if format == :csv then export_csv
    elsif format == :pdf then export_pdf # on touche au code existant
    end
  end
end

# ✅ on étend en ajoutant une nouvelle classe, pas en modifiant les existantes
class CsvExportService
  def call = export_csv
end

class PdfExportService
  def call = export_pdf
end
```

### L — Liskov Substitution

Toute sous-classe doit pouvoir se substituer à sa classe parente sans altérer le comportement attendu. Ne pas redéfinir une méthode pour en changer le contrat.

```ruby
# ❌ la sous-classe lève là où le parent retourne nil, ce qui casse les appelants
class ApiClient
  def find(id) = nil # retourne nil quand non trouvé
end

class StrictApiClient < ApiClient
  def find(id) = raise NotFoundError # change le contrat
end

# ✅ la sous-classe préserve le contrat
class CachedApiClient < ApiClient
  def find(id)
    cache.fetch(id) { super }
  end
end
```

### I — Interface Segregation

Préférer plusieurs modules ciblés à un seul module fourre-tout. Une classe ne devrait pas être forcée d'implémenter des méthodes dont elle n'a pas besoin.

```ruby
# ❌ un concern fourre-tout force tous les includers à porter des méthodes inutilisées
module Exportable
  def to_csv = ...
  def to_pdf = ...
  def to_xml = ...
end

# ✅ modules ciblés, on n'inclut que ce dont on a besoin
module CsvExportable
  def to_csv = ...
end

module PdfExportable
  def to_pdf = ...
end

class Subscription < ApplicationRecord
  include CsvExportable # uniquement ce qui est nécessaire
end
```

### D — Dependency Inversion

Dépendre d'abstractions, pas d'implémentations concrètes. Injecter les dépendances plutôt que de les instancier directement.

```ruby
# ❌ dépendance codée en dur, impossible à stubber dans les tests
class SubscriptionActivator
  def call(subscription)
    HubeeApi.new.post("/subscriptions", id: subscription.id)
  end
end

# ✅ dépendance injectée, facile à remplacer ou à stubber
class SubscriptionActivator
  def initialize(api_client: HubeeApi.new)
    @api_client = api_client
  end

  def call(subscription)
    @api_client.post("/subscriptions", id: subscription.id)
  end
end

# Dans spec/services/subscription_activator_spec.rb :
# SubscriptionActivator.new(api_client: double("api", post: true))
```

Dépends de ce qui change moins souvent que toi : une dépendance est saine quand la cible est plus stable et plus abstraite. Trois leviers : (1) graphe acyclique — jamais de cycle ; (2) injecter les dépendances volatiles plutôt que les instancier en dur ; (3) isoler ce qui change le plus (API/client tiers) derrière une frontière. Concret-Rails : un service dépend des models ; un model ne dépend jamais d'un controller/service ; le code métier ne dépend pas directement d'un client HTTP tiers (cf. archi 3-couches api-client).

### Law of Demeter — ne parle qu'à tes amis immédiats

N'invoque que des méthodes de tes voisins directs : pas de chaîne `order.customer.address.zip` qui traverse trois objets et te couple à leur structure interne.

```ruby
# ❌ chaîne qui traverse customer puis address
order.customer.address.zip

# ✅ l'objet expose ce dont l'appelant a besoin
class Order
  def customer_zip = customer.address_zip
end
order.customer_zip
```

## YAGNI

N'implémenter que ce qui est nécessaire maintenant, pas ce dont on pourrait avoir besoin un jour.

```ruby
# ❌ système de config générique construit « au cas où »
class Subscription < ApplicationRecord
  def self.find_with_options(id, cache: false, fallback: nil, locale: :fr)
    # logique complexe que personne n'a demandée
  end
end

# ✅ on implémente exactement ce qui est nécessaire
class Subscription < ApplicationRecord
  def activate! = update!(status: "active")
end
```

## KISS

Privilégier la solution la plus simple qui fonctionne, éviter la complexité accidentelle.

```ruby
# ❌ astucieux mais difficile à lire
active_orgs = orgs.each_with_object({}) { |o, h| h[o.id] = o if o.status == "active" }

# ✅ simple et explicite
active_orgs = orgs.select(&:active?)
```

## DRY

Chaque élément de connaissance a une représentation unique et non ambiguë — mais sans abstraction prématurée.

```ruby
# ❌ même logique dupliquée à deux endroits
def admin_label = "[#{siret}] #{name}"
def export_label = "[#{siret}] #{name}"

# ✅ source de vérité unique
def label = "[#{siret}] #{name}"
alias admin_label label
alias export_label label
```

### Rule of Three — attendre de l'avoir vu trois fois

Ne pas extraire à la deuxième occurrence. La duplication coûte peu, la mauvaise abstraction coûte
cher : une fois un helper extrait, chaque variation future doit soit s'y conformer, soit le casser.

Deux occurrences peuvent partager une forme par coïncidence. Une troisième occurrence est la preuve
d'un motif.

```ruby
# Premier usage — on l'écrit, c'est tout
def admin_label = "[#{siret}] #{name}"

# Deuxième usage — on duplique, on n'extrait pas encore
def export_label = "[#{siret}] #{name}"

# Troisième usage avec la même forme — maintenant on extrait
def label = "[#{siret}] #{name}"
alias admin_label label
alias export_label label
alias search_label label
```

Corollaire : si la troisième occurrence montre que la forme est *presque* la même mais avec une
variante (séparateur différent, champ conditionnel), c'est un signal que l'abstraction n'est pas
prête — continuer à dupliquer jusqu'à ce que la bonne forme émerge.

### Semantic DRY — coïncidence de valeur ≠ même connaissance

Deux choses qui partagent la même valeur ne sont **pas** la même chose si elles ont des rôles
sémantiques distincts. DRY s'applique à la *connaissance* (une règle métier → un endroit), pas aux
coïncidences structurelles.

Avant de factoriser deux valeurs qui se ressemblent, se demander : « représentent-elles le même
concept ? » Si non → les garder séparées, même si leurs valeurs actuelles coïncident.

```ruby
# ❌ même URL aujourd'hui, fusionnées en une seule (faux DRY)
KEYCLOAK_URL = ENV.fetch("KEYCLOAK_BASE_URL") # utilisée à la fois pour le login portail et la gestion des utilisateurs

# ✅ deux rôles sémantiques, deux variables, évoluables indépendamment
KEYCLOAK_OIDC_URL  = ENV.fetch("KEYCLOAK_BASE_URL")  # authentifie les admins du portail (OIDC)
KEYCLOAK_ADMIN_URL = ENV.fetch("KEYCLOAK_BASE_URL")  # gère les comptes utilisateurs finaux HubeeV1
```

## Auto-vérification avant de proposer du code

Tu reconnais des « best practices » issues de tes données d'entraînement et tu as tendance à
**sur-abstraire** : des service objects là où une méthode de model suffirait, de l'injection de
dépendances là où le codage en dur convient, de la configuration générique là où une valeur
littérale fait l'affaire. Ces principes existent pour contrer ce réflexe.

Avant de proposer du code, vérifie-toi :

- **YAGNI d'abord.** Cette abstraction est-elle nécessaire *aujourd'hui* par un appelant réel, ou
  prépare-t-elle un futur hypothétique ? Si c'est pour le futur, supprime-la.
- **KISS plutôt que SOLID.** Un controller Rails qui appelle `.update!` directement vaut souvent
  mieux qu'un service object enrobant la même ligne. Résiste au réflexe de découper.
- **Rule of Three avant DRY.** Si seulement deux endroits partagent une forme, ne les factorise pas
  encore.
- **Semantic DRY.** Deux valeurs ayant la même chaîne ne sont pas la même connaissance.

Si tu es sur le point d'extraire une classe, d'ajouter un strategy pattern ou d'introduire une gem
pour éviter trois lignes de duplication — contre-toi et garde la version la plus simple.
