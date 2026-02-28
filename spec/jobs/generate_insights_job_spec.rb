require 'rails_helper'

RSpec.describe GenerateInsightsJob, type: :job do
  let(:generator) { instance_double(Ai::InsightGenerator) }
  let(:insight) { create(:ai_insight, title: "Test Insights") }

  before do
    allow(Ai::InsightGenerator).to receive(:new).and_return(generator)
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:warn)
  end

  describe '#perform' do
    context 'when insight is generated successfully' do
      before do
        allow(generator).to receive(:generate_weekly_insights).and_return(insight)
      end

      it 'creates InsightGenerator' do
        expect(Ai::InsightGenerator).to receive(:new)
        described_class.new.perform
      end

      it 'generates weekly insights' do
        expect(generator).to receive(:generate_weekly_insights).with(days: 7)
        described_class.new.perform
      end

      it 'logs generation start' do
        described_class.new.perform
        expect(Rails.logger).to have_received(:info).with(/Generating AI insights/)
      end

      it 'logs success' do
        described_class.new.perform
        expect(Rails.logger).to have_received(:info).with(/Generated insight/)
      end

      it 'includes insight title in log' do
        described_class.new.perform
        expect(Rails.logger).to have_received(:info).with(/Test Insights/)
      end
    end

    context 'with custom days parameter' do
      before do
        allow(generator).to receive(:generate_weekly_insights).and_return(insight)
      end

      it 'passes days to generator' do
        expect(generator).to receive(:generate_weekly_insights).with(days: 14)
        described_class.new.perform(14)
      end

      it 'logs custom days' do
        described_class.new.perform(14)
        expect(Rails.logger).to have_received(:info).with(/last 14 days/)
      end
    end

    context 'when no insight is generated' do
      before do
        allow(generator).to receive(:generate_weekly_insights).and_return(nil)
      end

      it 'logs warning' do
        described_class.new.perform
        expect(Rails.logger).to have_received(:warn).with(/insufficient data or error occurred/)
      end

      it 'does not log success' do
        described_class.new.perform
        expect(Rails.logger).not_to have_received(:info).with(/Generated insight/)
      end
    end

    context 'when generator raises error' do
      before do
        allow(generator).to receive(:generate_weekly_insights).and_raise(StandardError.new("API error"))
      end

      it 'propagates the error' do
        expect {
          described_class.new.perform
        }.to raise_error(StandardError, "API error")
      end
    end
  end

  describe 'queue configuration' do
    it 'is queued on low priority queue' do
      expect(described_class.new.queue_name).to eq('low')
    end
  end
end
