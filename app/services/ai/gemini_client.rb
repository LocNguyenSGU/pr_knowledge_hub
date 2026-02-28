module Ai
  # Wrapper around Gemini AI API
  # Used for comment classification and pattern detection
  class GeminiClient
    def initialize
      @client = Gemini.new(
        credentials: {
          service: "generative-language-api",
          api_key: ENV.fetch("GEMINI_API_KEY")
        },
        options: { model: "gemini-2.5-flash", server_sent_events: true }
      )
    end

    # Classify a comment into categories
    # @param comment_body [String] The comment text to classify
    # @return [Array<String>] Array of category names
    def classify_comment(comment_body)
      prompt = build_classification_prompt(comment_body)

      response = @client.stream_generate_content({
        contents: { role: "user", parts: { text: prompt } }
      })

      categories = parse_classification_response(response)

      Rails.logger.info "Gemini classified comment into: #{categories.join(', ')}"
      categories

    rescue StandardError => e
      Rails.logger.error "Gemini classification failed: #{e.message}"
      []
    end

    # Analyze multiple comments to find patterns
    # @param comments [Array<Comment>] Comments to analyze
    # @return [Hash] Analysis results with patterns and insights
    def analyze_patterns(comments)
      prompt = build_pattern_analysis_prompt(comments)

      response = @client.stream_generate_content({
        contents: { role: "user", parts: { text: prompt } }
      })

      parse_pattern_response(response)

    rescue StandardError => e
      Rails.logger.error "Gemini pattern analysis failed: #{e.message}"
      { patterns: [], lessons: [], recommendations: [] }
    end

    private

    def build_classification_prompt(comment_body)
      categories = Tag::CATEGORIES.join(", ")

      <<~PROMPT
        You are a code review expert. Analyze this code review comment and classify it into one or more categories.

        Available categories: #{categories}

        Comment:
        "#{comment_body}"

        Return ONLY a JSON array of category names that apply. Example: ["security", "performance"]
        If no categories fit, return an empty array: []

        Response (JSON only):
      PROMPT
    end

    def build_pattern_analysis_prompt(comments)
      comment_summaries = comments.map.with_index do |comment, i|
        tags = comment.tags.pluck(:name).join(", ")
        "#{i + 1}. [#{tags}] #{comment.body.truncate(200)}"
      end.join("\n")

      <<~PROMPT
        You are analyzing code review comments to identify patterns and lessons learned.

        Comments (#{comments.count} total):
        #{comment_summaries}

        Provide your analysis in JSON format with these keys:
        {
          "patterns": ["pattern 1", "pattern 2", ...],
          "lessons": ["lesson 1", "lesson 2", ...],
          "recommendations": ["recommendation 1", "recommendation 2", ...]
        }

        Focus on:
        - Common issues that appear repeatedly
        - Best practices mentioned by reviewers
        - Areas where the team could improve

        Response (JSON only):
      PROMPT
    end

    def parse_classification_response(response)
      full_text = ""

      response.each do |event|
        next unless event.dig("candidates", 0, "content", "parts", 0, "text")
        full_text += event.dig("candidates", 0, "content", "parts", 0, "text")
      end

      Rails.logger.debug "Gemini raw response: #{full_text}"

      # Remove markdown code blocks if present
      cleaned_text = full_text.gsub(/```json\s*|\s*```/, "")

      # Extract JSON from response
      json_match = cleaned_text.match(/\[.*\]/m)

      unless json_match
        Rails.logger.warn "No JSON array found in Gemini response: #{full_text.truncate(200)}"
        return []
      end

      categories = JSON.parse(json_match[0])

      # Validate categories
      valid_categories = Tag::CATEGORIES
      validated = categories.select { |cat| valid_categories.include?(cat) }

      Rails.logger.debug "Validated categories: #{validated.inspect}"
      validated

    rescue JSON::ParserError => e
      Rails.logger.error "Failed to parse Gemini response: #{e.message}"
      Rails.logger.error "Response text: #{full_text.truncate(500)}"
      []
    end

    def parse_pattern_response(response)
      full_text = ""

      response.each do |event|
        next unless event.dig("candidates", 0, "content", "parts", 0, "text")
        full_text += event.dig("candidates", 0, "content", "parts", 0, "text")
      end

      # Remove markdown code blocks if present
      cleaned_text = full_text.gsub(/```json\s*|\s*```/, "")

      # Extract JSON from response
      json_match = cleaned_text.match(/\{.*\}/m)
      return { patterns: [], lessons: [], recommendations: [] } unless json_match

      JSON.parse(json_match[0], symbolize_names: true)

    rescue JSON::ParserError => e
      Rails.logger.error "Failed to parse Gemini pattern response: #{e.message}"
      { patterns: [], lessons: [], recommendations: [] }
    end
  end
end
