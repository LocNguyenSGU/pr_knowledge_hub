module Ai
  # Wrapper around OpenAI API
  # Used for generating insights and summaries
  class OpenaiClient
    def initialize
      @client = OpenAI::Client.new(access_token: ENV.fetch("OPENAI_API_KEY"))
    end

    # Generate a summary of code review insights
    # @param comments [Array<Comment>] Comments to summarize
    # @param time_period [String] Time period description (e.g., "last week")
    # @return [String] Generated summary
    def generate_insights_summary(comments, time_period: "recent")
      prompt = build_insights_prompt(comments, time_period)

      response = @client.chat(
        parameters: {
          model: "gpt-4o-mini",
          messages: [
            { role: "system", content: system_prompt },
            { role: "user", content: prompt }
          ],
          temperature: 0.7,
          max_tokens: 1000
        }
      )

      content = response.dig("choices", 0, "message", "content")

      Rails.logger.info "OpenAI generated insights summary (#{content&.length || 0} chars)"
      content

    rescue StandardError => e
      Rails.logger.error "OpenAI summary generation failed: #{e.message}"

      # Check if quota exceeded
      if e.message.include?("insufficient_quota")
        Rails.logger.error "❌ OpenAI quota exceeded. Please add credits at: https://platform.openai.com/settings/organization/billing"
        return "⚠️ OpenAI API quota exceeded. Please check billing settings."
      end

      "Failed to generate insights summary: #{e.message}"
    end

    # Extract key lessons from comments
    # @param comments [Array<Comment>] Comments to extract lessons from
    # @return [Array<Hash>] Array of lessons with title and description
    def extract_lessons(comments)
      prompt = build_lessons_prompt(comments)

      response = @client.chat(
        parameters: {
          model: "gpt-4o-mini",
          messages: [
            { role: "system", content: system_prompt },
            { role: "user", content: prompt }
          ],
          temperature: 0.7,
          max_tokens: 800
        }
      )

      content = response.dig("choices", 0, "message", "content")
      parse_lessons_response(content)

    rescue StandardError => e
      Rails.logger.error "OpenAI lesson extraction failed: #{e.message}"
      []
    end

    # Generate recommendations based on code review patterns
    # @param analysis [Hash] Analysis data from Gemini
    # @return [Array<String>] Array of recommendations
    def generate_recommendations(analysis)
      prompt = build_recommendations_prompt(analysis)

      response = @client.chat(
        parameters: {
          model: "gpt-4o-mini",
          messages: [
            { role: "system", content: system_prompt },
            { role: "user", content: prompt }
          ],
          temperature: 0.8,
          max_tokens: 600
        }
      )

      content = response.dig("choices", 0, "message", "content")
      parse_recommendations_response(content)

    rescue StandardError => e
      Rails.logger.error "OpenAI recommendation generation failed: #{e.message}"
      []
    end

    private

    def system_prompt
      <<~PROMPT.strip
        You are an expert software engineering coach analyzing code review data.
        Your goal is to help development teams improve their code quality and review process.
        Provide actionable, specific insights based on patterns in code review comments.
      PROMPT
    end

    def build_insights_prompt(comments, time_period)
      by_tag = comments.includes(:tags).group_by { |c| c.tags.pluck(:name) }

      summary = by_tag.map do |tags, comments_group|
        tag_names = tags.empty? ? "untagged" : tags.join(", ")
        "- #{tag_names}: #{comments_group.count} comments"
      end.join("\n")

      <<~PROMPT
        Analyze these code review statistics from #{time_period}:

        Total comments: #{comments.count}
        Breakdown by category:
        #{summary}

        Generate a concise executive summary (2-3 paragraphs) highlighting:
        1. Overall trends and patterns
        2. Areas of concern that need attention
        3. Positive practices observed

        Write in a professional but approachable tone.
      PROMPT
    end

    def build_lessons_prompt(comments)
      comment_samples = comments.includes(:tags).limit(20).map do |comment|
        tags = comment.tags.pluck(:name).join(", ")
        "- [#{tags}] #{comment.body.truncate(150)}"
      end.join("\n")

      <<~PROMPT
        Extract 3-5 key lessons learned from these code review comments:

        #{comment_samples}

        For each lesson, provide:
        1. A short title (5-8 words)
        2. A brief explanation (1-2 sentences)

        Format as JSON array:
        [
          {"title": "...", "description": "..."},
          ...
        ]
      PROMPT
    end

    def build_recommendations_prompt(analysis)
      <<~PROMPT
        Based on this code review analysis:

        Patterns: #{analysis[:patterns]&.join(', ')}
        Lessons: #{analysis[:lessons]&.join(', ')}

        Generate 3-5 specific, actionable recommendations to improve code quality and review effectiveness.
        Each recommendation should be a single sentence.

        Format as JSON array: ["recommendation 1", "recommendation 2", ...]
      PROMPT
    end

    def parse_lessons_response(content)
      # Extract JSON array from response
      json_match = content.match(/\[.*\]/m)
      return [] unless json_match

      JSON.parse(json_match[0], symbolize_names: true)

    rescue JSON::ParserError => e
      Rails.logger.error "Failed to parse lessons response: #{e.message}"
      []
    end

    def parse_recommendations_response(content)
      # Extract JSON array from response
      json_match = content.match(/\[.*\]/m)
      return [] unless json_match

      JSON.parse(json_match[0])

    rescue JSON::ParserError => e
      Rails.logger.error "Failed to parse recommendations response: #{e.message}"
      []
    end
  end
end
