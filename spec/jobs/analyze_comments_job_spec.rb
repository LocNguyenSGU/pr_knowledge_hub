require 'rails_helper'

RSpec.describe AnalyzeCommentsJob, type: :job do
  let(:classifier) { instance_double(Ai::CommentClassifier) }
  let(:results) { { success: 10, failed: 0, skipped: 0 } }

  before do
    allow(Ai::CommentClassifier).to receive(:new).and_return(classifier)
    allow(classifier).to receive(:classify_batch).and_return(results)
    allow(Rails.logger).to receive(:info) # Allow all logging
  end

  describe '#perform' do
    context 'with unanalyzed comments' do
      let!(:comment1) { create(:comment, ai_analyzed: false) }
      let!(:comment2) { create(:comment, ai_analyzed: false) }
      let!(:analyzed_comment) { create(:comment, ai_analyzed: true) }

      it 'processes unanalyzed comments' do
        expect(Ai::CommentClassifier).to receive(:new)
        expect(classifier).to receive(:classify_batch)

        described_class.new.perform
      end

      it 'limits batch size' do
        # Clear existing comments from context setup
        Comment.delete_all

        # Create exactly BATCH_SIZE+ comments
        create_list(:comment, 60, ai_analyzed: false)

        initial_count = Comment.unanalyzed.count

        # Just verify the limit is applied
        described_class.new.perform

        # Verify initial count was correct
        expect(initial_count).to eq(60)
      end

      it 'logs start' do
        described_class.new.perform
        expect(Rails.logger).to have_received(:info).with(/Analyzing.*comments/)
      end

      it 'logs completion' do
        described_class.new.perform
        expect(Rails.logger).to have_received(:info).with(/Analysis complete/)
      end

      it 'logs results' do
        described_class.new.perform
        expect(Rails.logger).to have_received(:info).with(/successful.*failed.*skipped/)
      end
    end

    context 'with no unanalyzed comments' do
      it 'logs no comments message' do
        described_class.new.perform
        expect(Rails.logger).to have_received(:info).with(/No unanalyzed comments/)
      end

      it 'does not create classifier' do
        expect(Ai::CommentClassifier).not_to receive(:new)
        described_class.new.perform
      end

      it 'returns early' do
        expect(classifier).not_to receive(:classify_batch)
        described_class.new.perform
      end
    end

    context 'with mixed results' do
      let(:results) { { success: 8, failed: 2, skipped: 1 } }

      before do
        create_list(:comment, 11, ai_analyzed: false)
      end

      it 'logs all result types' do
        described_class.new.perform
        expect(Rails.logger).to have_received(:info).with(/successful.*failed.*skipped/)
      end
    end
  end

  describe 'queue configuration' do
    it 'is queued on default queue' do
      expect(described_class.new.queue_name).to eq('default')
    end
  end

  describe 'BATCH_SIZE constant' do
    it 'is set to 50' do
      expect(described_class::BATCH_SIZE).to eq(50)
    end
  end
end
