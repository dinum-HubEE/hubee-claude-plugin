---
name: form-objects
description: "Form objects HubEE : objet qui pilote une opération (validation hors modèle, formulaire multi-champs, données qui ne mappent pas 1-1 sur un AR). Règle centrale — ne porter que ce qui pilote l'opération, rendre non soumis ce qui ne sert qu'à l'UX. Pour le rendu DSFR du form (form builder, view methods), voir la skill frontend-rails. Pour le choix du pattern, voir le routeur de rails-patterns."
globs:
  - "app/forms/**/*.rb"
---

# Form Objects Skill

Un form object modélise une **opération** de saisie qui ne mappe pas 1-1 sur un `ActiveRecord` : formulaire multi-champs, validation hors modèle, données agrégées de plusieurs sources. Pour le **rendu** de ce form (form builder DSFR, `dsfr-form_builder`, view methods sémantiques), voir la skill `frontend-rails` — cette skill-ci couvre l'objet lui-même.

## Ne porter que ce qui pilote l'opération

Un form object ne porte que ce qui **pilote l'opération**. Faire transiter une donnée purement d'**affichage**, redondante avec un identifiant déjà présent, est un smell : deux infos pour une même entité → risque de désync et état UI modélisé côté serveur.

```ruby
# Contexte : le SIRET identifie l'organisation ; le serveur re-résout le nom
# via HubApi::Organization.find. organization_name ne sert qu'à un message.

# ❌ le nom (affichage) transite et est validé alors qu'il est redondant
#    avec le SIRET, seul identifiant réellement nécessaire pour créer l'objet
validates :siret, presence: true, unless: -> { organization_name.present? }
validate  :organization_selected   # vérifie la cohérence du couple nom + siret

# ✅ le SIRET identifie l'organisation ; sa présence suffit côté serveur.
#    Le nom reste une aide de saisie côté front (Stimulus), non soumise.
validates :siret, presence: true
```

Corollaire : un champ qui ne sert qu'à l'UX côté client se rend **non soumis** plutôt que permis puis ignoré (champ hidden anti-pattern, voir skill `frontend-rails` ; params soumis mais non permis, voir skill `build-fix`).
