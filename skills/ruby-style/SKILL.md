---
name: ruby-style
description: "Style de code Ruby HubEE (transverse, non lié à un pattern) : nommage, méthodes de classe, résolution des constantes namespacées, error handling (scope du rescue, code mort), fonctions pures de module, réaffectation de variables et chaînage, imbrication de blocks, temps et fuseaux, linting StandardRB. À utiliser pour écrire ou relire n'importe quel code Ruby/Rails. Pour choisir QUEL pattern écrire, voir la skill choosing-a-pattern."
globs:
  - "app/**/*.rb"
  - "lib/**/*.rb"
---

# Ruby Style Skill

Conventions de code Ruby transverses, valables quel que soit le pattern. Elles ne disent pas *quoi* écrire (ça, c'est `choosing-a-pattern`) mais *comment* l'écrire proprement. Ce que StandardRB enforce déjà n'est pas répété ici (voir § Linting) — cette skill ne porte que le jugement qu'un cop ne couvre pas.

## Conventions de nommage

```ruby
# Classes — PascalCase
class UserSubscription; end

# Methods / variables — snake_case
def calculate_total
  user_count = 42
end

# Constants — SCREAMING_SNAKE_CASE
MAX_RETRY_COUNT = 3

# Predicates — end with ?
def active?; end

# Dangerous methods — end with !
def destroy!; end
```

### Méthodes de classe

Déclarer les méthodes de classe dans un bloc `class << self` (toujours, même pour une seule), avec la visibilité (`private`/`public`) regroupée dans le bloc.

```ruby
class Foo
  class << self
    def build = new

    private

    def default_options = {}
  end
end
```

## Résolution des constantes namespacées

Une constante relative se résout lexicalement, de l'intérieur vers l'extérieur : depuis `module Users`, `Shared::X` désigne `Users::Shared::X` s'il existe, sinon Ruby remonte jusqu'à la racine et trouve `::Shared::X`. Si les deux existent, c'est le plus proche qui gagne — pour viser explicitement un niveau supérieur, écrire le chemin complet (`HubEE::Shared::X`).

Avec Zeitwerk (Rails 6+), cette résolution est **déterministe** : les `autoload` sont enregistrés d'avance, une constante est visible avant d'être chargée. C'est le classic autoloader (avant Rails 6) qui pouvait résoudre vers la mauvaise constante homonyme selon l'ordre de chargement — ce problème n'existe plus.

## Error handling

### Rescue scope

Garder le rescue au plus proche de la ligne qui peut lever l'exception. Si l'action API est au milieu d'une méthode, l'extraire dans une méthode privée avec son propre rescue.

```ruby
# ✅ Rescue isolé sur l'appel API
def autocomplete
  @records = fetch_autocomplete_records(params[:q].to_s.strip)
end

private

def fetch_autocomplete_records(query)
  return [] if query.length < MIN_LENGTH
  HubApi::Organization.search(name: query).records
rescue HubApi::Client::Error
  []
end

# ❌ Rescue qui englobe du code qui ne peut pas lever cette erreur
def autocomplete
  query = params[:q].to_s.strip
  @records = if query.length >= MIN_LENGTH
    HubApi::Organization.search(name: query).records
  else
    []
  end
rescue HubApi::Client::Error
  @records = []
end
```

### Double filet nil

Quand les appelants gardent déjà contre nil avec `x && f(x)`, un `rescue TypeError` dans la fonction
ne peut jamais être atteint. C'est du code mort.

Pour les fonctions utilitaires de robustesse (préfixe `safe_`, parsers, formateurs), la fonction est
défensive : elle accepte nil, et on retire les `&&` chez tous les appelants. C'est leur contrat :
absorber toute entrée sans exploser.

```ruby
# ❌ double filet — rescue TypeError inatteignable, && superflus
item["started_at"] && safe_parse_time(item["started_at"])

def safe_parse_time(str)
  Time.zone.parse(str)
rescue ArgumentError, TypeError   # TypeError ne peut jamais être levé ici
  nil
end

# ✅ la fonction est défensive, les appelants s'en remettent à elle
safe_parse_time(item["started_at"])

def safe_parse_time(str)
  Time.zone.parse(str)
rescue ArgumentError, TypeError
  nil
end
```

## Fonctions pures

Quand une méthode est une fonction générique (parser, formateur, utilitaire de robustesse) sans lien
avec la logique métier d'un objet particulier, la déclarer avec `def self.` dans un module. Ce type
de logique n'appartient à aucune instance — l'exposer via `include` lui prête une appartenance
qu'elle n'a pas.

```ruby
# ❌ mixée par include — le spec doit instancier une classe fantôme
module HubApi::TimeParser
  def safe_parse_time(str) = ...
end
# spec : Class.new { include HubApi::TimeParser }.new.safe_parse_time("...")

# ✅ fonction de module — appelable directement
module HubApi
  module TimeParser
    def self.parse(str)
      Time.zone.parse(str)
    rescue ArgumentError
      nil
    end
  end
end
# spec    : HubApi::TimeParser.parse("2024-13-01")
# appelant: HubApi::TimeParser.parse(item["started_at"])
```

## Réaffectation de variables et chaînage de méthodes

### Éviter de réaffecter la même variable à des valeurs successives

Préférer le chaînage ou l'extraction d'une méthode privée — la réaffectation successive rend le flux de données difficile à suivre.

```ruby
# ❌ users réaffecté, le flux de données est difficile à suivre
users = cached_organization_users.select { |u| u.has_process_access?(code) }
users = users.select { |u| u.email&.start_with?(query) } if query

# ✅ chaîné, flux linéaire
cached_organization_users
  .select { |u| u.has_process_access?(code) }
  .select { |u| query.blank? || u.email&.start_with?(query) }
```

### Chaîner plutôt que stocker des résultats intermédiaires

```ruby
# ❌ variables intermédiaires inutiles
filtered = subscriptions.select(&:active?)
names = filtered.map(&:name)
result = names.sort

# ✅ chaîné
subscriptions.select(&:active?).map(&:name).sort
```

### Chaînage conditionnel via `.then` ou des méthodes privées

```ruby
# ❌ condition qui réaffecte
result = collection.select { |x| x.valid? }
result = result.first(10) if paginate?

# ✅ méthode privée nommée
def filtered_collection
  collection
    .select(&:valid?)
    .then { |r| paginate? ? r.first(10) : r }
end
```

### Ne pas imbriquer les blocks

Un block dans un block noie l'intention. **Deux niveaux d'imbrication au maximum, jamais trois** (StandardRB ne le voit pas — cops `Metrics/*` désactivés —, c'est à nous de tenir la règle). Et même à deux niveaux, on allège :

- **Minimum** : un `do…end` sur le block externe, pour que l'imbrication saute aux yeux.
- **Mieux** : extraire le block interne dans une **méthode nommée** par intention, qui fait disparaître l'imbrication.

```ruby
# ❌ deux blocks imbriqués en accolades — intention noyée
users.each { |u| u.roles.each { |r| grants << Grant.new(user: u, role: r, scope: default_scope(u)) } }

# ✅ acceptable — do…end externe, l'imbrication est lisible
users.each do |u|
  u.roles.each { |r| grants << Grant.new(user: u, role: r, scope: default_scope(u)) }
end

# ✅✅ mieux — le block interne devient une méthode
users.each { |u| grant_all_roles(u) }

def grant_all_roles(user)
  user.roles.each { |role| grants << Grant.new(user:, role:, scope: default_scope(user)) }
end
```

## Temps et fuseaux horaires

Utiliser `Time.current` partout, jamais `Time.now` qui ignore `config.time_zone` de Rails.

```ruby
# ❌ Time.now — retourne l'heure système, ignore le fuseau Rails
Time.now

# ✅ Time.current — respecte config.time_zone
Time.current
```

En test, figer le temps avec `travel_to` plutôt qu'en dépendre.

## Linting

StandardRB est l'unique source de vérité (pas de RuboCop, pas de débats). Le hook `post-edit-standardrb` du plugin le lance automatiquement après chaque Edit sur un fichier `.rb`.

```bash
# Vérification / correction manuelle
bundle exec standardrb
bundle exec standardrb --fix
```
