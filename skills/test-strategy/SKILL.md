---
name: test-strategy
description: "Stratégie de test HubEE : décider QUOI tester, à quel niveau, et jusqu'où pousser la couverture. Couvre l'objectif SimpleCov 90% (lignes + branches), les 3 niveaux de test d'une frontière gem, la répartition organizer vs step, ce qu'il ne faut PAS tester et la fausse couverture (chemin mort). À utiliser pour cadrer le périmètre des tests d'une fonctionnalité ou relire une couverture. Pour écrire les specs, voir la skill rspec-conventions."
globs:
  - "spec/**/*.rb"
---

> Décide **quoi** tester, **à quel niveau**, et **jusqu'où** pousser la couverture. Le **comment** (écrire la spec) vit dans la skill `rspec-conventions`.

# Stratégie de test HubEE

## Objectif de couverture

Minimum **90 % de couverture de lignes et de branches**, imposé par SimpleCov (`spec/spec_helper.rb`). Tourne automatiquement en CI et à la demande en local :

```bash
COVERAGE=true bundle exec rspec   # génère coverage/index.html
```

Configuration SimpleCov pour activer les deux métriques :

```ruby
# spec/spec_helper.rb
SimpleCov.start "rails" do
  enable_coverage :branch
  minimum_coverage line: 90, branch: 90
end
```

SimpleCov mesure la couverture de branches depuis la version 0.18 — chaque `if/unless/case/&&/||` compte comme une branche. Une couverture de lignes à 100 % ne garantit pas la couverture de branches.

## Niveaux de test d'une frontière gem

Quand l'app consomme une gem externe (ex: `hub-api-v1`), distinguer trois niveaux :

| Niveau | Quand | Pattern |
|---|---|---|
| Erreurs réseau | 401, 403, 500 | `allow(GemClass).to receive(:method).and_raise(...)` — seul cas légitime de mock sur la classe gem |
| Contrat form→gem | À chaque `to_search_params` | Spec unitaire sur le hash exact retourné (clés ET valeurs) |
| Frontière HTTP | Tout chemin de recherche/écriture | Injecter `FakeClient`, espionner avec `and_call_original`, asserter sur les params HTTP |

La spec de frontière se rédige **avant le code** (TDD). Elle doit passer au rouge avec le code cassé, au vert après le fix.

> L'**implémentation** de la spec de frontière HTTP (FakeClient, `and_call_original`, assertion du hash complet) est documentée dans la skill `rspec-conventions` § « Request & system specs ». Le contrat form→gem se teste dans une spec unitaire (voir aussi `rspec-conventions`).

## Organizer vs steps : répartition des cas de test

| Niveau      | Quoi tester                                                        |
|-------------|---------------------------------------------------------------------|
| Organizer   | Happy path de bout en bout + comportement de composition (ex : le context d'une étape alimente l'étape suivante) |
| Step        | Tous les chemins d'erreur propres à l'étape + comportement atomique |

Ne pas dupliquer les cas d'erreur à la fois au niveau step et organizer : les tester au niveau step suffit. L'organizer teste que les étapes sont bien branchées, pas ce que chaque étape fait en isolation.

## Ce qu'il ne faut PAS tester

- Les internes de Rails (faire confiance au framework)
- Les gems tierces (faire confiance à leur suite de tests)
- Les délégations simples (`delegate :name, to: :organization`)
- Les méthodes privées directement — tester via l'interface publique
- Les chemins inatteignables depuis les appelants réels

### Fausse couverture : tester un chemin mort

Un test peut passer sans jamais toucher le code qu'il prétend couvrir, donnant une fausse impression
de robustesse. Toujours vérifier que le cas testé peut réellement atteindre le `rescue` ou la
branche défensive depuis les appelants réels.

Exemple avec `Time.zone.parse` :

| Entrée testée | Ce qui se passe réellement |
|---|---|
| `"not-a-date"`, `""` | retourne `nil` nativement — le `rescue` n'est jamais touché |
| `nil` | lève `TypeError` — mais si tous les appelants font `&&`, chemin inatteignable |
| `"2024-13-01"` | lève `ArgumentError` — le seul vrai risque depuis une API externe |

```ruby
# ❌ teste un chemin mort (nil filtré par && chez tous les appelants)
it "returns nil for nil" do
  expect(described_class.safe_parse_time(nil)).to be_nil
end

# ✅ teste la vraie exception possible
it "returns nil for an out-of-range date string" do
  expect(described_class.safe_parse_time("2024-13-01")).to be_nil
end
```

Avant d'écrire un cas de test pour un `rescue`, se demander : **cette exception peut-elle réellement
être levée depuis les appelants réels, compte tenu des gardes existants ?**
