require 'rails_helper'

RSpec.describe Ai::InsightGenerator do
  let(:generator) { described_class.new }
  let(:gemini_client) { instance_double(Ai::GeminiClient) }
  let(:openai_client) { instance_double(Ai::OpenaiClient) }

  let(:pattern_analysis) do
    {
      patterns: [ "Pattern 1", "Pattern 2" ],
      lessons: [ "Lesson 1" ],
      recommendations: [ "Rec 1" ]
    }
  end

  before do
    allow(Ai::GeminiClient).to receive(:new).and_return(gemini_client)
    allow(Ai::OpenaiClient).to receive(:new).and_return(openai_client)

    allow(gemini_client).to receive(:analyze_patterns).and_return(pattern_analysis)
    allow(openai_client).to receive(:generate_insights_summary).and_return("Test summary")
    allow(openai_client).to receive(:extract_lessons).and_return([
      { title: "Lesson 1", description: "Description 1" }
    ])
    allow(openai_client).to receive(:generate_recommendations).and_return([
      { title: "Rec 1", description: "Description 1", priority: "high" }
    ])
  end

  describe '#initialize' do
    it 'creates AI clients' do
      expect(Ai::GeminiClient).to receive(:new)
      expect(Ai::OpenaiClient).to receive(:new)

      described_class.new
    end
  end

  describe '#generate_weekly_insights' do
    let!(:comment1) { create(:comment, body: "Security issue", created_at: 2.days.ago) }
    let!(:comment2) { create(:comment, body: "Performance problem", created_at: 3.days.ago) }
    let!(:old_comment) { create(:comment, body: "Old comment", created_at: 10.days.ago) }

    context 'with recent comments' do
      it 'generates insights' do
        result = generator.generate_weekly_insights(days: 7)

        expect(result).to be_a(AiInsight)
        expect(result.persisted?).to be true
      end

      it 'sets correct attributes' do
        result = generator.generate_weekly_insights(days: 7)

        expect(result.insight_type).to eq("pattern")
        expect(result.title).to include("Code Review Insights")
        expect(result.content).not_to be_empty
        expect(result.confidence_score).to eq(0.85)
        expect(result.ai_model).to eq("gemini-2.5-flash, gpt-4o-mini")
      end

      it 'includes related comments' do
        result = generator.generate_weekly_insights(days: 7)

        expect(result.related_comments).to include(comment1.id, comment2.id)
        expect(result.related_comments).not_to include(old_comment.id)
      end

      it 'calls AI services' do
        expect(gemini_client).to receive(:analyze_patterns)
        expect(openai_client).to receive(:generate_insights_summary)
        expect(openai_client).to receive(:extract_lessons)
        expect(openai_client).to receive(:generate_recommendations)

        generator.generate_weekly_insights(days: 7)
      end

      it 'logs insight creation' do
        expect(Rails.logger).to receive(:info).with(/Generating insights from/)
        expect(Rails.logger).to receive(:info).with(/Created AI insight/)

        generator.generate_weekly_insights(days: 7)
      end
    end

    context 'with no recent comments' do
      before do
        Comment.destroy_all
      end

      it 'returns nil' do
        result = generator.generate_weekly_insights(days: 7)
        expect(result).to be_nil
      end

      it 'logs warning' do
        expect(Rails.logger).to receive(:warn).with(/No comments found/)
        generator.generate_weekly_insights(days: 7)
      end

      it 'does not call AI services' do
        expect(gemini_client).not_to receive(:analyze_patterns)
        expect(openai_client).not_to receive(:generate_insights_summary)

        generator.generate_weekly_insights(days: 7)
      end
    end

    context 'when AI service fails' do
      before do
        create(:comment, created_at: 1.day.ago)
        allow(gemini_client).to receive(:analyze_patterns).and_raise(StandardError.new("API error"))
      end

      it 'returns nil' do
        result = generator.generate_weekly_insights(days: 7)
        expect(result).to be_nil
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with(/Failed to generate insights/)
        expect(Rails.logger).to receive(:error).with(include("API error"))

        generator.generate_weekly_insights(days: 7)
      end
    end

    context 'with custom days parameter' do
      let!(:recent_comment) { create(:comment, created_at: 10.days.ago) }

      it 'respects days parameter' do
        result = generator.generate_weekly_insights(days: 14)

        expect(result.related_comments).to include(recent_comment.id)
      end
    end
  end

  describe '#generate_tag_insights' do
    let(:security_tag) { create(:tag, name: 'security') }
    let!(:tagged_comment) { create(:comment, body: "Security issue", created_at: 5.days.ago).tap { |c| c.tags << security_tag } }
    let!(:untagged_comment) { create(:comment, body: "Other comment", created_at: 5.days.ago) }

    context 'with valid tag' do
      it 'generates tag-specific insights' do
        result = generator.generate_tag_insights('security', days: 30)

        expect(result).to be_a(AiInsight)
        expect(result.persisted?).to be true
      end

      it 'sets correct title with tag name' do
        result = generator.generate_tag_insights('security', days: 30)

        expect(result.title).to include("Security Insights")
      end

      it 'only includes tagged comments' do
        result = generator.generate_tag_insights('security', days: 30)

        expect(result.related_comments).to include(tagged_comment.id)
        expect(result.related_comments).not_to include(untagged_comment.id)
      end

      it 'logs generation' do
        expect(Rails.logger).to receive(:info).with(/Generating insights for 'security'/)
        generator.generate_tag_insights('security', days: 30)
      end
    end

    context 'with non-existent tag' do
      it 'returns nil' do
        result = generator.generate_tag_insights('nonexistent', days: 30)
        expect(result).to be_nil
      end
    end

    context 'with no comments for tag' do
      before do
        Comment.destroy_all
      end

      it 'returns nil' do
        result = generator.generate_tag_insights('security', days: 30)
        expect(result).to be_nil
      end

      it 'logs warning' do
        expect(Rails.logger).to receive(:warn).with(/No comments found for tag/)
        generator.generate_tag_insights('security', days: 30)
      end
    end
  end

  describe 'private methods' do
    describe '#build_insight_content' do
      let(:summary) { "Test summary" }
      let(:lessons) { [ { title: "Lesson 1", description: "Desc 1" } ] }
      let(:recommendations) { [ { title: "Rec 1", description: "Desc 1", priority: "high" } ] }

      it 'builds formatted content' do
        content = generator.send(:build_insight_content, summary, pattern_analysis, lessons, recommendations)

        expect(content).to be_a(String)
        expect(content).to include(summary)
      end

      it 'includes all sections' do
        content = generator.send(:build_insight_content, summary, pattern_analysis, lessons, recommendations)

        expect(content).to include("Summary")
        expect(content).to include("Patterns")
        expect(content).to include("Lessons")
        expect(content).to include("Recommendations")
      end

      it 'formats patterns' do
        content = generator.send(:build_insight_content, summary, pattern_analysis, lessons, recommendations)

        expect(content).to include("Pattern 1")
        expect(content).to include("Pattern 2")
      end

      it 'formats lessons with title and description' do
        content = generator.send(:build_insight_content, summary, pattern_analysis, lessons, recommendations)

        expect(content).to include("Lesson 1")
        expect(content).to include("Desc 1")
      end

      it 'formats recommendations with priority' do
        content = generator.send(:build_insight_content, summary, pattern_analysis, lessons, recommendations)

        expect(content).to include("Rec 1")
        expect(content).to include("high")
      end
    end

    describe '#calculate_tag_distribution' do
      let(:tag1) { create(:tag, name: 'security') }
      let(:tag2) { create(:tag, name: 'performance') }
      let!(:comment1) { create(:comment).tap { |c| c.tags << tag1 } }
      let!(:comment2) { create(:comment).tap { |c| c.tags << tag1 } }
      let!(:comment3) { create(:comment).tap { |c| c.tags << tag2 } }
      let(:comments) { Comment.all }

      it 'calculates tag distribution' do
        result = generator.send(:calculate_tag_distribution, comments)

        expect(result).to be_a(Hash)
        expect(result['security']).to eq(2)
        expect(result['performance']).to eq(1)
      end

      it 'handles comments without tags' do
        create(:comment) # No tags

        result = generator.send(:calculate_tag_distribution, Comment.all)

        expect(result).to be_a(Hash)
      end
    end
  end
end
