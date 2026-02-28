# AI Services Documentation

## Overview
AI-powered services để tự động phân tích và tổng hợp insights từ code review comments. Sử dụng kết hợp Gemini AI (Google) và OpenAI GPT-4.

## Architecture

### Service Layer
```
app/services/ai/
├── gemini_client.rb       # Gemini AI wrapper (classification, pattern detection)
├── openai_client.rb       # OpenAI wrapper (summaries, insights)
├── comment_classifier.rb  # Auto-classify comments into categories
└── insight_generator.rb   # Generate weekly insights and lessons
```

### AI Models Used
- **Gemini 2.5 Flash**: Fast, cost-effective classification and pattern detection
- **GPT-4o Mini**: High-quality summaries and recommendations

## Features

### 1. Comment Classification (Gemini)
Tự động phân loại comments vào các categories:
- `security` - Security vulnerabilities
- `performance` - Performance issues
- `code_style` - Code style and formatting
- `best_practice` - Best practices
- `bug` - Bug reports
- `refactoring` - Refactoring suggestions
- `testing` - Testing-related
- `documentation` - Documentation
- `question` - Questions

**Usage:**
```ruby
classifier = Ai::CommentClassifier.new

# Classify single comment
comment = Comment.find(1)
classifier.classify(comment)

# Classify batch
comments = Comment.unanalyzed.limit(50)
results = classifier.classify_batch(comments)
# => { success: 45, failed: 2, skipped: 3 }

# Re-classify untagged comments
classifier.reclassify_untagged(limit: 100)
```

### 2. Pattern Analysis (Gemini)
Phát hiện patterns và trends trong code reviews.

**Usage:**
```ruby
gemini = Ai::GeminiClient.new
comments = Comment.recent.limit(100)
analysis = gemini.analyze_patterns(comments)

# Returns:
# {
#   patterns: ["Frequent SQL injection concerns", ...],
#   lessons: ["Always use parameterized queries", ...],
#   recommendations: ["Add security linting", ...]
# }
```

### 3. Insight Generation (Gemini + OpenAI)
Tạo comprehensive insights từ code review data.

**Usage:**
```ruby
generator = Ai::InsightGenerator.new

# Weekly insights (last 7 days)
insight = generator.generate_weekly_insights(days: 7)

# Tag-specific insights
insight = generator.generate_tag_insights("security", days: 30)

# Access the generated content
puts insight.title
puts insight.content
puts insight.metadata  # Stats, patterns, lessons, recommendations
```

### 4. Summary Generation (OpenAI)
Tạo executive summaries về code review trends.

**Usage:**
```ruby
openai = Ai::OpenaiClient.new
comments = Comment.where("created_at >= ?", 1.week.ago)

summary = openai.generate_insights_summary(comments, time_period: "last week")
lessons = openai.extract_lessons(comments)
recommendations = openai.generate_recommendations(analysis_data)
```

## Background Jobs

### AnalyzeCommentsJob
Chạy mỗi 30 phút, classify 50 comments mỗi lần.

```ruby
# Enqueue manually
AnalyzeCommentsJob.perform_later

# Via rake
rake sidekiq:analyze
```

### GenerateInsightsJob
Chạy mỗi thứ 2 lúc 9:00 AM, tạo weekly insights.

```ruby
# Enqueue manually (with custom days)
GenerateInsightsJob.perform_later(14)

# Via rake
rake ai:insights[7]
```

## Rake Tasks

### Test AI Configuration
```bash
rake ai:test
```
Kiểm tra API keys và test connection tới cả 2 AI services.

### Classify Comments
```bash
# Classify single comment
rake ai:classify[123]

# Classify all unanalyzed (interactive)
rake ai:classify_all
```

### Generate Insights
```bash
# Weekly insights (last 7 days)
rake ai:insights[7]

# Monthly insights
rake ai:insights[30]

# Tag-specific insights
rake ai:tag_insights[security,30]
```

### View Statistics
```bash
rake ai:stats
```

## Configuration

### Environment Variables (.env)
```bash
# Gemini AI (Google)
GEMINI_API_KEY=your_gemini_api_key_here

# OpenAI
OPENAI_API_KEY=sk-your_openai_key_here
```

### Getting API Keys

**Gemini AI:**
1. Visit: https://aistudio.google.com/app/apikey
2. Create API key
3. Copy to `.env` file

**OpenAI:**
1. Visit: https://platform.openai.com/api-keys
2. Create new secret key
3. Copy to `.env` file

