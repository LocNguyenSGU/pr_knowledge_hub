namespace :ai do
  desc "Test AI services configuration"
  task test: :environment do
    puts "\n=== Testing AI Services ==="

    # Check API keys
    puts "\n1. API Keys:"
    gemini_key = ENV["GEMINI_API_KEY"]
    openai_key = ENV["OPENAI_API_KEY"]

    puts "  Gemini API Key: #{gemini_key ? '✓ Set' : '✗ Missing'}"
    puts "  OpenAI API Key: #{openai_key ? '✓ Set' : '✗ Missing'}"

    if gemini_key.blank? || openai_key.blank?
      puts "\n⚠️  Please set API keys in .env file"
      exit 1
    end

    # Test Gemini client
    puts "\n2. Testing Gemini Client..."
    begin
      gemini = Ai::GeminiClient.new
      test_comment = "This code has a potential SQL injection vulnerability. Please use parameterized queries."
      categories = gemini.classify_comment(test_comment)

      if categories.any?
        puts "  ✓ Gemini working - classified as: #{categories.join(', ')}"
      else
        puts "  ⚠️  Gemini returned no categories (this may be normal for generic comments)"
        puts "  Suggestion: Try with a more specific technical comment"
      end
    rescue StandardError => e
      puts "  ✗ Gemini error: #{e.message}"
      puts "  Check your GEMINI_API_KEY and quota at: https://aistudio.google.com/app/apikey"
    end

    # Test OpenAI client
    puts "\n3. Testing OpenAI Client..."
    begin
      openai = Ai::OpenaiClient.new
      comments = Comment.limit(5)

      if comments.empty?
        puts "  ⚠️  No comments to test with - skipping"
      else
        summary = openai.generate_insights_summary(comments, time_period: "test")

        if summary && summary != "Failed to generate insights summary"
          puts "  ✓ OpenAI working - generated #{summary.length} chars"
        else
          puts "  ✗ OpenAI failed to generate summary"
        end
      end
    rescue OpenAI::Error => e
      puts "  ✗ OpenAI API error: #{e.message}"
      if e.message.include?("quota")
        puts "  💡 Your OpenAI account has no credits. Options:"
        puts "     1. Add payment method: https://platform.openai.com/account/billing"
        puts "     2. Use only Gemini (free): comment out OpenAI calls"
        puts "     3. Wait for free tier reset (if applicable)"
      end
    rescue StandardError => e
      puts "  ✗ OpenAI error: #{e.message}"
    end

    puts "\n=== Test Complete ==="
  end

  desc "Classify a single comment by ID"
  task :classify, [ :comment_id ] => :environment do |_t, args|
    comment_id = args[:comment_id]

    unless comment_id
      puts "Usage: rake ai:classify[123]"
      exit 1
    end

    comment = Comment.find_by(id: comment_id)

    unless comment
      puts "Comment ##{comment_id} not found"
      exit 1
    end

    puts "Classifying comment ##{comment.id}..."
    puts "Body: #{comment.body.truncate(100)}\n\n"

    classifier = Ai::CommentClassifier.new
    success = classifier.classify(comment)

    if success
      comment.reload
      puts "✓ Classified with tags: #{comment.tags.pluck(:name).join(', ')}"
    else
      puts "✗ Classification failed"
    end
  end

  desc "Classify all unanalyzed comments"
  task classify_all: :environment do
    unanalyzed = Comment.unanalyzed

    puts "Found #{unanalyzed.count} unanalyzed comments"

    if unanalyzed.empty?
      puts "Nothing to do!"
      exit 0
    end

    print "Proceed with classification? (y/n): "
    response = STDIN.gets.chomp.downcase

    exit 0 unless response == "y"

    classifier = Ai::CommentClassifier.new
    results = classifier.classify_batch(unanalyzed)

    puts "\n=== Results ==="
    puts "Success: #{results[:success]}"
    puts "Failed: #{results[:failed]}"
    puts "Skipped: #{results[:skipped]}"
  end

  desc "Generate insights for a time period"
  task :insights, [ :days ] => :environment do |_t, args|
    days = args[:days]&.to_i || 7

    puts "Generating insights for the last #{days} days..."

    generator = Ai::InsightGenerator.new
    insight = generator.generate_weekly_insights(days: days)

    if insight
      puts "\n✓ Generated insight ##{insight.id}"
      puts "Title: #{insight.title}"
      puts "Content length: #{insight.content.length} chars"
      puts "\nPreview:"
      puts insight.content.lines.first(10).join
    else
      puts "✗ Failed to generate insights"
    end
  end

  desc "Generate insights for a specific tag"
  task :tag_insights, [ :tag_name, :days ] => :environment do |_t, args|
    tag_name = args[:tag_name]
    days = args[:days]&.to_i || 30

    unless tag_name
      puts "Usage: rake ai:tag_insights[security,30]"
      exit 1
    end

    puts "Generating insights for '#{tag_name}' (last #{days} days)..."

    generator = Ai::InsightGenerator.new
    insight = generator.generate_tag_insights(tag_name, days: days)

    if insight
      puts "\n✓ Generated insight ##{insight.id}"
      puts "Title: #{insight.title}"
      puts "\nContent:"
      puts insight.content
    else
      puts "✗ Failed to generate insights"
    end
  end

  desc "Show AI usage statistics"
  task stats: :environment do
    puts "\n=== AI Statistics ==="

    total_comments = Comment.count
    analyzed = Comment.analyzed.count
    unanalyzed = Comment.unanalyzed.count

    puts "\nComments:"
    puts "  Total: #{total_comments}"
    puts "  Analyzed: #{analyzed} (#{(analyzed.to_f / total_comments * 100).round(1)}%)"
    puts "  Unanalyzed: #{unanalyzed}"

    puts "\nTags:"
    Comment.joins(:tags)
           .group("tags.name")
           .order("count_all DESC")
           .count
           .each do |tag_name, count|
      puts "  #{tag_name}: #{count}"
    end

    puts "\nInsights:"
    insights = AiInsight.all
    puts "  Total generated: #{insights.count}"

    if insights.any?
      latest = insights.order(created_at: :desc).first
      puts "  Latest: #{latest.title} (#{latest.created_at.strftime('%Y-%m-%d')})"
    end
  end
end
