---
name: state-machine
description: "State machines HubEE avec la gem AASM : modéliser le cycle de vie et les transitions d'états d'une ressource (statuts, événements, guards). À utiliser dès qu'un modèle a un champ statut avec des transitions contraintes. Pour le choix du pattern, voir la skill choosing-a-pattern."
globs:
  - "app/models/**/*.rb"
---

# State Machine Skill

Un cycle de vie — un champ `status` dont les transitions sont **contraintes** (on ne passe pas de `cancelled` à `active`) — se modélise avec la gem [AASM](https://github.com/aasm/aasm). Le choix d'AASM plutôt que des `update` libres et des `validates inclusion` est tranché par `choosing-a-pattern` (§ « Choisir un pattern ») ; cette skill couvre son implémentation. AASM rend les transitions explicites, refuse les sauts illégaux et donne des prédicats d'état (`active?`) et des événements (`activate!`).

```ruby
class Subscription < ApplicationRecord
  include AASM

  aasm column: :status do
    state :pending, initial: true
    state :active
    state :suspended
    state :cancelled

    event :activate do
      transitions from: :pending, to: :active
      after { self.activated_at = Time.current }
    end

    event :suspend do
      transitions from: :active, to: :suspended
    end

    event :cancel do
      transitions from: %i[active suspended], to: :cancelled
    end
  end
end
```

## Règles

- ✅ La colonne (`column: :status`) reste une string en base ; AASM déclare l'ensemble fermé des états — pas besoin d'un `validates inclusion` en doublon, la machine refuse déjà tout état inconnu.
- ✅ Une seule `initial: true`.
- ✅ Les effets de bord d'une transition passent par les callbacks de transition (`after`, `before`, `guard`), pas par du code dispersé chez l'appelant.
- ✅ `from` peut lister plusieurs états sources (`from: %i[active suspended]`) ; une transition illégale lève `AASM::InvalidTransition`.
- ✅ Logique métier multi-étapes autour d'une transition (résoudre une orga, appeler une API, notifier) → ce n'est plus l'affaire du modèle ; quel pattern l'accueille relève de `choosing-a-pattern`. La transition AASM reste déclenchée par ce pattern, jamais dispersée chez l'appelant.
