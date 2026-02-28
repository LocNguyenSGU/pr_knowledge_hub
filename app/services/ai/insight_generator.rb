module Ai
  # Service to generate AI-powered insights from code review data
  class InsightGenerator
    def initialize
      @gemini = GeminiClient.new
      @openai = OpenaiClient.new
    end

    # Generate comprehensive weekly insights
    # @param days [Integer] Number of days to analyze (default: 7)
    # @return [AiInsight] Created insight record
    def generate_weekly_insights(days: 7)
      start_date = days.days.ago
      comments = Comment.where("created_at >= ?", start_date)
                        .includes(:tags, :pull_request)

      if comments.empty?
        Rails.logger.warn "No comments found in the last #{days} days"
        return nil
      end

      Rails.logger.info "Generating insights from #{comments.count} comments (last #{days} days)"

      # Step 1: Analyze patterns with Gemini
      pattern_analysis = @gemini.analyze_patterns(comments)

      # Step 2: Generate summary with OpenAI
      summary = @openai.generate_insights_summary(comments, time_period: "the last #{days} days")

      # Step 3: Extract lessons with OpenAI
      lessons = @openai.extract_lessons(comments)

      # Step 4: Generate recommendations
      recommendations = @openai.generate_recommendations(pattern_analysis)

      # Step 5: Create insight record
      insight = AiInsight.create!(
        title: "Code Review Insights - Week of #{Date.today.strftime('%B %d, %Y')}",
        insight_type: "pattern",
        content: build_insight_content(summary, pattern_analysis, lessons, recommendations),
        related_comments: comments.pluck(:id),
        confidence_score: 0.85,
        ai_model: "gemini-2.5-flash, gpt-4o-mini"
      )

      Rails.logger.info "Created AI insight ##{insight.id}"
      insight

    rescue StandardError => e
      Rails.logger.error "Failed to generate insights: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      nil
    end

    # Generate insights for a specific tag category
    # @param tag_name [String] Tag category to analyze
    # @param days [Integer] Number of days to analyze
    # @return [AiInsight] Created insight record
    def generate_tag_insights(tag_name, days: 30)
      tag = Tag.find_by(name: tag_name)
      return nil unless tag

      comments = Comment.joins(:tags)
                        .where(tags: { id: tag.id })
                        .where("comments.created_at >= ?", days.days.ago)
                        .includes(:pull_request)

      if comments.empty?
        Rails.logger.warn "No comments found for tag '#{tag_name}' in the last #{days} days"
        return nil
      end

      Rails.logger.info "Generating insights for '#{tag_name}' from #{comments.count} comments"

      # Analyze patterns specific to this tag
      pattern_analysis = @gemini.analyze_patterns(comments)
      summary = @openai.generate_insights_summary(comments, time_period: "the last #{days} days")

      insight = AiInsight.create!(
        title: "#{tag.display_name} Insights - #{Date.today.strftime('%B %Y')}",
        insight_type: "pattern",
        content: summary,
        related_comments: comments.pluck(:id),
        confidence_score: 0.85,
        ai_model: "gemini-2.5-flash, gpt-4o-mini"
      )

      Rails.logger.info "Created tag-specific insight ##{insight.id}"
      insight

    rescue StandardError => e
      Rails.logger.error "Failed to generate tag insights: #{e.message}"
      nil
    end

    private

    def build_insight_content(summary, patterns, lessons, recommendations)
      content = "# Executive Summary\n\n#{summary}\n\n"

      if patterns[:patterns]&.any?
        content += "## Patterns Identified\n\n"
        patterns[:patterns].each { |p| content += "- #{p}\n" }
        content += "\n"
      end

      if lessons.any?
        content += "## Key Lessons Learned\n\n"
        lessons.each do |lesson|
          content += "### #{lesson[:title]}\n#{lesson[:description]}\n\n"
        end
      end

      if recommendations.any?
        content += "## Recommendations\n\n"
        recommendations.each { |r| content += "- #{r}\n" }
      end

      content
    end

    def calculate_tag_distribution(comments)
      distribution = Hash.new(0)

      comments.includes(:tags).each do |comment|
        comment.tags.each do |tag|
          distribution[tag.name] += 1
        end
      end

      distribution.sort_by { |_, count| -count }.to_h
    end
  end
end
