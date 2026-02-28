require 'rails_helper'

RSpec.describe Ai::OpenaiClient do
  let(:openai_mock) { double('OpenAI::Client') }
  let(:client) { described_class.new }
  let!(:comment1) { create(:comment, body: "Consider using a constant for this magic number", ai_analyzed: true) }
  let!(:comment2) { create(:comment, body: "Good refactoring! The code is much cleaner now", ai_analyzed: true) }
  let(:comments) { Comment.where(id: [ comment1.id, comment2.id ]) }

  # Mock OpenAI response structure
  let(:mock_chat_response) do
    {
      "choices" => [
        {
          "message" => {
            "content" => "This week's code review highlights improvements in code quality..."
          }
        }
      ]
    }
  end

  let(:mock_lessons_response) do
    {
      "choices" => [
        {
          "message" => {
            "content" => '[{"title": "Use Constants", "description": "Magic numbers should be constants"}]'
          }
        }
      ]
    }
  end

  let(:mock_recommendations_response) do
    {
      "choices" => [
        {
          "message" => {
            "content" => '["Add unit tests for edge cases", "Use constants for magic numbers", "Document complex algorithms"]'
          }
        }
      ]
    }
  end

  before do
    allow(ENV).to receive(:fetch).with("OPENAI_API_KEY").and_return("test-api-key")
    allow(ENV).to receive(:fetch).with(anything, anything).and_call_original
    allow(OpenAI::Client).to receive(:new).and_return(openai_mock)
    allow(openai_mock).to receive(:chat).and_return(mock_chat_response)
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
        allow(openai_mock).to receive(:chat).and_raise(StandardError.new("API error"))
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
        allow(openai_mock).to receive(:chat).and_raise(StandardError.new("insufficient_quota"))
      end

      it 'returns quota exceeded message' do
        result = client.generate_insights_summary(comments)
        expect(result).to include("OpenAI API quota exceeded")
      end

      it 'logs quota error' do
        expect(Rails.logger).to receive(:error).at_least(:once)
        client.generate_insights_summary(comments)
      end
    end
  end

  describe '#extract_lessons', :vcr do
    before do
      allow(openai_mock).to receive(:chat).and_return(mock_lessons_response)
    end

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
        allow(openai_mock).to receive(:chat).and_return(
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
    let(:analysis) { { patterns: [ "Pattern 1" ], lessons: [ "Lesson 1" ] } }

    before do
      allow(openai_mock).to receive(:chat).and_return(mock_recommendations_response)
    end

    context 'with valid analysis' do
      it 'generates recommendations array' do
        result = client.generate_recommendations(analysis)

        expect(result).to be_an(Array)
        expect(result).not_to be_empty
      end

      it 'includes recommendation structure' do
        result = client.generate_recommendations(analysis)

        result.each do |rec|
          expect(rec).to be_a(String)
        end
      end
    end
  end

  describe 'private methods' do
    describe '#build_insights_prompt' do
      it 'builds a prompt with comments' do
        prompt = client.send(:build_insights_prompt, comments, "last week")

        expect(prompt).to include("last week")
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
