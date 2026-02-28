# Authentication Implementation

## Overview
This document describes the authentication implementation using Devise gem for the PR Knowledge Hub application.

## Implementation Date
February 28, 2026

## Technology Stack
- **Devise**: 4.9+ - Industry standard authentication solution for Rails
- **Rails**: 8.0.2 - With ActionMailer enabled for password reset emails
- **Tailwind CSS**: Custom styled views for consistent UI

## Features Implemented

### 1. User Model
- **Email/Password Authentication**: Standard Devise setup with database authentication
- **Rememberable**: "Remember me" functionality for persistent sessions
- **Recoverable**: Password reset via email
- **Validatable**: Email and password validation
- **Database Fields**:
  - `email` (unique, indexed)
  - `encrypted_password`
  - `reset_password_token` (indexed)
  - `reset_password_sent_at`
  - `remember_created_at`
  - Timestamps

### 2. Protected Routes
The following routes require authentication:

#### Sidekiq Web UI
```ruby
authenticate :user do
  mount Sidekiq::Web => '/sidekiq'
end
```
- **Access**: `/sidekiq`
- **Protection**: Only authenticated users can access
- **Redirect**: Non-authenticated users → `/users/sign_in`

#### Sync API Endpoints
```ruby
class Sync::BaseController < ApplicationController
  before_action :authenticate_user!
end
```
- **Routes**:
  - `POST /sync/pull_requests` - Manual PR sync
  - `POST /sync/comments` - Manual comment sync
  - `POST /sync/analyze` - Manual AI analysis trigger
  - `GET /sync/status` - Sidekiq queue status
- **Protection**: Only authenticated users can trigger syncs

### 3. Public Routes
The following routes remain publicly accessible:
- Dashboard (`/`)
- Pull Requests listing (`/pull_requests`)
- Pull Request details (`/pull_requests/:id`)
- Insights listing (`/insights`)
- Insight details (`/insights/:id`)
- Search (`/search`)
- Health check (`/up`)

### 4. Custom Views with Tailwind CSS

#### Sign In Page (`/users/sign_in`)
- Centered card layout with app logo
- Email and password fields with focus states
- "Remember me" checkbox
- Form validation with styled error messages
- Links to Sign Up and Forgot Password
- Consistent with app's design system

#### Sign Up Page (`/users/sign_up`)
- Similar layout to Sign In
- Email, password, and password confirmation fields
- Password requirements display (minimum 6 characters)
- Form validation with error styling
- Links to Sign In and other actions

#### Forgot Password Page (`/users/password/new`)
- Email input for password reset
- Styled submit button
- Links back to Sign In and Sign Up
- Email instructions message

#### Shared Partials
- **Error Messages** (`devise/shared/_error_messages.html.erb`):
  - Red alert box with error icon
  - List of validation errors
  - Dismissible with Turbo cache disabled

- **Links** (`devise/shared/_links.html.erb`):
  - Contextual navigation between auth pages
  - Blue link styling consistent with app
  - Proper spacing and hover effects

### 5. Navigation Updates
Application layout (`app/views/layouts/application.html.erb`) now includes:

```erb
<% if user_signed_in? %>
  <span class="text-sm text-gray-700">
    <%= current_user.email %>
  </span>
  <%= button_to "Sign Out", destroy_user_session_path, method: :delete,
      class: "px-4 py-2 bg-gray-600 hover:bg-gray-700 text-white rounded-lg" %>
<% else %>
  <%= link_to "Sign In", new_user_session_path,
      class: "px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-lg" %>
<% end %>
```

## Configuration

### ActionMailer Setup
Added to `config/application.rb`:
```ruby
require "action_mailer/railtie"
```

Added to `config/environments/development.rb`:
```ruby
config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }
```

### Devise Initializer
Generated at `config/initializers/devise.rb` with default configuration:
- Secret key from `config/credentials.yml.enc`
- Email sender: `please-change-me-at-config-initializers-devise@example.com`
- Password length: 6-128 characters
- Sign out via DELETE method
- Session timeout: 30 days (remember_me)

## Test User
A test user is created via `db/seeds.rb` for development:

```ruby
# Email: admin@example.com
# Password: password123
```

Run `rails db:seed` to create the test user.

## Routes Added by Devise

```
GET    /users/sign_in       → devise/sessions#new
POST   /users/sign_in       → devise/sessions#create
DELETE /users/sign_out      → devise/sessions#destroy

GET    /users/sign_up       → devise/registrations#new
POST   /users              → devise/registrations#create

GET    /users/password/new → devise/passwords#new
POST   /users/password     → devise/passwords#create
GET    /users/password/edit → devise/passwords#edit
PATCH  /users/password     → devise/passwords#update
```

## Security Features

### 1. CSRF Protection
- Enabled by default in ApplicationController
- Temporarily disabled for Sync API endpoints (expects API keys in production)

### 2. Session Security
- Secure cookies in production
- HTTP-only session cookies
- SameSite protection enabled

### 3. Password Security
- BCrypt encryption (Devise default)
- Minimum 6 characters
- Password confirmation required on sign up
- Password reset with time-limited tokens

