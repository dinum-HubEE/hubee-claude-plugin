---
name: e2e
description: End-to-end testing with system specs. Use for user flow testing and integration validation.
---

# E2E Testing Skill

## Purpose

Create comprehensive end-to-end tests using RSpec system specs with Capybara.

## Setup

```ruby
# spec/system/support/capybara.rb
Capybara.default_driver = :selenium_chrome_headless
Capybara.javascript_driver = :selenium_chrome_headless
```

## Writing System Specs

### Basic Structure

```ruby
# spec/system/subscriptions_spec.rb
RSpec.describe "Subscriptions", type: :system do
  before do
    driven_by(:selenium_chrome_headless)
  end

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
