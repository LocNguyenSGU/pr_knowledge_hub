require 'rails_helper'

RSpec.describe Ai::CommentClassifier do
  let(:classifier) { described_class.new }
  let(:gemini_client) { instance_double(Ai::GeminiClient) }
  let(:comment) { create(:comment, body: "This is a security issue", ai_analyzed: false) }
  let(:security_tag) { create(:tag, name: 'security') }
  let(:performance_tag) { create(:tag, name: 'performance') }

  before do
    allow(Ai::GeminiClient).to receive(:new).and_return(gemini_client)
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:error)
  end

  describe '#initialize' do
    it 'creates a Gemini client' do
      expect(Ai::GeminiClient).to receive(:new)
      described_class.new
    end
  end

  describe '#classify' do
    context 'with valid comment' do
      before do
        security_tag # Ensure tag exists
        allow(gemini_client).to receive(:classify_comment).and_return([ 'security' ])
      end

      it 'classifies the comment' do
        result = classifier.classify(comment)

        expect(result).to be true
        expect(comment.ai_analyzed).to be true
      end

      it 'assigns tags to comment' do
        classifier.classify(comment)

        expect(comment.tags).to include(security_tag)
      end

      it 'logs the classification' do
        expect(Rails.logger).to receive(:info).with(/Classifying comment/)
        expect(Rails.logger).to receive(:info).with(/tagged with/)

        classifier.classify(comment)
      end
    end

    context 'when no categories identified' do
      before do
        allow(gemini_client).to receive(:classify_comment).and_return([])
      end

      it 'marks as analyzed' do
        classifier.classify(comment)

        expect(comment.ai_analyzed).to be true
      end

      it 'does not assign tags' do
        classifier.classify(comment)

        expect(comment.tags).to be_empty
      end

      it 'logs no categories' do
        expect(Rails.logger).to receive(:info).with(/No categories identified/)
        classifier.classify(comment)
      end
    end

    context 'when classification fails' do
      before do
        allow(gemini_client).to receive(:classify_comment).and_raise(StandardError.new("API error"))
      end

      it 'returns false' do
        result = classifier.classify(comment)
        expect(result).to be false
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with(/Failed to classify/)
        classifier.classify(comment)
      end
    end

    context 'with multiple categories' do
      before do
        security_tag
        performance_tag
        allow(gemini_client).to receive(:classify_comment).and_return([ 'security', 'performance' ])
      end

      it 'assigns all matching tags' do
        classifier.classify(comment)

        expect(comment.tags).to include(security_tag, performance_tag)
        expect(comment.tags.count).to eq(2)
      end
    end

    context 'when tag does not exist' do
      before do
        allow(gemini_client).to receive(:classify_comment).and_return([ 'nonexistent_tag' ])
      end

      it 'skips non-existent tags' do
        classifier.classify(comment)

        expect(comment.tags).to be_empty
      end

      it 'still marks as analyzed' do
        classifier.classify(comment)

        expect(comment.ai_analyzed).to be true
      end
    end
  end

  describe '#classify_batch' do
    let!(:comment1) { create(:comment, body: "Security issue", ai_analyzed: false) }
    let!(:comment2) { create(:comment, body: "Performance problem", ai_analyzed: false) }
    let!(:analyzed_comment) { create(:comment, body: "Already analyzed", ai_analyzed: true) }
    let(:comments) { Comment.where(id: [ comment1.id, comment2.id, analyzed_comment.id ]) }

    before do
      security_tag
      performance_tag
      allow(gemini_client).to receive(:classify_comment).with(comment1.body).and_return([ 'security' ])
      allow(gemini_client).to receive(:classify_comment).with(comment2.body).and_return([ 'performance' ])
      allow(classifier).to receive(:sleep) # Skip sleep in tests
    end

    it 'processes all unanalyzed comments' do
      result = classifier.classify_batch(comments)

      expect(result[:success]).to eq(2)
      expect(result[:skipped]).to eq(1)
      expect(result[:failed]).to eq(0)
    end

    it 'skips already analyzed comments' do
      classifier.classify_batch(comments)

      expect(analyzed_comment.reload.tags).to be_empty
    end

    it 'logs completion' do
      expect(Rails.logger).to receive(:info).with(/Batch classification complete/)
      classifier.classify_batch(comments)
    end

    context 'when some classifications fail' do
      before do
        allow(gemini_client).to receive(:classify_comment).with(comment2.body).and_raise(StandardError)
      end

      it 'continues processing' do
        result = classifier.classify_batch(comments)

        expect(result[:success]).to eq(1)
        expect(result[:failed]).to eq(1)
      end
    end

    it 'rate limits requests' do
      expect(classifier).to receive(:sleep).with(0.5).twice
      classifier.classify_batch(comments)
    end
  end

  describe '#reclassify_untagged' do
    let!(:tagged_comment) { create(:comment, ai_analyzed: true).tap { |c| c.tags << security_tag } }
    let!(:untagged_comment1) { create(:comment, ai_analyzed: true) }
    let!(:untagged_comment2) { create(:comment, ai_analyzed: true) }

    before do
      allow(gemini_client).to receive(:classify_comment).and_return([ 'security' ])
      allow(classifier).to receive(:sleep)
    end

    it 'finds untagged comments' do
      expect(Rails.logger).to receive(:info).with(/Re-classifying 2 untagged comments/)
      classifier.reclassify_untagged
    end

    it 'marks them as unanalyzed' do
      classifier.reclassify_untagged

      expect(untagged_comment1.reload.ai_analyzed).to be false
      expect(untagged_comment2.reload.ai_analyzed).to be false
    end

    it 'reclassifies them' do
      result = classifier.reclassify_untagged

      expect(result[:success]).to eq(2)
    end

    it 'respects limit parameter' do
      result = classifier.reclassify_untagged(limit: 1)

      expect(result[:success]).to eq(1)
    end

    it 'does not touch already tagged comments' do
      classifier.reclassify_untagged

      expect(tagged_comment.reload.ai_analyzed).to be true
    end
  end
end
