require 'rails_helper'

RSpec.describe Ai::OpenaiClient do
  let(:client) { described_class.new }
  let(:comment1) { create(:comment, body: "Consider using a constant for this magic number", ai_analyzed: true) }
  let(:comment2) { create(:comment, body: "Good refactoring! The code is much cleaner now", ai_analyzed: true) }
  let(:comments) { [ comment1, comment2 ] }

  before do
    allow(ENV).to receive(:fetch).with("OPENAI_API_KEY").and_return("test-api-key")
  end

  describe '#initialize' do
    it 'creates an OpenAI client' do
      expect { client }.not_to raise_error
    end
  end

  describe '#generate_insights_summary', :vcr do
    context 'with valid comments' do
      it 'generates a summary' do
        result = client.generate_insights_summary(comments, time_period: "last week")

        expect(result).to be_a(String)
        expect(result).not_to be_empty
      end

      it 'logs the generation' do
        expect(Rails.logger).to receive(:info).with(/OpenAI generated insights summary/)
        client.generate_insights_summary(comments)
      end
    end

    context 'when API call fails' do
      before do
        allow_any_instance_of(OpenAI::Client).to receive(:chat).and_raise(StandardError.new("API error"))
      end

      it 'returns error message' do
        result = client.generate_insights_summary(comments)
        expect(result).to include("Failed to generate insights summary")
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with(/OpenAI summary generation failed/)
        client.generate_insights_summary(comments)
      end
    end

    context 'when quota is exceeded' do
      before do
        allow_any_instance_of(OpenAI::Client).to receive(:chat).and_raise(StandardError.new("insufficient_quota"))
      end

      it 'returns quota exceeded message' do
        result = client.generate_insights_summary(comments)
        expect(result).to include("OpenAI API quota exceeded")
      end

      it 'logs quota error' do
        expect(Rails.logger).to receive(:error).with(/quota exceeded/)
        client.generate_insights_summary(comments)
      end
    end
  end

  describe '#extract_lessons', :vcr do
    context 'with valid comments' do
      it 'extracts lessons as array' do
        result = client.extract_lessons(comments)

        expect(result).to be_an(Array)
        expect(result).not_to be_empty
      end

      it 'includes lesson structure' do
        result = client.extract_lessons(comments)

        result.each do |lesson|
          expect(lesson).to have_key(:title)
          expect(lesson).to have_key(:description)
          expect(lesson[:title]).to be_a(String)
          expect(lesson[:description]).to be_a(String)
        end
      end
    end

    context 'when parsing fails' do
      before do
        allow_any_instance_of(OpenAI::Client).to receive(:chat).and_return(
          { "choices" => [ { "message" => { "content" => "invalid json" } } ] }
        )
      end

      it 'returns empty array' do
        result = client.extract_lessons(comments)
        expect(result).to eq([])
      end
    end
  end

  describe '#generate_recommendations', :vcr do
    context 'with valid comments' do
      it 'generates recommendations array' do
        result = client.generate_recommendations(comments)

        expect(result).to be_an(Array)
        expect(result).not_to be_empty
      end

      it 'includes recommendation structure' do
        result = client.generate_recommendations(comments)

        result.each do |rec|
          expect(rec).to have_key(:title)
          expect(rec).to have_key(:description)
          expect(rec).to have_key(:priority)
        end
      end
    end
  end

  describe '#classify_comment', :vcr do
    it 'classifies a comment' do
      result = client.classify_comment(comment1.body)

      expect(result).to be_a(Hash)
      expect(result).to have_key(:category)
      expect(result).to have_key(:sentiment)
      expect(result).to have_key(:confidence)
    end

    it 'returns valid category' do
      result = client.classify_comment(comment1.body)

      valid_categories = %w[code_quality bug performance security style documentation question praise suggestion]
      expect(valid_categories).to include(result[:category])
    end

    it 'returns valid sentiment' do
      result = client.classify_comment(comment1.body)

      expect(%w[positive neutral negative constructive]).to include(result[:sentiment])
    end

    it 'returns confidence score' do
      result = client.classify_comment(comment1.body)

      expect(result[:confidence]).to be_a(Float)
      expect(result[:confidence]).to be_between(0.0, 1.0)
    end
  end

  describe 'private methods' do
    describe '#build_insights_prompt' do
      it 'builds a prompt with comments' do
        prompt = client.send(:build_insights_prompt, comments, "last week")

        expect(prompt).to include("last week")
        expect(prompt).to include(comment1.body)
        expect(prompt).to include(comment2.body)
      end
    end

    describe '#system_prompt' do
      it 'returns system prompt' do
        prompt = client.send(:system_prompt)

        expect(prompt).to be_a(String)
        expect(prompt).to include("code review")
      end
    end
  end
end
