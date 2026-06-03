---
name: frontend-rails
description: DSFR + Rails integration specifics — dsfr-form_builder (model-bound and search forms), hidden_field anti-pattern (no mirroring of server-known values), Hotwire integration in ERB views, gem-over-npm rationale. Use when editing ERB templates, building forms, integrating Hotwire (Turbo/Stimulus) into DSFR-styled views, or making decisions about hidden fields vs server lookups. For pure DSFR component documentation (HTML structure, accessibility, fr-* classes), use the dsfr-skill plugin instead.
globs:
  - "app/views/**/*.erb"
  - "app/javascript/controllers/**/*.js"
  - "app/helpers/**/*.rb"
---

# Frontend Rails Skill

## Design System

This project uses the **DSFR** (Design System de l'État français), installed via Ruby gems (not npm).

- `dsfr-assets` — CSS, JS and DSFR icons
- `dsfr-form_builder` — Rails helpers for forms

### Why gems instead of npm?

1. **Security** — avoids npm supply chain risks (Shai-Hulud)
2. **Simplicity** — no JS bundler, no `node_modules`
3. **Rails integration** — works with Propshaft and importmap

For pure DSFR component structure (HTML/CSS/accessibility — fr-btn, fr-alert, fr-grid, etc.), use the **dsfr-skill plugin** which embeds the official component documentation. This skill focuses on DSFR-Rails plumbing.

## Forms

`Dsfr::FormBuilder` is configured as the default form builder globally:

```ruby
# config/application.rb
config.action_view.default_form_builder = "Dsfr::FormBuilder"
```

All `form_with` calls automatically use DSFR helpers.

### Model-bound forms (CRUD)

```erb
<%= form_with model: @organization do |f| %>
  <%= f.dsfr_text_field :name %>
  <%= f.dsfr_email_field :email %>
  <%= f.dsfr_submit "Enregistrer" %>
<% end %>
```

### Search forms without model binding

Pass `label:` explicitly — there's no `human_attribute_name` to fall back on:

```erb
<%= form_with url: search_path, method: :get do |f| %>
  <%= f.dsfr_text_field :query, label: "Recherche" %>
  <%= f.dsfr_submit "Rechercher" %>
<% end %>
```

### Manual Rails helpers (escape hatch)

When custom ARIA attributes or layout control are needed (e.g. `aria-describedby`, `fr-messages-group`), using standard Rails helpers (`f.text_field`, `f.label`) with manual `fr-*` classes is acceptable.

## Hidden fields anti-pattern

Only add a `hidden_field` when the value **cannot be resolved server-side**.

If the server already has access to the data (database lookup, existing association), the hidden field is **redundant**: it increases the attack surface (falsifiable parameter) and creates a false impression that the server uses it.

```erb
<%# BAD — server can resolve branch_code via Editor.find_by(company_register:) %>
<%= f.hidden_field :editor_branch_code, value: actor.branch_code %>

<%# GOOD — server has no way to know the email typed by the user; hidden field is justified %>
<%= f.hidden_field :email, data: { "email-autocomplete-target": "hiddenField" } %>
```

**Rule**: a hidden field carries a value **only the client knows**, not a mirror of data already present in the database.

## Hotwire integration

Interactive JavaScript uses Hotwire (Turbo + Stimulus). For deep Hotwire patterns (Turbo Frames/Streams choreography, complex Stimulus controllers), see the `hotwire` skill. Here we focus on integration with DSFR ERB views.

### Stimulus controller boilerplate

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
<div data-controller="example" class="fr-container">
  <button class="fr-btn" data-action="click->example#greet">Cliquer</button>
  <span data-example-target="output"></span>
</div>
```

## Accessibility (RGAA 4.1)

All interfaces must be accessible:
- Appropriate ARIA attributes (often added automatically by `dsfr-form_builder`)
- Functional keyboard navigation
- Sufficient contrast (provided by DSFR — never customize DSFR colors)
- Explicit labels for forms

The plugin `dsfr-skill` has detailed RGAA component guidance — invoke it for component-level accessibility decisions.

## What NOT to do

- ❌ Use npm / npx (Shai-Hulud supply-chain risk)
- ❌ Add Tailwind CSS (we use DSFR)
- ❌ Customize DSFR colors (French government charter)
- ❌ Ignore accessibility
- ❌ Add a `hidden_field` for a value the server can resolve itself
