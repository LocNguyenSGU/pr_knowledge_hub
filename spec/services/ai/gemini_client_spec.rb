require 'rails_helper'

RSpec.describe Ai::GeminiClient do
  let(:client) { described_class.new }
  let(:comment1) { create(:comment, body: "This could lead to SQL injection", ai_analyzed: true) }
  let(:comment2) { create(:comment, body: "Consider caching this query", ai_analyzed: true) }
  let(:comments) { [ comment1, comment2 ] }

  before do
    allow(ENV).to receive(:fetch).with("GEMINI_API_KEY").and_return("test-api-key")
  end

  describe '#initialize' do
    it 'creates a Gemini client' do
      expect { client }.not_to raise_error
    end
  end

  describe '#classify_comment', :vcr do
    context 'with valid comment' do
      it 'classifies into categories' do
        result = client.classify_comment(comment1.body)

        expect(result).to be_an(Array)
      end

      it 'returns valid category names' do
        allow(client).to receive(:parse_classification_response).and_return([ "security" ])

        result = client.classify_comment(comment1.body)
        expect(result).to all(be_a(String))
      end

      it 'logs the classification' do
        allow(client).to receive(:parse_classification_response).and_return([ "security" ])

        expect(Rails.logger).to receive(:info).with(/Gemini classified comment/)
        client.classify_comment(comment1.body)
      end
    end

    context 'when API call fails' do
      before do
        allow_any_instance_of(Gemini).to receive(:stream_generate_content).and_raise(StandardError.new("API error"))
      end

      it 'returns empty array' do
        result = client.classify_comment(comment1.body)
        expect(result).to eq([])
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with(/Gemini classification failed/)
        client.classify_comment(comment1.body)
      end
    end
  end

  describe '#analyze_patterns', :vcr do
    before do
      # Create tags for testing
      security_tag = create(:tag, name: 'security')
      performance_tag = create(:tag, name: 'performance')
      comment1.tags << security_tag
      comment2.tags << performance_tag
    end

    context 'with valid comments' do
      it 'analyzes patterns' do
        result = client.analyze_patterns(comments)

        expect(result).to be_a(Hash)
        expect(result).to have_key(:patterns)
        expect(result).to have_key(:lessons)
        expect(result).to have_key(:recommendations)
      end

      it 'returns arrays for each key' do
        result = client.analyze_patterns(comments)

        expect(result[:patterns]).to be_an(Array)
        expect(result[:lessons]).to be_an(Array)
        expect(result[:recommendations]).to be_an(Array)
      end
    end

    context 'when analysis fails' do
      before do
        allow_any_instance_of(Gemini).to receive(:stream_generate_content).and_raise(StandardError.new("API error"))
      end

      it 'returns empty structure' do
        result = client.analyze_patterns(comments)

        expect(result).to eq({ patterns: [], lessons: [], recommendations: [] })
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with(/Gemini pattern analysis failed/)
        client.analyze_patterns(comments)
      end
    end
  end

  describe 'private methods' do
    describe '#build_classification_prompt' do
      it 'builds prompt with comment body' do
        prompt = client.send(:build_classification_prompt, comment1.body)

        expect(prompt).to include(comment1.body)
        expect(prompt).to include("code review")
      end

      it 'includes available categories' do
        prompt = client.send(:build_classification_prompt, comment1.body)

        expect(prompt).to include("security")
        expect(prompt).to include("performance")
      end
    end

    describe '#build_pattern_analysis_prompt' do
      before do
        tag = create(:tag, name: 'security')
        comment1.tags << tag
      end

      it 'builds prompt with comments' do
        prompt = client.send(:build_pattern_analysis_prompt, comments)

        expect(prompt).to be_a(String)
        expect(prompt).to include("pattern")
      end

      it 'includes comment summaries with tags' do
        prompt = client.send(:build_pattern_analysis_prompt, comments)

        expect(prompt).to include("[security]")
      end
    end

    describe '#parse_classification_response' do
      it 'parses valid JSON response' do
        response_text = '["security", "performance"]'
        allow(client).to receive(:extract_text_from_response).and_return(response_text)

        result = client.send(:parse_classification_response, {})

        expect(result).to eq([ "security", "performance" ])
      end

      it 'handles empty response' do
        allow(client).to receive(:extract_text_from_response).and_return("")

        result = client.send(:parse_classification_response, {})

        expect(result).to eq([])
      end

      it 'filters invalid categories' do
        response_text = '["security", "invalid_category", "performance"]'
        allow(client).to receive(:extract_text_from_response).and_return(response_text)

        result = client.send(:parse_classification_response, {})

        expect(result).to include("security", "performance")
        expect(result).not_to include("invalid_category")
      end
    end

    describe '#parse_pattern_response' do
      it 'parses valid JSON response' do
        response_json = {
          patterns: [ "Pattern 1" ],
          lessons: [ "Lesson 1" ],
          recommendations: [ "Rec 1" ]
        }.to_json

        allow(client).to receive(:extract_text_from_response).and_return(response_json)

        result = client.send(:parse_pattern_response, {})

        expect(result[:patterns]).to eq([ "Pattern 1" ])
        expect(result[:lessons]).to eq([ "Lesson 1" ])
        expect(result[:recommendations]).to eq([ "Rec 1" ])
      end

      it 'returns empty structure on parse error' do
        allow(client).to receive(:extract_text_from_response).and_return("invalid json")

        result = client.send(:parse_pattern_response, {})

        expect(result).to eq({ patterns: [], lessons: [], recommendations: [] })
      end
    end

    describe '#extract_text_from_response' do
      it 'extracts text from streaming response' do
        response = [
          { "candidates" => [ { "content" => { "parts" => [ { "text" => "part1" } ] } } ] },
          { "candidates" => [ { "content" => { "parts" => [ { "text" => "part2" } ] } } ] }
        ]

        result = client.send(:extract_text_from_response, response)

        expect(result).to eq("part1part2")
      end

      it 'handles empty response' do
        result = client.send(:extract_text_from_response, [])

        expect(result).to eq("")
      end
    end
  end
end
