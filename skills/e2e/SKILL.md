---
name: e2e
description: "Tests end-to-end des parcours utilisateur avec Capybara : system specs RSpec ou features Cucumber selon le projet (drivers, tag @javascript, simulation d'un fournisseur externe). À utiliser pour écrire ou relire un test de parcours de bout en bout."
---

# E2E Testing Skill

## Purpose

Couvrir les parcours utilisateur de bout en bout avec Capybara.

Selon le projet, la couche E2E est en **system specs RSpec** (`spec/system/`) ou en **features Cucumber** (`features/`) — vérifier `bin/ci`, qui nomme la ou les commandes de la step E2E. La philosophie est la même des deux côtés : **rack_test par défaut** (rapide, sans navigateur), navigateur réel seulement quand le JavaScript compte.

## Cucumber comme couche E2E

Certains projets (portail V2, `datagouv/hubee`) portent leur E2E en Cucumber, exécuté par `bin/ci` comme step distincte (`bundle exec cucumber`).

### Drivers

- Défaut : `rack_test`. Les scénarios qui exigent un vrai navigateur portent le tag **`@javascript`** — capybara/cucumber bascule seul sur `Capybara.javascript_driver` (`:selenium_chrome_headless`).
- **Piège Selenium Manager sur Linux ARM** : Selenium Manager n'a pas de binaire Linux ARM. Quand un chromedriver système existe (`/usr/bin/chromedriver`), pointer explicitement dessus via `Selenium::WebDriver::Service.chrome(path:)` (et `options.binary` vers le chromium système) ; ailleurs, laisser la résolution automatique. Référence : `features/support/capybara.rb`.

### Support

`features/support/world.rb` : `World(FactoryBot::Syntax::Methods)` + `require "cucumber/rspec/doubles"` — les stubs rspec-mocks posés dans les steps sont **valables** parce que l'app tourne dans le même process que les scénarios : un stub de classe est vu par le serveur Capybara.

### Simuler un fournisseur externe : boucler sur son propre callback

Pour un parcours qui traverse un fournisseur externe (OIDC…), ne pas mocker le navigateur ni monter un faux serveur : stubber le client pour que **l'URL d'autorisation boucle sur notre propre callback** avec le state attendu. Le navigateur joue alors toute la chaîne de redirections, **sans réseau**. Référence : `features/step_definitions/portail_steps.rb` (ProConnect simulé).

## Setup des system specs RSpec

Le driver par défaut pour les system specs est `:rack_test` (rapide, sans navigateur). Utiliser `:selenium_chrome_headless` uniquement pour les specs qui nécessitent du JavaScript via la metadata `js: true`.

```ruby
# spec/rails_helper.rb (ou spec/support/system.rb)
RSpec.configure do |config|
  config.before(:each, type: :system) { driven_by :rack_test }
  config.before(:each, type: :system, js: true) { driven_by :selenium_chrome_headless }
end
```

Ne pas mettre `driven_by` dans un `before` block du spec lui-même. Ne pas mettre `driven_by :selenium_chrome_headless` globalement.

## Nommage des fichiers

Nommer le fichier spec précisément selon ce qui est testé, pas selon la ressource.

```
# ✅ Précis
spec/system/users_search_organization_autocomplete_spec.rb
spec/system/subscriptions_pdf_export_spec.rb

# ❌ Trop vague (on ne sait pas quel flux est couvert)
spec/system/users_spec.rb
spec/system/subscriptions_spec.rb
```

## Writing System Specs

### Basic Structure

```ruby
# spec/system/subscriptions_list_spec.rb
RSpec.describe "Subscriptions list", type: :system do
  let(:admin) { create(:user, :admin) }

  before { sign_in admin }

  describe "listing subscriptions" do
    it "displays all subscriptions" do
      subscriptions = create_list(:subscription, 3)

      visit subscriptions_path

      subscriptions.each do |sub|
        expect(page).to have_content(sub.organization.name)
      end
    end
  end

  describe "creating a subscription" do
    let!(:organization) { create(:organization) }
    let!(:process) { create(:process) }

    it "allows creating a new subscription" do
      visit new_subscription_path

      select organization.name, from: "Organization"
      select process.name, from: "Process"
      fill_in "Notes", with: "Test notes"
      click_button "Create Subscription"

      expect(page).to have_content("Subscription created")
      expect(page).to have_content(organization.name)
    end

    it "shows validation errors" do
      visit new_subscription_path
      click_button "Create Subscription"

      expect(page).to have_content("Organization must exist")
    end
  end

  describe "editing a subscription" do
    let!(:subscription) { create(:subscription) }

    it "allows updating the subscription" do
      visit edit_subscription_path(subscription)

      fill_in "Notes", with: "Updated notes"
      click_button "Update Subscription"

      expect(page).to have_content("Subscription updated")
      expect(page).to have_content("Updated notes")
    end
  end

  describe "deleting a subscription" do
    let!(:subscription) { create(:subscription) }

    it "allows deleting the subscription" do
      visit subscription_path(subscription)

      accept_confirm do
        click_button "Delete"
      end

      expect(page).to have_content("Subscription deleted")
      expect(page).not_to have_content(subscription.organization.name)
    end
  end
end
```

### Testing Turbo Frames

```ruby
describe "inline editing with Turbo" do
  let!(:subscription) { create(:subscription) }

  it "updates subscription inline" do
    visit subscriptions_path

    within "#subscription_#{subscription.id}" do
      click_link "Edit"

      # Turbo Frame replaces content
      fill_in "Notes", with: "Inline edit"
      click_button "Save"
    end

    # Verify update without page reload
    expect(page).to have_content("Inline edit")
    expect(page).not_to have_field("Notes")
  end
end
```

### Testing JavaScript

Annoter avec `js: true` — le driver `:selenium_chrome_headless` est activé automatiquement via `rails_helper`.

```ruby
describe "dynamic form", js: true do
  it "validates form in real-time" do
    visit new_subscription_path

    fill_in "SIRET", with: "invalid"
    find("body").click  # Trigger blur

    expect(page).to have_content("Invalid SIRET format")
  end
end
```

## Capybara Matchers

```ruby
# Content
expect(page).to have_content("text")
expect(page).to have_text("text")

# Elements
expect(page).to have_selector("css")
expect(page).to have_css(".class")
expect(page).to have_xpath("//xpath")

# Forms
expect(page).to have_field("Label")
expect(page).to have_button("Text")
expect(page).to have_link("Text")

# Tables
expect(page).to have_table("id")

# Within scope
within("#element") do
  expect(page).to have_content("scoped")
end
```

## Commands

```bash
# Run system specs
bundle exec rspec spec/system

# Run with visible browser (debugging)
HEADLESS=false bundle exec rspec spec/system

# Run specific file
bundle exec rspec spec/system/subscriptions_spec.rb
```

## Debugging

```ruby
# Take screenshot
save_screenshot("debug.png")

# Pause execution
binding.pry

# Print page content
puts page.body
```