## Testing Authentication

### Manual Testing Steps

1. **Test Sign In**:
   ```bash
   curl -I http://localhost:3000/users/sign_in
   # Expected: 200 OK with sign in form
   ```

2. **Test Protected Route (Not Authenticated)**:
   ```bash
   curl -I http://localhost:3000/sidekiq
   # Expected: 302 Found → redirect to /users/sign_in
   ```

3. **Test Sign In with Test User**:
   - Visit `http://localhost:3000/users/sign_in`
   - Email: `admin@example.com`
   - Password: `password123`
   - Should redirect to dashboard with "Signed in successfully" message

4. **Test Sidekiq Access (Authenticated)**:
   - After signing in, visit `http://localhost:3000/sidekiq`
   - Should display Sidekiq dashboard (not redirect)

5. **Test Sign Out**:
   - Click "Sign Out" button in navbar
   - Should redirect to root page with "Signed out successfully" message
   - Try accessing `/sidekiq` → should redirect to sign in

### RSpec Tests (TODO - Phase 10)
```ruby
# spec/features/authentication_spec.rb
RSpec.describe 'Authentication', type: :feature do
  describe 'Sign in' do
    it 'allows user to sign in with valid credentials'
    it 'rejects invalid credentials'
    it 'redirects to original page after sign in'
  end

  describe 'Protected routes' do
    it 'redirects to sign in when accessing Sidekiq without auth'
    it 'allows access to Sidekiq when authenticated'
  end
end
```

## Production Considerations

### 1. Email Configuration
Update `config/environments/production.rb`:
```ruby
config.action_mailer.default_url_options = {
  host: 'your-domain.com',
  protocol: 'https'
}

# Configure SMTP (e.g., SendGrid, Mailgun, AWS SES)
config.action_mailer.delivery_method = :smtp
config.action_mailer.smtp_settings = {
  address: ENV['SMTP_ADDRESS'],
  port: ENV['SMTP_PORT'],
  user_name: ENV['SMTP_USERNAME'],
  password: ENV['SMTP_PASSWORD'],
  authentication: 'plain',
  enable_starttls_auto: true
}
```

### 2. Secret Key
Ensure `config/credentials.yml.enc` has:
```yaml
secret_key_base: <generated-secret>
devise:
  secret_key: <generated-secret>
```

Generate secrets with:
```bash
rails secret
```

### 3. SSL/HTTPS
Enable secure cookies in production:
```ruby
# config/environments/production.rb
config.force_ssl = true
```

### 4. Email Sender
Update in `config/initializers/devise.rb`:
```ruby
config.mailer_sender = 'noreply@your-domain.com'
```

### 5. CORS for Sync API
If exposing sync endpoints as public API:
```ruby
# Add to Gemfile
gem 'rack-cors'

# Configure in config/application.rb
config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins '*'
    resource '/sync/*',
      headers: :any,
      methods: [:post, :get],
      credentials: false
  end
end
```

## Future Enhancements

### 1. Role-Based Access Control (RBAC)
- Add `role` column to users table (admin, member, viewer)
- Implement authorization with Pundit gem
- Restrict Sidekiq and Sync to admin role only

### 2. OAuth Integration
- GitHub OAuth (authenticate with GitHub account)
- Google OAuth
- Microsoft OAuth

### 3. Two-Factor Authentication (2FA)
- Add `devise-two-factor` gem
- QR code generation for authenticator apps
- Backup codes

### 4. Session Management
- Active sessions list
- Sign out all devices
- Session expiration policies

### 5. Audit Logging
- Track user sign ins/outs
- Log access to protected endpoints
- Failed authentication attempts

## Troubleshooting

### Issue: "undefined method 'action_mailer'"
**Solution**: Uncomment `require "action_mailer/railtie"` in `config/application.rb`

### Issue: Email not sending in development
**Solution**:
1. Check `config/environments/development.rb` has `default_url_options`
2. Use `letter_opener` gem to preview emails in browser:
   ```ruby
   # Gemfile
   gem 'letter_opener', group: :development

   # config/environments/development.rb
   config.action_mailer.delivery_method = :letter_opener
   ```

### Issue: Sidekiq dashboard accessible without auth
**Solution**: Ensure routes.rb has:
```ruby
authenticate :user do
  mount Sidekiq::Web => '/sidekiq'
end
```

## References
- [Devise Documentation](https://github.com/heartcombo/devise)
- [Devise Wiki](https://github.com/heartcombo/devise/wiki)
- [Rails Security Guide](https://guides.rubyonrails.org/security.html)
- [Tailwind CSS Forms](https://tailwindcss.com/docs/forms)

## Summary
✅ User authentication with Devise
✅ Protected admin routes (Sidekiq, Sync endpoints)
✅ Custom Tailwind CSS views
✅ Test user seeded for development
✅ Navigation updated with sign in/out links
✅ Password reset functionality
✅ Form validation with styled error messages

Phase 9 authentication implementation is **complete** and ready for testing in Phase 10.
