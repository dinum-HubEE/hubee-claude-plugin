---
name: hotwire
description: Hotwire, Turbo Drive, Turbo Frames, Turbo Streams, Stimulus controllers. Use when building interactive UI, dynamic updates, or JavaScript behavior.
globs:
  - "app/views/**/*.erb"
  - "app/views/**/*.turbo_stream.erb"
  - "app/javascript/controllers/**/*.js"
---

# Hotwire Skill

## Turbo Drive

Turbo Drive is enabled by default. It intercepts link clicks and form submissions, replacing page content via AJAX.

### Disabling for specific links

```erb
<!-- Disable Turbo for this link -->
<%= link_to "External", "https://example.com", data: { turbo: false } %>

<!-- Force full page reload -->
<%= link_to "Reload", path, data: { turbo_action: "replace" } %>
```

## Turbo Frames

Turbo Frames allow partial page updates.

### Basic Frame

```erb
<!-- app/views/subscriptions/index.html.erb -->
<%= turbo_frame_tag "subscriptions" do %>
  <% @subscriptions.each do |subscription| %>
    <%= render subscription %>
  <% end %>
<% end %>
```

### Lazy Loading

```erb
<!-- Load content lazily when frame becomes visible -->
<%= turbo_frame_tag "stats", src: stats_path, loading: :lazy do %>
  <p>Loading stats...</p>
<% end %>
```

### Breaking out of frames

```erb
<!-- Link targets the whole page, not the frame -->
<%= link_to "View Details", subscription_path(@subscription),
    data: { turbo_frame: "_top" } %>
```

### Frame Navigation

```erb
<!-- Form that updates a different frame -->
<%= form_with url: search_path, data: { turbo_frame: "results" } do |f| %>
  <%= f.search_field :q %>
  <%= f.submit "Search" %>
<% end %>

<%= turbo_frame_tag "results" do %>
  <!-- Search results appear here -->
<% end %>
```

## Turbo Streams

Real-time DOM updates from the server.

### Stream Actions

```erb
<!-- app/views/subscriptions/create.turbo_stream.erb -->

<!-- Append to a list -->
<%= turbo_stream.append "subscriptions" do %>
  <%= render @subscription %>
<% end %>

<!-- Prepend to a list -->
<%= turbo_stream.prepend "subscriptions" do %>
  <%= render @subscription %>
<% end %>

<!-- Replace an element -->
<%= turbo_stream.replace @subscription do %>
  <%= render @subscription %>
<% end %>

<!-- Update content (keeps the element) -->
<%= turbo_stream.update "flash" do %>
  <%= render "shared/flash" %>
<% end %>

<!-- Remove an element -->
<%= turbo_stream.remove @subscription %>
```

### Controller Response

```ruby
def create
  @subscription = Subscription.new(subscription_params)

  respond_to do |format|
    if @subscription.save
      format.turbo_stream
      format.html { redirect_to @subscription }
    else
      format.html { render :new, status: :unprocessable_entity }
    end
  end
end
```

## Stimulus Controllers

### Basic Controller

```javascript
// app/javascript/controllers/toggle_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content"]
  static values = { open: Boolean }

  toggle() {
    this.openValue = !this.openValue
  }

  openValueChanged() {
    this.contentTarget.classList.toggle("hidden", !this.openValue)
  }
}
```

```erb
<div data-controller="toggle" data-toggle-open-value="false">
  <button data-action="toggle#toggle">Toggle</button>
  <div data-toggle-target="content" class="hidden">
    Content here
  </div>
</div>
```

### Form Controller

```javascript
// app/javascript/controllers/form_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["submit"]

  connect() {
    this.validate()
  }

  validate() {
    const form = this.element
    const isValid = form.checkValidity()
    this.submitTarget.disabled = !isValid
  }
}
```

```erb
<%= form_with model: @subscription, data: { controller: "form" } do |f| %>
  <%= f.text_field :name, required: true, data: { action: "input->form#validate" } %>
  <%= f.submit "Save", data: { form_target: "submit" } %>
<% end %>
```

### Debounce Search

```javascript
// app/javascript/controllers/search_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]
  static values = { url: String }

  search() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => {
      const query = this.inputTarget.value
      Turbo.visit(`${this.urlValue}?q=${encodeURIComponent(query)}`, {
        frame: "results"
      })
    }, 300)
  }
}
```

## Common Patterns

### Flash Messages with Turbo

```erb
<!-- app/views/layouts/application.html.erb -->
<%= turbo_frame_tag "flash" do %>
  <%= render "shared/flash" %>
<% end %>
```

```erb
<!-- Update flash in turbo_stream response -->
<%= turbo_stream.update "flash" do %>
  <div class="alert alert-success">Saved!</div>
<% end %>
```

### Modal with Turbo Frame

```erb
<!-- Link opens modal -->
<%= link_to "Edit", edit_subscription_path(@subscription),
    data: { turbo_frame: "modal" } %>

<!-- Modal frame (empty by default) -->
<%= turbo_frame_tag "modal" %>

<!-- edit.html.erb targets the modal frame -->
<%= turbo_frame_tag "modal" do %>
  <div class="modal">
    <%= render "form" %>
  </div>
<% end %>
```
