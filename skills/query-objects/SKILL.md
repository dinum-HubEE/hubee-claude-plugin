---
name: query-objects
description: "Query objects HubEE : extraire une requête complexe (filtres conditionnels, recherche, jointures) hors du controller et du modèle dans app/queries/. À utiliser dès qu'une action index accumule des scopes conditionnels. Pour le choix du pattern (notamment query object vs scope de modèle), voir la skill choosing-a-pattern."
globs:
  - "app/queries/**/*.rb"
---

# Query Objects Skill

Un query object isole une **requête complexe** (filtres conditionnels, recherche, jointures) hors du controller et du modèle. Le choix d'y basculer plutôt que de rester sur un scope de modèle est une décision de choix de pattern, tranchée par `choosing-a-pattern` (§ « Choisir un pattern ») — cette skill couvre l'implémentation une fois ce choix fait.

## Structure

```ruby
# app/queries/subscriptions_query.rb
class SubscriptionsQuery
  def initialize(relation = Subscription.all)
    @relation = relation
  end

  def call(params = {})
    result = @relation
    result = filter_by_status(result, params[:status])
    result = filter_by_organization(result, params[:organization_id])
    result = search(result, params[:q])
    result.includes(:organization, :process)
  end

  private

  def filter_by_status(relation, status)
    return relation if status.blank?
    relation.where(status: status)
  end

  def filter_by_organization(relation, org_id)
    return relation if org_id.blank?
    relation.where(organization_id: org_id)
  end

  def search(relation, query)
    return relation if query.blank?
    relation.joins(:organization)
      .where("organizations.name ILIKE ?", "%#{query}%")
  end
end
```

## Règles

- ✅ Une relation injectée en entrée (`Subscription.all` par défaut) → composable et testable en isolation.
- ✅ Chaque filtre est une méthode privée qui **court-circuite sur `blank?`** et retourne la relation inchangée — pas de branche `if` qui réaffecte (voir chaînage, skill `ruby-style`).
- ✅ `call` retourne une `ActiveRecord::Relation` (pas un tableau chargé) → l'appelant garde la pagination, l'`includes` et le comptage paresseux.
- ✅ Interpolation SQL sécurisée : jamais de `"...#{query}..."` dans un `where` sans placeholder (voir skill `security`).
- ❌ Pas de query object pour un seul `where` : c'est un `scope` de modèle.
