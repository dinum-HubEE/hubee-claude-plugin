---
name: gem-design
description: Use when extracting or creating an internal Ruby gem (e.g. hub-api-v1). Covers FakeClient design, gemspec for private gems, and Dockerfile secrets for private gem sources.
---

# Gem Design Skill

Conventions pour créer ou maintenir une gem Ruby interne dans l'écosystème HubEE.

## FakeClient — objet de test de première classe

Le `FakeClient` n'est pas un ajout tardif : il se conçoit en même temps que le vrai client.

**Contrat obligatoire** :
- Implémenter tous les filtres supportés par les vraies méthodes (`companyName`, `company_register`, `type`, `name`…) avec la même sémantique de filtrage
- Exposer des méthodes de setup fluides : `add_subscription`, `add_organization`, `set_processes`
- Permettre le spy sans effet de bord : `allow(fake_client).to receive(:get_with_headers).and_call_original` doit fonctionner

Sans ça, les specs de frontière dans l'app consommatrice ne peuvent vérifier que les params transmis, pas le comportement filtré — angle mort garanti.

```ruby
# lib/hub_api_v1/testing/fake_client.rb
module HubApiV1
  module Testing
    class FakeClient
      def initialize
        @subscriptions = []
      end

      def add_subscription(attrs)
        @subscriptions << attrs
        self
      end

      def get_with_headers(path, params = {})
        case path
        when Subscription::PATH
          results = @subscriptions
          results = results.select { |s| s[:companyName]&.include?(params[:companyName]) } if params[:companyName]
          results = results.select { |s| s[:type] == params[:type] } if params[:type]
          { "value" => results }
        end
      end
    end
  end
end
```

**Règle PR** : toute MR sur la gem qui ajoute un critère de recherche doit aussi mettre à jour le `FakeClient` pour implémenter ce filtre.

## gemspec — gem privée

```ruby
Gem::Specification.new do |spec|
  spec.name    = "hub-api-v1"
  spec.version = HubApiV1::VERSION
  spec.authors = ["HubEE"]

  # Bloque un gem push accidentel vers rubygems.org
  spec.metadata["allowed_push_host"] = "https://rubygems.pkg.github.com/dinum-HubEE"

  spec.metadata["source_code_uri"]   = "https://github.com/dinum-HubEE/hub-api-v1"
  spec.metadata["changelog_uri"]     = "https://github.com/dinum-HubEE/hub-api-v1/blob/main/CHANGELOG.md"
end
```

`allowed_push_host` est obligatoire sur toute gem privée : sans lui, un `gem push` accidentel publie la gem sur rubygems.org.

## Linting

StandardRB — même convention que les apps HubEE (voir `ruby-style`). Ajouter dans le gemspec :

```ruby
spec.add_development_dependency "standard"
spec.add_development_dependency "standard-rspec"
```

## Dockerfile & secrets (source privée)

Si la gem est consommée depuis GitHub Packages, voir la section **Dockerfile & secrets** du skill `security` — ARG interdit pour les tokens, utiliser `RUN --mount=type=secret`.

## Versioning

Suivre semver. Incrémenter le PATCH pour un bugfix ou l'ajout d'un filtre dans FakeClient ; MINOR pour une nouvelle méthode publique ; MAJOR pour un breaking change.
