# PR Knowledge Hub - Implementation Plan

**Date:** February 28, 2026  
**Based on:** [System Design Document](../../pr_knowledge_hub/docs/plans/2026-02-28-pr-knowledge-hub-design.md)

## Implementation Phases

### Phase 1: Foundation Setup ✓
- [x] Create Rails project with optimal flags
- [x] Configure PostgreSQL database
- [x] Setup Tailwind CSS
- [x] Configure Git and GitHub repository

### Phase 2: Database & Models
- [ ] Create database schema with migrations
- [ ] Build ActiveRecord models with associations
- [ ] Add validations and scopes
- [ ] Setup pg_search for full-text search
- [ ] Create seed data for testing

### Phase 3: GitHub Integration
- [ ] Install and configure Octokit gem
- [ ] Implement GitHub::Client service
- [ ] Build PullRequestFetcher service
- [ ] Build CommentFetcher service
- [ ] Create SyncService orchestrator
- [ ] Add error handling and retry logic

### Phase 4: Background Jobs
- [ ] Install and configure Sidekiq + Redis
- [ ] Create SyncPullRequestsJob
- [ ] Create AnalyzeCommentJob
- [ ] Create GenerateInsightsJob
- [ ] Setup scheduled jobs (sidekiq-cron)

### Phase 5: AI Integration
- [ ] Install ruby-openai and gemini-ai gems
- [ ] Implement OpenaiClient service
- [ ] Implement GeminiClient service
- [ ] Build CommentClassifier service
- [ ] Build InsightGenerator service
- [ ] Add cost tracking and limits

### Phase 6: Controllers & Routes
- [ ] Setup routes structure
- [ ] Build DashboardController
- [ ] Build PullRequestsController
- [ ] Build CommentsController
- [ ] Build InsightsController
- [ ] Build SyncController (manual trigger)
- [ ] Build SearchController

### Phase 7: Views & UI
- [ ] Create application layout with navbar
- [ ] Build dashboard view with stats cards
- [ ] Build PR index view with filters
- [ ] Build PR show view with timeline
- [ ] Build insights index and show views
- [ ] Build search interface
- [ ] Add shared partials (cards, badges, etc.)

### Phase 8: Hotwire & Interactivity
- [ ] Setup Turbo Frames for lazy loading
- [ ] Add Turbo Streams for real-time updates
- [ ] Create Stimulus controllers (search, filter, collapsible)
- [ ] Add loading states and animations

### Phase 9: Authentication & Security
- [ ] Install and configure Devise
- [ ] Create User model
- [ ] Add authentication views
- [ ] Implement simple authorization
- [ ] Setup environment variables
- [ ] Add security best practices

### Phase 10: Testing & Deployment
- [ ] Write model tests
- [ ] Write service tests with VCR
- [ ] Write controller tests
- [ ] Setup CI/CD pipeline
- [ ] Deploy to staging
- [ ] Deploy to production

## Session 1: Rails Setup & Database (TODAY)

### Step 1: Create Rails Application
```bash
rails new . \
  --database=postgresql \
  --css=tailwind \
  --javascript=importmap \
  --skip-jbuilder \
  --skip-action-mailer \
  --skip-action-mailbox \
  --skip-action-text \
  --skip-active-storage \
  --force
```

### Step 2: Add Essential Gems
Add to Gemfile:
```ruby
# GitHub API
gem 'octokit', '~> 8.0'

# Background Jobs
gem 'sidekiq', '~> 7.0'
gem 'sidekiq-cron', '~> 1.12'

# Search
gem 'pg_search', '~> 2.3'

# AI APIs
gem 'ruby-openai', '~> 6.0'
gem 'gemini-ai', '~> 4.0'

# Authentication
gem 'devise', '~> 4.9'

# Utilities
gem 'dotenv-rails', '~> 2.8', groups: [:development, :test]

group :development, :test do
  gem 'rspec-rails', '~> 6.1'
  gem 'factory_bot_rails', '~> 6.4'
  gem 'faker', '~> 3.2'
  gem 'vcr', '~> 6.2'
  gem 'webmock', '~> 3.19'
end
```

### Step 3: Database Configuration
```yaml
# config/database.yml
default: &default
  adapter: postgresql
  encoding: unicode
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>

development:
  <<: *default
  database: pr_knowledge_hub_development

test:
  <<: *default
  database: pr_knowledge_hub_test

production:
  <<: *default
  database: pr_knowledge_hub_production
  username: <%= ENV['DATABASE_USERNAME'] %>
  password: <%= ENV['DATABASE_PASSWORD'] %>
```

### Step 4: Create Database
```bash
rails db:create
```

### Step 5: Generate Models & Migrations

**PullRequest Model:**
```bash
rails generate model PullRequest \
  github_id:bigint:uniq \
  number:integer \
  title:string \
  body:text \
  state:string \
  author_name:string \
  author_avatar:string \
  repository_name:string \
  repository_url:string \
  additions:integer \
  deletions:integer \
  changed_files_count:integer \
  mergeable_state:string \
  draft:boolean \
  github_created_at:datetime \
  github_updated_at:datetime \
  closed_at:datetime \
  merged_at:datetime \
  last_synced_at:datetime
```

**Comment Model:**
```bash
rails generate model Comment \
  github_id:bigint:uniq \
  pull_request:references \
  body:text \
  author_name:string \
  author_avatar:string \
  author_role:string \
  comment_type:string \
  path:string \
  position:integer \
  line:integer \
  ai_analyzed:boolean \
  ai_summary:text \
  github_created_at:datetime \
  github_updated_at:datetime
```

**Tag Model:**
```bash
rails generate model Tag \
  name:string:uniq \
  color:string \
  description:text \
  category:string
```

**CommentTag Model (Join Table):**
```bash
rails generate model CommentTag \
  comment:references \
  tag:references
```

**AiInsight Model:**
```bash
rails generate model AiInsight \
  insight_type:string \
  title:string \
  content:text \
  related_comments:jsonb \
  confidence_score:float \
  ai_model:string
```

### Step 6: Customize Migrations
Add indexes and constraints as specified in design document.

### Step 7: Run Migrations
```bash
rails db:migrate
```

### Step 8: Setup Model Associations
Add associations, validations, and scopes to models.

### Step 9: Environment Setup
```bash
# Create .env file
touch .env
echo ".env" >> .gitignore

# Add to .env
DATABASE_URL=postgresql://localhost/pr_knowledge_hub_development
GITHUB_ACCESS_TOKEN=your_token_here
GITHUB_REPOSITORY=owner/repo
OPENAI_API_KEY=your_key_here
GEMINI_API_KEY=your_key_here
REDIS_URL=redis://localhost:6379/1
```

### Step 10: Verify Setup
```bash
rails console
# Test creating a PullRequest
PullRequest.create!(
  github_id: 1,
  number: 1,
  title: "Test PR",
  state: "open",
  author_name: "test_user"
)
```

## Success Criteria for Session 1
- ✅ Rails app created with correct configuration
- ✅ PostgreSQL database created and connected
- ✅ All models generated with proper migrations
- ✅ Database schema matches design document
- ✅ Models have associations and basic validations
- ✅ Environment variables configured
- ✅ Can create records in Rails console

## Next Session Preview
Session 2 will focus on GitHub API integration:
- Implement service layer for GitHub API
- Test fetching real PR data
- Build sync mechanism
- Add error handling

## Notes
- Keep commits small and focused
- Test each component before moving forward
- Document any deviations from design
- Update this plan as needed
