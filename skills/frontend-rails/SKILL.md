---
name: frontend-rails
description: DSFR + Rails integration specifics — dsfr-form_builder (model-bound and search forms), partials (feature-specific placement, strict locals Rails 7.1+, minimize locals), semantic view methods via form objects (not nil checks), hidden_field anti-pattern, Hotwire integration in ERB views, CSS comments documenting reusable patterns, gem-over-npm rationale. Use when editing ERB templates or partials, building forms, declaring strict locals, writing Stimulus controllers, commenting reusable CSS patterns, or making decisions about hidden fields vs server lookups. For pure DSFR component documentation (HTML structure, accessibility, fr-* classes), use the dsfr-skill plugin instead.
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

## Partials

### Feature-specific, pas `shared/`

Placer les partials dans le dossier de la feature qui les définit. N'utiliser `shared/` que si le partial est réellement utilisé par plusieurs features sans lien logique. Un partial "commun à deux formulaires d'une même resource" reste dans le dossier de la resource.

```
# ✅
app/views/organizations/_autocomplete_input.html.erb
app/views/users/_search.html.erb

# ❌ trop générique
app/views/shared/_organization_autocomplete.html.erb
app/views/shared/_search_form.html.erb
```

### Strict locals (Rails 7.1+)

Toujours déclarer les locals attendus par un partial avec la magic comment `locals:`. Cela documente le contrat et rend Rails strict sur les variables passées.

```erb
<%# locals: (f:, search_form:) %>
<%# locals: (subscription:, editable: false) %>
```

### Minimiser les locals

Ne passer que ce qui varie réellement entre les usages. Les champs, namespaces i18n et classes CSS hardcodés dans le partial sont préférables à des locals dynamiques prématurés.

```erb
<%# ✅ Locals réduits au strict nécessaire %>
<%# locals: (f:, search_form:) %>

<%# ❌ Locals qui anticipent des usages hypothétiques %>
<%# locals: (f:, search_form:, name_field:, siret_field:, label_name:, name_col_class: "fr-col-12 fr-col-md-6") %>
```

## Sémantique des vues

Préférer les méthodes du form object aux variables d'instance brutes pour exprimer l'intention. Les vues n'ont pas à interpréter une valeur `nil` comme un signal d'état — c'est au form object d'exposer une méthode sémantique (`search_requested?`, `submitted?`, etc.).

```erb
<%# ✅ Sémantique claire %>
<% if !@search_form.search_requested? %>
  <%# hint initial %>
<% elsif @users.empty? %>
  <%# aucun résultat %>
<% end %>

<%# ❌ Valeur nil comme signal d'état %>
<% if @users.nil? %>
  <%# hint initial %>
<% elsif @users.empty? %>
  <%# aucun résultat %>
<% end %>
```

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

## Commentaires CSS sur les patterns réutilisables

Quand un pattern CSS est générique (combobox, autocomplete, widget partagé), commenter en listant ses usages actuels. Documenter la surface impactée évite les régressions lors d'une modification : la liste sert de checklist de retest.

```css
/* autocomplete : pattern de combobox réutilisable (email-autocomplete, organization-autocomplete) */
.autocomplete-wrapper { ... }
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
