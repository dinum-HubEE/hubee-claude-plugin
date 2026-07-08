---
name: models
description: "Conventions des modèles ActiveRecord HubEE : structure standard (ordre constants → associations → validations → scopes → callbacks → méthodes), validations à liste fermée, scopes, callbacks avec parcimonie. À utiliser pour créer ou modifier un modèle dans app/models/. Pour décider si une logique doit rester une méthode de modèle ou basculer vers un autre pattern, voir la skill choosing-a-pattern."
globs:
  - "app/models/**/*.rb"
---

# Models Skill

Conventions d'implémentation des modèles ActiveRecord. Le choix « cette logique reste-t-elle dans le modèle ou bascule-t-elle vers un pattern dédié » est tranché par `choosing-a-pattern` (§ « Choisir un pattern ») — cette skill couvre le *comment* une fois le modèle retenu.

## Structure standard d'un modèle

Ordre fixe des sections, chacune introduite par un commentaire `# === … ===`.

```ruby
class Subscription < ApplicationRecord
  # === Constants ===
  STATUSES = %w[pending active suspended cancelled].freeze

  # === Associations ===
  belongs_to :organization
  belongs_to :process
  has_many :events, dependent: :destroy

  # === Validations ===
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :organization_id, uniqueness: { scope: :process_id }

  # === Scopes ===
  scope :active, -> { where(status: "active") }
  scope :by_organization, ->(org_id) { where(organization_id: org_id) }
  scope :recent, -> { order(created_at: :desc) }

  # === Callbacks (à utiliser avec parcimonie) ===
  after_create :notify_organization

  # === Méthodes de classe ===
  def self.for_dashboard
    includes(:organization, :process).active.recent.limit(10)
  end

  # === Méthodes d'instance ===
  def activate!
    update!(status: "active", activated_at: Time.current)
  end

  def display_name
    "#{organization.name} - #{process.name}"
  end

  private

  def notify_organization
    NotificationJob.perform_later(id)
  end
end
```

> **Valeur à liste fermée** (`select`, `enum`) : préférer `validates inclusion:` (erreur explicite) au filtrage silencieux — l'utilisateur doit savoir que sa saisie est rejetée, pas la voir disparaître.

> **Statut à transitions contraintes** : dès qu'un `status` a des transitions **contraintes** (on ne passe pas de `cancelled` à `active`), ce n'est plus une simple validation d'inclusion — le pattern à écrire relève de `choosing-a-pattern`.
