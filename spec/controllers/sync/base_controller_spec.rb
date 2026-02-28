require 'rails_helper'

RSpec.describe Sync::BaseController, type: :controller do
  routes { Rails.application.routes }

  # Skip authentication for these specs
  before do
    allow(controller).to receive(:authenticate_user!).and_return(true)
    allow(SyncPullRequestsJob).to receive(:perform_later)
    allow(AnalyzeCommentsJob).to receive(:perform_later)
  end

  describe "POST #pull_requests" do
    it "queues SyncPullRequestsJob with default state" do
      post :pull_requests, format: :json
      expect(SyncPullRequestsJob).to have_received(:perform_later).with("open")
    end

    it "queues SyncPullRequestsJob with custom state" do
      post :pull_requests, params: { state: "closed" }, format: :json
      expect(SyncPullRequestsJob).to have_received(:perform_later).with("closed")
    end

    it "returns success JSON response" do
      post :pull_requests, format: :json
      json = JSON.parse(response.body)
      expect(json['status']).to eq('queued')
      expect(json['message']).to eq('Pull requests sync job has been queued')
      expect(json['job']).to eq('SyncPullRequestsJob')
    end

    it "returns http success" do
      post :pull_requests, format: :json
      expect(response).to have_http_status(:success)
    end

    it "skips CSRF token verification" do
      allow(controller).to receive(:verify_authenticity_token)
      post :pull_requests, format: :json
      expect(controller).not_to have_received(:verify_authenticity_token)
    end
  end

  describe "POST #comments" do
    context "with pr_number parameter" do
      let!(:pull_request) { create(:pull_request, number: 123) }
      let(:comment_fetcher) { instance_double(Github::CommentFetcher, fetch: []) }

      before do
        allow(Github::CommentFetcher).to receive(:new).and_return(comment_fetcher)
        allow(comment_fetcher).to receive(:fetch).and_return([])
      end

      it "syncs comments for specific PR" do
        post :comments, params: { pr_number: 123 }, format: :json
        expect(Github::CommentFetcher).to have_received(:new).with(ENV["GITHUB_REPOSITORY"], 123)
        expect(comment_fetcher).to have_received(:fetch)
      end

      it "returns success JSON response" do
        post :comments, params: { pr_number: 123 }, format: :json
        json = JSON.parse(response.body)
        expect(json['status']).to eq('success')
        expect(json['message']).to eq('Comments synced for PR #123')
      end

      it "returns http success" do
        post :comments, params: { pr_number: 123 }, format: :json
        expect(response).to have_http_status(:success)
      end

      context "when PR not found" do
        it "returns error JSON response" do
          post :comments, params: { pr_number: 999 }, format: :json
          json = JSON.parse(response.body)
          expect(json['status']).to eq('error')
          expect(json['message']).to eq('PR #999 not found')
        end

        it "returns http not_found status" do
          post :comments, params: { pr_number: 999 }, format: :json
          expect(response).to have_http_status(:not_found)
        end

        it "does not call CommentFetcher" do
          post :comments, params: { pr_number: 999 }, format: :json
          expect(Github::CommentFetcher).not_to have_received(:new)
        end
      end
    end

    context "without pr_number parameter" do
      it "queues SyncPullRequestsJob" do
        post :comments, format: :json
        expect(SyncPullRequestsJob).to have_received(:perform_later).with("open")
      end

      it "returns queued JSON response" do
        post :comments, format: :json
        json = JSON.parse(response.body)
        expect(json['status']).to eq('queued')
        expect(json['message']).to eq('Comments sync job has been queued')
      end

      it "returns http success" do
        post :comments, format: :json
        expect(response).to have_http_status(:success)
      end
    end

    it "skips CSRF token verification" do
      allow(controller).to receive(:verify_authenticity_token)
      post :comments, format: :json
      expect(controller).not_to have_received(:verify_authenticity_token)
    end
  end

  describe "POST #analyze" do
    it "queues AnalyzeCommentsJob" do
      post :analyze, format: :json
      expect(AnalyzeCommentsJob).to have_received(:perform_later)
    end

    it "returns success JSON response" do
      post :analyze, format: :json
      json = JSON.parse(response.body)
      expect(json['status']).to eq('queued')
      expect(json['message']).to eq('Comment analysis job has been queued')
      expect(json['job']).to eq('AnalyzeCommentsJob')
    end

    it "returns http success" do
      post :analyze, format: :json
      expect(response).to have_http_status(:success)
    end

    it "skips CSRF token verification" do
      allow(controller).to receive(:verify_authenticity_token)
      post :analyze, format: :json
      expect(controller).not_to have_received(:verify_authenticity_token)
    end
  end

  describe "GET #status" do
    let(:sidekiq_stats) do
      double(Sidekiq::Stats,
        processed: 100,
        failed: 5,
        enqueued: 10,
        scheduled_size: 2,
        retry_size: 1,
        dead_size: 0,
        workers_size: 3
      )
    end

    let(:sidekiq_queue) do
      double(Sidekiq::Queue, name: 'default', size: 5)
    end

    let(:cron_job) do
      double(Sidekiq::Cron::Job,
        name: 'sync_prs',
        enabled?: true,
        last_enqueue_time: Time.current,
        status: 'enabled'
      )
    end

    before do
      stub_const('Sidekiq::Stats', Class.new)
      allow(Sidekiq::Stats).to receive(:new).and_return(sidekiq_stats)

      allow(Sidekiq::Queue).to receive(:all).and_return([ sidekiq_queue ])
      allow(Sidekiq::Cron::Job).to receive(:all).and_return([ cron_job ])

      # Clear any existing data from other tests
      PullRequest.delete_all
      Comment.delete_all
      AiInsight.delete_all

      @pr = create(:pull_request, state: 'open')
      @comment = create(:comment, ai_analyzed: true, pull_request: @pr)
      @insight = create(:ai_insight)
    end

    before { get :status, format: :json }

    it "returns http success" do
      expect(response).to have_http_status(:success)
    end

    it "includes Sidekiq stats" do
      json = JSON.parse(response.body)
      expect(json['sidekiq']).to be_a(Hash)
      expect(json['sidekiq']['processed']).to eq(100)
      expect(json['sidekiq']['failed']).to eq(5)
      expect(json['sidekiq']['enqueued']).to eq(10)
      expect(json['sidekiq']['scheduled']).to eq(2)
      expect(json['sidekiq']['retry']).to eq(1)
      expect(json['sidekiq']['dead']).to eq(0)
      expect(json['sidekiq']['workers']).to eq(3)
    end

    it "includes queue information" do
      json = JSON.parse(response.body)
      expect(json['queues']).to be_an(Array)
      expect(json['queues'].first['name']).to eq('default')
      expect(json['queues'].first['size']).to eq(5)
    end

    it "includes scheduled jobs information" do
      json = JSON.parse(response.body)
      expect(json['scheduled_jobs']).to be_an(Array)
      expect(json['scheduled_jobs'].first['name']).to eq('sync_prs')
      expect(json['scheduled_jobs'].first['enabled']).to be true
      expect(json['scheduled_jobs'].first).to have_key('last_run')
      expect(json['scheduled_jobs'].first['status']).to eq('enabled')
    end

    it "includes database statistics" do
      json = JSON.parse(response.body)
      expect(json['database']).to be_a(Hash)
      expect(json['database']['total_prs']).to eq(1)
      expect(json['database']['open_prs']).to eq(1)
      expect(json['database']['total_comments']).to eq(1)
      expect(json['database']['analyzed_comments']).to eq(1)
      expect(json['database']['total_insights']).to eq(1)
    end

    context "with empty database" do
      before do
        PullRequest.destroy_all
        Comment.destroy_all
        AiInsight.destroy_all
        get :status, format: :json
      end

      it "handles empty database gracefully" do
        json = JSON.parse(response.body)
        expect(json['database']['total_prs']).to eq(0)
        expect(json['database']['total_comments']).to eq(0)
      end
    end

    context "when Sidekiq is not available" do
      before do
        allow(Sidekiq::Stats).to receive(:new).and_raise(StandardError.new("Redis connection failed"))
      end

      it "handles error gracefully" do
        expect {
          get :status, format: :json
        }.to raise_error(StandardError)
      end
    end
  end
end
