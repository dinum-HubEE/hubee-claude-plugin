---
name: models
description: "Conventions des modèles ActiveRecord HubEE : structure standard (ordre constants → associations → validations → scopes → callbacks → méthodes), validations à liste fermée, scopes, callbacks avec parcimonie, + frontière app/models vs lib pour les objets de domaine sans ActiveRecord. À utiliser pour créer ou modifier un fichier de app/models/. Pour décider si une logique doit rester une méthode de modèle ou basculer vers un autre pattern, voir la skill choosing-a-pattern."
globs:
  - "app/models/**/*.rb"
---

# Models Skill

Conventions d'implémentation des modèles ActiveRecord. Le choix « cette logique reste-t-elle dans le modèle ou bascule-t-elle vers un pattern dédié » est tranché par `choosing-a-pattern` (§ « Choisir un pattern ») — cette skill couvre le *comment* une fois le modèle retenu.

## Structure standard d'un modèle

Ordre fixe des sections, chacune introduite par un commentaire `# === … ===`.

> **Seuil — à partir de trois sections distinctes.** En deçà (un modèle de 10 lignes : une association, un enum, deux validations), l'**ordre** suffit : les commentaires de section pèseraient plus lourd que le code qu'ils annoncent. Le seuil vaut par modèle, pas par projet — un projet peut choisir de sectionner partout par cohérence, mais ne doit pas le faire au nom de cette skill.

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

## Objets de domaine sans ActiveRecord (POROs, modules de domaine)

`app/models/` n'est pas réservé aux modèles ActiveRecord. La frontière est :

- **`app/models/<namespace>/`** — objets et modules de **domaine métier**, même sans table ni ActiveModel : vocabulaire du métier, règles, politiques (ex. `Portail::AuthenticationLevels`, `Portail::SecondFactor`). Le namespace (`portail/`, `api/`) porte l'appartenance au module applicatif : la logique spécifique à un module ne va **jamais** sur un modèle AR de `::` (les modèles AR sans namespace ne portent que le code commun).
- **`lib/`** — **adaptateurs vers un protocole ou un service externe** : clients HTTP, dialogues OIDC, vérification de jetons (ex. `Portail::ProConnect::Client`, `Portail::ProConnect::TokenVerifier`).

Test rapide : « cet objet parle-t-il le vocabulaire du métier (niveaux, règles, politiques) ou celui d'un système externe (endpoints, jetons, payloads) ? » Métier → `app/models/<namespace>/`. Externe → `lib/`.

Les conventions de structure ci-dessus (sections `# === … ===`, ordre) restent celles des modèles AR : un module de domaine sans table suit simplement `ruby-style`.
