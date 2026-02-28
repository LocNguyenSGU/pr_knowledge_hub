require 'rails_helper'

RSpec.describe Github::SyncService do
  let(:repository_name) { "owner/repo" }
  let(:service) { described_class.new(repository_name) }
  let(:github_client) { instance_double(Github::Client) }
  let(:rate_limit) { double(remaining: 1000, resets_at: 1.hour.from_now) }

  let!(:pull_request) { create(:pull_request, number: 123, github_updated_at: 1.day.ago) }

  before do
    allow(Github::Client).to receive(:new).and_return(github_client)
    allow(github_client).to receive(:rate_limit).and_return(rate_limit)
    allow(github_client).to receive(:rate_limit_ok?).with(threshold: 100).and_return(true)
  end

  describe '#initialize' do
    it 'sets repository name from parameter' do
      expect(service.repository_name).to eq(repository_name)
    end

    it 'uses ENV variable if no parameter' do
      allow(ENV).to receive(:[]).with("GITHUB_REPOSITORY").and_return("env/repo")
      service = described_class.new

      expect(service.repository_name).to eq("env/repo")
    end

    it 'creates GitHub client' do
      expect(Github::Client).to receive(:new)
      described_class.new(repository_name)
    end

    context 'without repository name' do
      it 'raises ArgumentError' do
        allow(ENV).to receive(:[]).with("GITHUB_REPOSITORY").and_return(nil)

        expect {
          described_class.new
        }.to raise_error(ArgumentError, /Repository name is required/)
      end
    end
  end

  describe '#sync_all' do
    let(:pr_fetcher) { instance_double(Github::PullRequestFetcher) }
    let(:comment_fetcher) { instance_double(Github::CommentFetcher) }

    before do
      allow(Github::PullRequestFetcher).to receive(:new).and_return(pr_fetcher)
      allow(pr_fetcher).to receive(:fetch_all).and_return([ pull_request ])

      allow(Github::CommentFetcher).to receive(:new).and_return(comment_fetcher)
      allow(comment_fetcher).to receive(:fetch).and_return([])
    end

    it 'checks rate limit' do
      expect(service).to receive(:check_rate_limit!)
      service.sync_all
    end

    it 'syncs pull requests' do
      expect(service).to receive(:sync_pull_requests).and_call_original
      service.sync_all
    end

    it 'syncs comments for PRs' do
      expect(service).to receive(:sync_comments_for_prs)
      service.sync_all
    end

    it 'logs start and completion' do
      expect(Rails.logger).to receive(:info).with(/Starting full sync/).ordered
      expect(Rails.logger).to receive(:info).with(/Synced .* pull requests/).ordered
      expect(Rails.logger).to receive(:info).with(/Sync completed/).ordered

      service.sync_all
    end

    it 'returns sync stats' do
      result = service.sync_all

      expect(result).to be_a(Hash)
      expect(result).to have_key(:synced_prs)
      expect(result).to have_key(:total_comments)
      expect(result).to have_key(:rate_limit_remaining)
    end

    context 'with state parameter' do
      it 'passes state to sync_pull_requests' do
        expect(service).to receive(:sync_pull_requests).with(state: "open", limit: nil).and_return([ pull_request ])
        expect(service).to receive(:sync_comments_for_prs).and_return(nil)
        service.sync_all(state: "open")
      end
    end

    context 'with limit parameter' do
      let(:pr2) { create(:pull_request, number: 124, github_updated_at: 2.days.ago) }

      before do
        allow(pr_fetcher).to receive(:fetch_all).and_return([ pull_request, pr2 ])
      end

      it 'limits number of PRs to sync comments for' do
        expect(comment_fetcher).to receive(:fetch).once
        service.sync_all(limit: 1)
      end

      it 'syncs most recently updated PRs first' do
        expect(Github::CommentFetcher).to receive(:new).with(repository_name, pull_request.number)
        service.sync_all(limit: 1)
      end
    end
  end

  describe '#sync_pull_requests' do
    let(:pr_fetcher) { instance_double(Github::PullRequestFetcher) }
    let(:prs) { [ pull_request ] }

    before do
      allow(Github::PullRequestFetcher).to receive(:new).and_return(pr_fetcher)
      allow(pr_fetcher).to receive(:fetch_all).and_return(prs)
    end

    it 'creates PullRequestFetcher with repository name' do
      expect(Github::PullRequestFetcher).to receive(:new).with(repository_name, nil)
      service.sync_pull_requests
    end

    it 'fetches all PRs' do
      expect(pr_fetcher).to receive(:fetch_all).with(state: "all")
      service.sync_pull_requests
    end

    it 'returns array of PRs' do
      result = service.sync_pull_requests
      expect(result).to eq(prs)
    end

    it 'logs sync' do
      expect(Rails.logger).to receive(:info).with(/Synced 1 pull requests/)
      service.sync_pull_requests
    end

    context 'with custom state' do
      it 'passes state parameter' do
        expect(pr_fetcher).to receive(:fetch_all).with(state: "open")
        service.sync_pull_requests(state: "open")
      end
    end

    context 'with limit' do
      let(:pr2) { create(:pull_request, number: 124) }
      let(:prs) { [ pull_request, pr2 ] }

      it 'limits returned PRs' do
        result = service.sync_pull_requests(limit: 1)
        expect(result.size).to eq(1)
      end
    end
  end

  describe '#sync_comments_for_prs' do
    let(:pr2) { create(:pull_request, number: 124) }
    let(:prs) { [ pull_request, pr2 ] }

    it 'syncs comments for each PR' do
      expect(service).to receive(:sync_comments_for_pr).with(pull_request)
      expect(service).to receive(:sync_comments_for_pr).with(pr2)

      service.sync_comments_for_prs(prs)
    end
  end

  describe '#sync_comments_for_pr' do
    let(:comment_fetcher) { instance_double(Github::CommentFetcher) }

    before do
      allow(Github::CommentFetcher).to receive(:new).and_return(comment_fetcher)
      allow(comment_fetcher).to receive(:fetch).and_return([])
    end

    it 'creates CommentFetcher with PR number' do
      expect(Github::CommentFetcher).to receive(:new).with(repository_name, pull_request.number)
      service.sync_comments_for_pr(pull_request)
    end

    it 'fetches comments' do
      expect(comment_fetcher).to receive(:fetch)
      service.sync_comments_for_pr(pull_request)
    end

    context 'when fetch fails' do
      before do
        allow(comment_fetcher).to receive(:fetch).and_raise(StandardError.new("API error"))
      end

      it 'logs error' do
        expect(Rails.logger).to receive(:error).with(/Failed to sync comments/)
        service.sync_comments_for_pr(pull_request)
      end

      it 'does not raise error' do
        expect {
          service.sync_comments_for_pr(pull_request)
        }.not_to raise_error
      end
    end
  end

  describe '#sync_recent' do
    let!(:recent_pr) { create(:pull_request, number: 200, github_updated_at: 2.days.ago) }
    let!(:old_pr) { create(:pull_request, number: 201, github_updated_at: 10.days.ago) }
    let(:pr_fetcher) { instance_double(Github::PullRequestFetcher) }
    let(:comment_fetcher) { instance_double(Github::CommentFetcher) }

    before do
      allow(Github::PullRequestFetcher).to receive(:new).and_return(pr_fetcher)
      allow(pr_fetcher).to receive(:fetch).and_return(recent_pr)

      allow(Github::CommentFetcher).to receive(:new).and_return(comment_fetcher)
      allow(comment_fetcher).to receive(:fetch).and_return([])
    end

    it 'finds recently updated PRs' do
      # pull_request (1 day ago) and recent_pr (2 days ago) are both within 7 days
      expect(Rails.logger).to receive(:info).with(/Syncing 2 recently updated PRs/)
      service.sync_recent(days: 7)
    end

    it 'only syncs recent PRs' do
      expect(Github::PullRequestFetcher).to receive(:new).with(repository_name, recent_pr.number)
      expect(Github::PullRequestFetcher).not_to receive(:new).with(repository_name, old_pr.number)

      service.sync_recent(days: 7)
    end

    it 'refetches PR data' do
      expect(pr_fetcher).to receive(:fetch).at_least(:once)
      service.sync_recent(days: 7)
    end

    it 'syncs comments' do
      # Should sync comments for both pull_request and recent_pr
      expect(service).to receive(:sync_comments_for_pr).at_least(:once)
      service.sync_recent(days: 7)
    end

    context 'with custom days' do
      let!(:pr_5_days_ago) { create(:pull_request, number: 202, github_updated_at: 5.days.ago) }

      before do
        allow(pr_fetcher).to receive(:fetch).and_return(pr_5_days_ago)
      end

      it 'respects days parameter' do
        # pull_request (1 day ago) and recent_pr (2 days ago) are both within 3 days
        # pr_5_days_ago (5 days ago) is not
        expect(Rails.logger).to receive(:info).with(/Syncing 2 recently updated PRs/)
        service.sync_recent(days: 3)
      end
    end
  end

  describe 'private methods' do
    describe '#check_rate_limit!' do
      context 'when rate limit is OK' do
        it 'does not raise error' do
          expect { service.send(:check_rate_limit!) }.not_to raise_error
        end
      end

      context 'when rate limit is not OK' do
        let(:rate_limit) { double(remaining: 50, resets_at: 1.hour.from_now) }

        before do
          allow(github_client).to receive(:rate_limit_ok?).with(threshold: 100).and_return(false)
        end

        it 'raises error with remaining count' do
          expect {
            service.send(:check_rate_limit!)
          }.to raise_error(Github::Client::RateLimitError, /Rate limit too low: 50 remaining/)
        end
      end
    end
  end
end
