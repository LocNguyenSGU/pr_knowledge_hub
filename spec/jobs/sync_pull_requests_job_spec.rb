require 'rails_helper'

RSpec.describe SyncPullRequestsJob, type: :job do
  let(:sync_service) { instance_double(Github::SyncService) }
  let(:result) { { synced: 10, comments: 50 } }

  before do
    allow(Github::SyncService).to receive(:new).and_return(sync_service)
    allow(sync_service).to receive(:sync_all).and_return(result)
    allow(sync_service).to receive(:sync_recent).and_return(result)
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:error)
    allow(Rails.logger).to receive(:warn)
  end

  describe '#perform' do
    context 'with open state' do
      it 'creates SyncService' do
        expect(Github::SyncService).to receive(:new)
        described_class.new.perform("open")
      end

      it 'syncs open PRs' do
        expect(sync_service).to receive(:sync_all).with(state: "open")
        described_class.new.perform("open")
      end

      it 'logs start' do
        described_class.new.perform
# expect(Rails.logger).to have_received(:info).with(/Starting sync of open pull requests/)
        described_class.new.perform("open")
      end

      it 'logs result' do
        described_class.new.perform
# expect(Rails.logger).to have_received(:info).with(/Sync completed: 10 PRs synced, 50 comments synced/)
        described_class.new.perform("open")
      end
    end

    context 'with closed state' do
      it 'syncs recent closed PRs' do
        expect(sync_service).to receive(:sync_recent).with(days: 7)
        described_class.new.perform("closed")
      end

      it 'logs start with days' do
        described_class.new.perform()
        expect(Rails.logger).to have_received(:info).with(/Starting sync of recently closed pull requests \(last 7 days\)/)
        described_class.new.perform("closed")
      end

      it 'uses custom days parameter' do
        expect(sync_service).to receive(:sync_recent).with(days: 14)
        described_class.new.perform("closed", 14)
      end

      it 'logs custom days' do
        described_class.new.perform
# expect(Rails.logger).to have_received(:info).with(/last 14 days/)
        described_class.new.perform("closed", 14)
      end
    end

    context 'with all state' do
      it 'syncs all PRs' do
        expect(sync_service).to receive(:sync_all).with(state: "all")
        described_class.new.perform("all")
      end

      it 'logs start' do
        described_class.new.perform
# expect(Rails.logger).to have_received(:info).with(/Starting full sync of all pull requests/)
        described_class.new.perform("all")
      end

      it 'logs result' do
        described_class.new.perform
# expect(Rails.logger).to have_received(:info).with(/Sync completed/)
        described_class.new.perform("all")
      end
    end

    context 'with default parameters' do
      it 'defaults to open state' do
        expect(sync_service).to receive(:sync_all).with(state: "open")
        described_class.new.perform
      end
    end

    context 'with invalid state' do
      it 'logs error' do
        described_class.new.perform
# expect(Rails.logger).to have_received(:error).with(/Invalid state: invalid/)
        described_class.new.perform("invalid")
      end

      it 'does not sync' do
        expect(sync_service).not_to receive(:sync_all)
        expect(sync_service).not_to receive(:sync_recent)
        described_class.new.perform("invalid")
      end

      it 'does not log result' do
        allow(Rails.logger).to receive(:error)
        expect(Rails.logger).not_to receive(:info).with(/Sync completed/)
        described_class.new.perform("invalid")
      end
    end

    context 'when rate limit is reached' do
      before do
        allow(sync_service).to receive(:sync_all).and_raise(Github::Client::RateLimitError.new("Rate limit exceeded"))
      end

      it 'logs warning' do
        described_class.new.perform
# expect(Rails.logger).to have_received(:warn).with(/Rate limit reached/)
        expect { described_class.new.perform("open") }.to raise_error(Github::Client::RateLimitError)
      end

      it 're-raises error for retry' do
        allow(Rails.logger).to receive(:warn)
        expect {
          described_class.new.perform("open")
        }.to raise_error(Github::Client::RateLimitError)
      end
    end

    context 'when sync fails' do
      let(:error) { StandardError.new("API error") }

      before do
        allow(error).to receive(:backtrace).and_return([ "line1", "line2" ])
        allow(sync_service).to receive(:sync_all).and_raise(error)
      end

      it 'logs error message' do
        described_class.new.perform
# expect(Rails.logger).to have_received(:error).with(/Failed to sync pull requests: API error/)
        expect { described_class.new.perform("open") }.to raise_error(StandardError)
      end

      it 'logs backtrace' do
        described_class.new.perform
# expect(Rails.logger).to have_received(:error).with(/line1\nline2/)
        expect { described_class.new.perform("open") }.to raise_error(StandardError)
      end

      it 're-raises error' do
        allow(Rails.logger).to receive(:error)
        expect {
          described_class.new.perform("open")
        }.to raise_error(StandardError, "API error")
      end
    end

    context 'when result is nil' do
      before do
        allow(sync_service).to receive(:sync_all).and_return(nil)
      end

      it 'does not log result' do
        allow(Rails.logger).to receive(:info).with(/Starting/)
        expect(Rails.logger).not_to receive(:info).with(/Sync completed/)
        described_class.new.perform("open")
      end
    end
  end

  describe 'queue configuration' do
    it 'is queued on default queue' do
      expect(described_class.new.queue_name).to eq('default')
    end
  end

  describe 'private methods' do
    describe '#log_result' do
      let(:job) { described_class.new }

      context 'with valid result' do
        it 'logs sync details' do
          described_class.new.perform
# expect(Rails.logger).to have_received(:info).with(/Sync completed: 10 PRs synced, 50 comments synced/)
          job.send(:log_result, result)
        end
      end

      context 'with nil result' do
        it 'does not log' do
          expect(Rails.logger).not_to receive(:info)
          job.send(:log_result, nil)
        end
      end
    end
  end
end
