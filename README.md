# PR Knowledge Hub

A Rails application for analyzing GitHub pull request comments using AI (OpenAI GPT-4 and Google Gemini) to extract insights, patterns, and recommendations.

## 📋 Prerequisites

- Ruby 3.4.7
- PostgreSQL 14+
- Redis 7+
- Node.js 18+ (for Tailwind CSS)

## 🚀 Quick Start

### 1. Clone the repository

```bash
git clone https://github.com/LocNguyenSGU/pr_knowledge_hub.git
cd pr_knowledge_hub
```

### 2. Setup environment variables

Copy the example environment file and configure your API keys:

```bash
cp .env.example .env
```

Edit `.env` and add your API keys:

**Required Variables:**
- `OPENAI_API_KEY`: Get from [OpenAI Platform](https://platform.openai.com/api-keys)
- `GEMINI_API_KEY`: Get from [Google AI Studio](https://makersuite.google.com/app/apikey)
- `GITHUB_ACCESS_TOKEN`: Create from [GitHub Settings](https://github.com/settings/tokens) with `repo` and `read:user` scopes
- `GITHUB_REPOSITORY`: Your repository in format `owner/repo` (e.g., `LocNguyenSGU/pr_knowledge_hub`)

### 3. Install dependencies and setup database

```bash
bin/setup
```

This will:
- Install Ruby gems
- Install JavaScript dependencies
- Create and migrate databases
- Seed sample data (6 test users)
- Start the development server

### 4. Access the application

Open http://localhost:3000 in your browser.

**Test User Credentials:**
- Email: `admin@example.com`
- Password: `password123`

(5 additional users: `user1@example.com` to `user5@example.com`, all with password `password123`)

## 🧪 Running Tests

```bash
# Run full test suite with coverage
bin/ci

# Run only RSpec tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/models/pull_request_spec.rb
```

**Test Coverage:** 93.92% (572/609 lines)

## 🔧 Configuration

### Environment Variables

See `.env.example` for all available configuration options.

**Key configurations:**
- `REDIS_URL`: Redis connection (default: `redis://localhost:6379/1`)
- `PORT`: Server port (default: `3000`)
- `RAILS_MAX_THREADS`: Puma threads (default: `3`)

### Database

The application uses PostgreSQL with the following databases:
- Development: `pr_knowledge_hub_development`
- Test: `pr_knowledge_hub_test`
- Production: Configured via `DATABASE_URL`

## 📊 Features

- **GitHub Integration**: Sync pull requests and comments from GitHub
- **AI Analysis**: Classify comments using Gemini AI
- **Insight Generation**: Generate weekly insights using OpenAI GPT-4
- **Tag Management**: Automatic tagging of comments by category
- **Background Jobs**: Sidekiq for async processing
- **Dashboard**: Visualize PR and comment statistics

## 🏗️ Architecture

### Services
- `Github::Client`: GitHub API integration
- `Github::SyncService`: Sync PRs and comments
- `Ai::CommentClassifier`: Classify comments with Gemini
- `Ai::InsightGenerator`: Generate insights with OpenAI

### Background Jobs
- `SyncPullRequestsJob`: Sync PRs from GitHub (scheduled)
- `AnalyzeCommentsJob`: Analyze comments with AI
- `GenerateInsightsJob`: Generate weekly insights

### Models
- `PullRequest`: GitHub pull requests
- `Comment`: PR review comments
- `Tag`: Comment categories
- `AiInsight`: Generated insights
- `User`: Devise authentication

## 🔐 Security

- Brakeman security scanning in CI
- RuboCop linting with Ruby style guide
- ERB Lint for view templates
- Test coverage > 90%

## 📝 Development

### Linting

```bash
# Ruby code style
bundle exec rubocop

# ERB templates
bundle exec erb_lint --lint-all

# Security scan
bin/brakeman
```

### Seeding Data

```bash
# Reset and reseed database
bin/rails db:seed:replant

# Or just seed
bin/rails db:seed
```

## 🚢 Deployment

The application is configured for deployment with Kamal. See `config/deploy.yml` for configuration.

```bash
# Deploy to production
kamal deploy
```

## 📄 License

This project is private and proprietary.

## 👥 Contributors

- Loc Nguyen - [LocNguyenSGU](https://github.com/LocNguyenSGU)