## Cost Estimation

### Gemini 2.5 Flash (Free Tier)
- **Free quota**: 1,500 requests/day
- **Rate limit**: 15 RPM
- **Cost after free tier**: ~$0.075 per 1M input tokens

**Example:** Classifying 1,000 comments/day = ~500 requests = Free

### OpenAI GPT-4o Mini
- **Input**: $0.150 per 1M tokens
- **Output**: $0.600 per 1M tokens

**Example:** Weekly insight (100 comments):
- Input: ~5,000 tokens = $0.00075
- Output: ~1,000 tokens = $0.0006
- **Total**: ~$0.0014 per insight

**Monthly cost estimate:** ~$10-20 for team of 10 people

## Error Handling

### Rate Limiting
Both services có built-in retry logic:
- Gemini: 15 requests/minute
- OpenAI: Depends on tier (3-90 RPM)

Jobs sẽ tự động retry với exponential backoff.

### Failed Classifications
Comments that fail classification được marked as `analyzed: true` nhưng không có tags. Có thể re-classify bằng:

```ruby
classifier = Ai::CommentClassifier.new
classifier.reclassify_untagged(limit: 100)
```

### API Errors
Tất cả errors được log trong Rails logs:
```ruby
Rails.logger.error "Gemini classification failed: #{e.message}"
```

## Best Practices

### 1. Rate Limiting
```ruby
# In batch operations, add delays between requests
comments.each do |comment|
  classifier.classify(comment)
  sleep 0.5  # 2 requests/second
end
```

### 2. Cost Control
```ruby
# Batch size limits
BATCH_SIZE = 50  # Process 50 comments at a time

# Scheduled frequency
# Every 30 min for classification
# Weekly for insights (not daily)
```

### 3. Quality Check
```ruby
# Review untagged comments
Comment.analyzed.left_joins(:comment_tags)
       .where(comment_tags: { id: nil })
       .each do |comment|
  puts comment.body
end
```

### 4. Monitoring
```ruby
# Check classification accuracy
rake ai:stats

# Review generated insights
AiInsight.order(created_at: :desc).each do |insight|
  puts insight.title
  puts insight.metadata[:comment_count]
end
```

## Testing in Development

### 1. Test với seed data
```bash
# Load seed comments
rails db:seed

# Classify them
rake ai:classify_all
```

### 2. Test với 1 comment
```ruby
rails console

comment = Comment.create!(
  pull_request: PullRequest.first,
  body: "This code has a SQL injection vulnerability. Use parameterized queries.",
  author_name: "security_reviewer",
  author_role: "reviewer"
)

classifier = Ai::CommentClassifier.new
classifier.classify(comment)

comment.reload.tags.pluck(:name)
# => ["security"]
```

### 3. Test insight generation
```ruby
# Generate test insight
generator = Ai::InsightGenerator.new
insight = generator.generate_weekly_insights(days: 30)

puts insight.content
```

## Troubleshooting

### "API key not set"
```bash
# Check .env file
cat .env | grep API_KEY

# Restart Rails after updating .env
```

### "Rate limit exceeded"
Jobs sẽ tự động retry. Check Sidekiq logs:
```bash
tail -f log/sidekiq.log
```

### "No categories identified"
Normal behavior - không phải tất cả comments đều cần tags. Check comment content:
```ruby
Comment.analyzed.left_joins(:comment_tags)
       .where(comment_tags: { id: nil })
       .pluck(:body)
```

### "Classification failed"
Check Gemini API key và quota:
```bash
rake ai:test
```

## Integration with UI

Insights sẽ được hiển thị trong dashboard (upcoming):
```ruby
# Controller
@latest_insight = AiInsight.order(created_at: :desc).first
@tag_distribution = @latest_insight.metadata[:tag_distribution]

# View
<%= markdown @latest_insight.content %>
```

## Future Enhancements

- [ ] Sentiment analysis for reviewer tone
- [ ] Code snippet extraction and indexing
- [ ] Reviewer expertise tracking
- [ ] Automated response suggestions
- [ ] Multi-language support for comments
- [ ] Custom category training
- [ ] Real-time classification (webhook)
- [ ] Slack/Teams notifications for insights

## Resources

- [Gemini API Docs](https://ai.google.dev/docs)
- [OpenAI API Docs](https://platform.openai.com/docs)
- [Gemini Ruby Gem](https://github.com/gbaptista/gemini-ai)
- [OpenAI Ruby Gem](https://github.com/alexrudall/ruby-openai)
