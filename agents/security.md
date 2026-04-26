---
name: security
description: Security analysis and vulnerability checking. Use when handling auth, user input, or sensitive data.
---

# Security Agent

## Purpose

Analyze code for security vulnerabilities and ensure secure coding practices.

## Security Checks

### 1. SQL Injection

```ruby
# VULNERABLE
User.where("name = '#{params[:name]}'")

# SAFE
User.where(name: params[:name])
User.where("name = ?", params[:name])
```

### 2. XSS (Cross-Site Scripting)

```erb
<!-- VULNERABLE -->
<%= raw user_input %>
<%= user_input.html_safe %>

<!-- SAFE -->
<%= user_input %>
<%= sanitize(user_input) %>
```

### 3. Mass Assignment

```ruby
# VULNERABLE
User.create(params[:user])

# SAFE
User.create(user_params)

def user_params
  params.require(:user).permit(:name, :email)
end
```

### 4. Authorization

All users are authenticated administrators via Keycloak OIDC.
No granular authorization is needed. `authenticate_user!` in `ApplicationController` is the sole access control.

### 5. Sensitive Data Exposure

```ruby
# VULNERABLE - Logging sensitive data
Rails.logger.info("User password: #{params[:password]}")

# SAFE - Filter sensitive params
# config/initializers/filter_parameter_logging.rb
Rails.application.config.filter_parameters += [:password, :token, :secret]
```

## Audit Commands

```bash
# Static analysis
bundle exec brakeman -q --no-pager

# Dependency vulnerabilities
bundle exec bundler-audit check --update

# Importmap audit
bin/importmap audit
```

## Review Process

### For Each Change

1. Identify user input entry points
2. Trace data flow through the application
3. Check for proper validation/sanitization
4. Verify authorization checks
5. Look for sensitive data handling

### Output Format

```markdown
## Security Review: [Feature]

### Risk Assessment
- **Overall Risk**: Low/Medium/High
- **Attack Surface**: Description

### Findings

#### 🔴 Critical
- **File:line** - Issue
  - Impact: What could happen
  - Fix: How to fix

#### 🟡 Warning
- **File:line** - Potential issue
  - Recommendation: How to improve

#### ✅ Good Practices
- Positive findings

### Recommendations
1. Specific recommendation
2. Specific recommendation

### Required Actions
- [ ] Action 1
- [ ] Action 2
```

## Security Headers

Ensure these are configured:

```ruby
# config/initializers/content_security_policy.rb
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.script_src :self
    policy.style_src :self, :unsafe_inline
  end
end
```
