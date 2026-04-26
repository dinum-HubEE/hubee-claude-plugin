# Testing Rules

## TDD is Mandatory

Always follow RED → GREEN → REFACTOR:

1. **RED**: Write a failing test that defines expected behavior
2. **GREEN**: Write the minimum code to make the test pass
3. **REFACTOR**: Improve the code while keeping tests green

NEVER write implementation code before the test.

## Test Types

### Model Specs (unit tests)

Test validations, associations, and business logic.

```ruby
# spec/models/organization_spec.rb
RSpec.describe Organization, type: :model do
  describe "validations" do
    it { is_expected.to validate_presence_of(:siret) }
    it { is_expected.to validate_uniqueness_of(:siret) }
  end

  describe "associations" do
    it { is_expected.to have_many(:subscriptions).dependent(:destroy) }
  end

  describe "#full_identifier" do
    it "combines siret and name" do
      org = build(:organization, siret: "123", name: "Test")
      expect(org.full_identifier).to eq("123 - Test")
    end
  end
end
```

### Request Specs (integration tests)

Test controller actions and HTTP responses.

```ruby
# spec/requests/subscriptions_spec.rb
RSpec.describe "Subscriptions", type: :request do
  let(:admin) { create(:user, :admin) }

  before { sign_in admin }

  describe "GET /subscriptions" do
    it "returns success" do
      get subscriptions_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /subscriptions" do
    let(:valid_params) { { subscription: attributes_for(:subscription) } }

    it "creates a subscription" do
      expect {
        post subscriptions_path, params: valid_params
      }.to change(Subscription, :count).by(1)
    end
  end
end
```

### System Specs (E2E tests)

Test full user flows with a real browser.

```ruby
# spec/system/subscriptions_spec.rb
RSpec.describe "Managing subscriptions", type: :system do
  before do
    driven_by(:selenium_chrome_headless)
    sign_in create(:user, :admin)
  end

  it "allows creating a subscription" do
    org = create(:organization)
    process = create(:process)

    visit new_subscription_path
    select org.name, from: "Organization"
    select process.name, from: "Process"
    click_button "Create"

    expect(page).to have_content("Subscription created")
  end
end
```

## Language

All test descriptions (`it`, `context`, `describe`) MUST be in **English**.
The rest of the project (commits, MR, comments) stays in French — but specs are always English.

```ruby
# BAD
it "works"
it "should return true"
it "test subscription creation"

# GOOD
it "returns true when organization is active"
it "creates a subscription with valid params"
it "displays error for invalid SIRET"
```

## Factories Over Fixtures

Use FactoryBot for test data:

```ruby
# spec/factories/organizations.rb
FactoryBot.define do
  factory :organization do
    siret { Faker::Company.french_siret_number }
    name { Faker::Company.name }
    status { "active" }

    trait :inactive do
      status { "inactive" }
    end
  end
end
```

## Coverage Target

Minimum 80% line coverage, enforced by SimpleCov (`spec/spec_helper.rb`). Coverage runs automatically in CI and on-demand locally:

```bash
COVERAGE=true bundle exec rspec    # Generates coverage/index.html
open coverage/index.html           # Browse detailed report (line + branch)
```

Branch coverage is also tracked but not enforced as a minimum (yet).

## What NOT to Test

- Rails internals (trust the framework)
- Third-party gems
- Simple delegations
- Private methods directly (test through public interface)
