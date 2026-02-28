# Sidekiq Background Jobs Setup

## Overview
Background job processing với Sidekiq cho PR Knowledge Hub. Tự động sync PRs từ GitHub và phân tích comments với AI.

## Jobs Đã Implement

### 1. SyncPullRequestsJob
Sync pull requests từ GitHub theo state (open/closed/all).

**Tham số:**
- `state`: "open", "closed", hoặc "all"
- `days`: Số ngày để sync (cho closed PRs, mặc định 7)

**Enqueue thủ công:**
```ruby
# Sync open PRs
SyncPullRequestsJob.perform_later("open")

# Sync closed PRs (7 ngày gần nhất)
SyncPullRequestsJob.perform_later("closed", 7)

# Sync all PRs
SyncPullRequestsJob.perform_later("all")
```

### 2. AnalyzeCommentsJob
Phân tích và tag comments chưa được phân tích bằng AI (50 comments/lần).

**Enqueue:**
```ruby
AnalyzeCommentsJob.perform_later
```

### 3. GenerateInsightsJob
Tạo AI insights từ code reviews (chạy hàng tuần).

**Enqueue:**
```ruby
GenerateInsightsJob.perform_later
```

## Scheduled Jobs (Cron)

Được cấu hình trong `config/schedule.yml`:

| Job | Schedule | Mô tả |
|-----|----------|-------|
| `sync_open_pull_requests` | */15 * * * * | Sync open PRs mỗi 15 phút |
| `sync_recent_pull_requests` | 0 * * * * | Sync closed PRs mỗi giờ |
| `analyze_pending_comments` | */30 * * * * | Phân tích comments mỗi 30 phút |
| `generate_weekly_insights` | 0 9 * * 1 | Tạo insights mỗi thứ 2 lúc 9:00 |

## Rake Tasks

### Xem thống kê
```bash
rake sidekiq:stats
```

### Enqueue jobs thủ công
```bash
# Sync open PRs
rake sidekiq:sync_open

# Sync closed PRs
rake sidekiq:sync_closed

# Analyze comments
rake sidekiq:analyze

# Generate insights
rake sidekiq:insights
```

### Load lại cron schedule
```bash
rake sidekiq:load_schedule
```

### Clear tất cả jobs
```bash
rake sidekiq:clear
```

## Chạy Sidekiq

### Cách 1: Chạy riêng
```bash
bundle exec sidekiq -C config/sidekiq.yml
```

### Cách 2: Dùng Procfile.dev (foreman)
```bash
# Install foreman
gem install foreman

# Start all services (Rails + Sidekiq + CSS)
foreman start -f Procfile.dev
```

Procfile.dev:
```
web: bin/rails server
css: bin/rails tailwindcss:watch
sidekiq: bundle exec sidekiq -C config/sidekiq.yml
```

## Configuration

### Redis
URL: `redis://localhost:6379/1` (Docker container đang chạy)

### Sidekiq Config (`config/sidekiq.yml`)
- Concurrency: 5 workers (dev), 10 workers (prod)
- Max retries: 3
- Queues: critical (3), default (2), low (1)

### Retry Logic (ApplicationJob)
- **RateLimitError**: Retry 5 lần với exponential backoff
- **Octokit::Error**: Retry 3 lần, chờ 5 phút giữa mỗi lần
- **ActiveRecord::Deadlocked**: Auto retry
- **DeserializationError**: Discard (không retry)

## Web UI

Sidekiq đi kèm web UI để monitor jobs. Để enable, thêm vào `config/routes.rb`:

```ruby
require 'sidekiq/web'
require 'sidekiq/cron/web'

Rails.application.routes.draw do
  mount Sidekiq::Web => '/sidekiq'
end
```

Sau đó truy cập: http://localhost:3000/sidekiq

## Testing

### Test trong Rails console
```ruby
# Check Sidekiq loaded
defined?(Sidekiq) # => "constant"

# Enqueue job
SyncPullRequestsJob.perform_later("open")

# Check queue
require 'sidekiq/api'
Sidekiq::Queue.new("default").size

# Check cron jobs
Sidekiq::Cron::Job.all.map(&:name)
```

### Test sync với repo thực
```ruby
# Đảm bảo có token GitHub hợp lệ trong .env
ENV['GITHUB_REPOSITORY'] = 'rails/rails'
SyncPullRequestsJob.perform_now("open")
```

## Lưu Ý

1. **GitHub Token**: Cần token có quyền `repo` cho private repos
2. **Redis**: Phải chạy Redis trước khi start Sidekiq
3. **Rate Limiting**: GitHub API giới hạn 5000 requests/hour, job sẽ tự retry khi hit limit
4. **AI Services**: `AnalyzeCommentsJob` và `GenerateInsightsJob` cần implement AI services trước khi hoạt động đầy đủ

## Next Steps

- [ ] Implement AI services (Gemini + OpenAI)
- [ ] Enable Sidekiq Web UI
- [ ] Setup monitoring và alerting
- [ ] Configure production deployment với Redis và Sidekiq workers
