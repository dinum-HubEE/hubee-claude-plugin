# Frontend Rules

## Design System

This project uses the **DSFR** (Design System de l'État français).

### Installation

DSFR is installed via **Ruby gems** (not npm):
- `dsfr-assets`: CSS, JS and DSFR icons
- `dsfr-form_builder`: Rails helpers for forms

### Why gems instead of npm?

1. **Security**: Avoids npm supply chain risks (Shai-Hulud)
2. **Simplicity**: No JS bundler, no node_modules
3. **Rails integration**: Works with Propshaft and importmap

## Implementation Rules

### CSS Classes

Use DSFR `fr-*` classes:

```erb
<%# Container %>
<div class="fr-container">

<%# Grid %>
<div class="fr-grid-row fr-grid-row--gutters">
  <div class="fr-col-12 fr-col-md-6">

<%# Buttons %>
<button class="fr-btn">Primaire</button>
<button class="fr-btn fr-btn--secondary">Secondaire</button>

<%# Alerts %>
<div class="fr-alert fr-alert--info">
```

### Forms

`Dsfr::FormBuilder` is configured as the default form builder globally (`config.action_view.default_form_builder`). All `form_with` calls automatically use DSFR helpers.

For model-bound forms (CRUD):

```erb
<%= form_with model: @organization do |f| %>
  <%= f.dsfr_text_field :name %>
  <%= f.dsfr_email_field :email %>
  <%= f.dsfr_submit "Enregistrer" %>
<% end %>
```

For GET search forms without model binding, pass `label:` explicitly (no `human_attribute_name` available):

```erb
<%= form_with url: search_path, method: :get do |f| %>
  <%= f.dsfr_text_field :query, label: "Recherche" %>
  <%= f.dsfr_submit "Rechercher" %>
<% end %>
```

When custom ARIA attributes or layout control are needed (e.g. `aria-describedby`, `fr-messages-group`), using standard Rails helpers (`f.text_field`, `f.label`) with manual `fr-*` classes is acceptable.

### Documentation

To learn about components and their structure:
1. Use the `dsfr-skill` skill (built-in documentation)
2. See https://www.systeme-de-design.gouv.fr/

## Accessibility (RGAA 4.1)

All interfaces must be accessible:

- Appropriate ARIA attributes
- Functional keyboard navigation
- Sufficient contrast (provided by DSFR)
- Explicit labels for forms

## Hotwire

Interactive JavaScript uses **Hotwire** (Turbo + Stimulus):

- **Turbo Drive**: Automatic SPA-like navigation
- **Turbo Frames**: Partial page updates
- **Turbo Streams**: Real-time updates
- **Stimulus**: Lightweight JS behaviors

### Stimulus Example

```javascript
// app/javascript/controllers/example_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["output"]

  greet() {
    this.outputTarget.textContent = "Bonjour !"
  }
}
```

```erb
<div data-controller="example">
  <button data-action="click->example#greet">Cliquer</button>
  <span data-example-target="output"></span>
</div>
```

## Hidden fields in forms

Only add a `hidden_field` when the value **cannot be resolved server-side**.

If the server already has access to the data (database lookup, existing association), the hidden
field is redundant: it increases the attack surface (falsifiable parameter) and creates a false
impression that the server uses it.

```erb
<%# BAD — server can resolve branch_code via Editor.find_by(company_register:) %>
<%= f.hidden_field :editor_branch_code, value: actor.branch_code %>

<%# GOOD — server has no way to know the email typed by the user; hidden field is justified %>
<%= f.hidden_field :email, data: { "email-autocomplete-target": "hiddenField" } %>
```

Rule: **a hidden field carries a value only the client knows**, not a mirror of data already
present in the database.

## What NOT to do

- Do NOT use npm/npx (Shai-Hulud risk)
- Do NOT add Tailwind CSS (we use DSFR)
- Do NOT customize DSFR colors (French government charter)
- Do NOT ignore accessibility
- Do NOT add a `hidden_field` for a value the server can resolve itself
