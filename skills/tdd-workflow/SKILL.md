---
name: tdd-workflow
description: TDD methodology, RSpec patterns, test writing. Use when writing tests, specs, creating features with TDD, or debugging test failures.
globs:
  - "spec/**/*.rb"
  - "spec/factories/**/*.rb"
  - "spec/support/**/*.rb"
---

> **Override de `superpowers:test-driven-development`** : cette skill ajoute les conventions HubEE Rails (RSpec, FactoryBot, SimpleCov 80% mini, descriptions `it`/`describe` en anglais) au cycle RED-GREEN-REFACTOR fourni par superpowers. Quand les deux sont disponibles, suivre cette skill HubEE.

# TDD Workflow Skill

## The TDD Cycle

### 1. RED - Write a failing test

```ruby
# spec/models/subscription_spec.rb
RSpec.describe Subscription, type: :model do
  describe "#active?" do
    it "returns true when status is active" do
      subscription = build(:subscription, status: "active")
      expect(subscription.active?).to be true
    end

    it "returns false when status is inactive" do
      subscription = build(:subscription, status: "inactive")
      expect(subscription.active?).to be false
    end
  end
end
```

Run: `bundle exec rspec spec/models/subscription_spec.rb`
Expected: RED (method doesn't exist)

### 2. GREEN - Minimum code to pass

```ruby
# app/models/subscription.rb
class Subscription < ApplicationRecord
  def active?
    status == "active"
  end
end
```

Run: `bundle exec rspec spec/models/subscription_spec.rb`
Expected: GREEN

### 3. REFACTOR - Improve while green

```ruby
# Maybe extract to a concern if pattern repeats
module Statusable
  extend ActiveSupport::Concern

  included do
    scope :active, -> { where(status: "active") }
  end

  def active?
    status == "active"
  end
end
```

## RSpec Patterns

### Model Specs

```ruby
RSpec.describe Organization, type: :model do
  # Use shoulda-matchers for validations
  describe "validations" do
    it { is_expected.to validate_presence_of(:siret) }
    it { is_expected.to validate_uniqueness_of(:siret) }
  end

  # Use shoulda-matchers for associations
  describe "associations" do
    it { is_expected.to have_many(:subscriptions) }
    it { is_expected.to belong_to(:parent).optional }
  end

  # Test custom methods
  describe "#full_name" do
    subject(:org) { build(:organization, siret: "123", name: "Test") }

    it "combines siret and name" do
      expect(org.full_name).to eq("123 - Test")
    end
  end
end
```

### Request Specs

```ruby
RSpec.describe "Subscriptions", type: :request do
  let(:user) { create(:user, :admin) }

  before { sign_in user }

  describe "GET /subscriptions" do
    it "returns http success" do
      get subscriptions_path
      expect(response).to have_http_status(:success)
    end

    it "renders the index template" do
      get subscriptions_path
      expect(response).to render_template(:index)
    end
  end

  describe "POST /subscriptions" do
    context "with valid params" do
      let(:valid_params) do
        { subscription: attributes_for(:subscription) }
      end

      it "creates a new subscription" do
        expect {
          post subscriptions_path, params: valid_params
        }.to change(Subscription, :count).by(1)
      end

      it "redirects to the subscription" do
        post subscriptions_path, params: valid_params
        expect(response).to redirect_to(Subscription.last)
      end
    end

    context "with invalid params" do
      let(:invalid_params) do
        { subscription: { organization_id: nil } }
      end

      it "does not create a subscription" do
        expect {
          post subscriptions_path, params: invalid_params
        }.not_to change(Subscription, :count)
      end

      it "renders the new template" do
        post subscriptions_path, params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
```

### Factories

```ruby
# spec/factories/subscriptions.rb
FactoryBot.define do
  factory :subscription do
    organization
    process

    status { "active" }
    created_at { Time.current }

    trait :inactive do
      status { "inactive" }
    end

    trait :with_notes do
      notes { Faker::Lorem.paragraph }
    end
  end
end
```

## Commands

```bash
# Run all specs
bundle exec rspec

# Run specific file
bundle exec rspec spec/models/subscription_spec.rb

# Run specific line
bundle exec rspec spec/models/subscription_spec.rb:15

# Run with documentation format
bundle exec rspec --format documentation

# Run only failures
bundle exec rspec --only-failures

# Run with coverage
COVERAGE=true bundle exec rspec
```
