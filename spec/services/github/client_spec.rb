require 'rails_helper'

RSpec.describe Github::Client do
  let(:client) { described_class.new }
  let(:octokit_client) { instance_double(Octokit::Client) }
  let(:rate_limit) { double(remaining: 1000, resets_at: 1.hour.from_now) }

  before do
    allow(ENV).to receive(:[]).with("GITHUB_ACCESS_TOKEN").and_return("test-token")
    allow(Octokit::Client).to receive(:new).and_return(octokit_client)
    allow(octokit_client).to receive(:auto_paginate=)
    allow(octokit_client).to receive(:rate_limit).and_return(rate_limit)
  end

  describe '#initialize' do
    it 'creates Octokit client with token' do
      expect(Octokit::Client).to receive(:new).with(access_token: "test-token")
      described_class.new
    end

    it 'enables auto pagination' do
      expect(octokit_client).to receive(:auto_paginate=).with(true)
      described_class.new
    end
  end

  describe '#rate_limit' do
    it 'returns rate limit info' do
      result = client.rate_limit
      expect(result.remaining).to eq(1000)
    end
  end

  describe '#rate_limit_ok?' do
    context 'when remaining requests above threshold' do
      it 'returns true with default threshold' do
        expect(client.rate_limit_ok?).to be true
      end

      it 'returns true with custom threshold' do
        expect(client.rate_limit_ok?(threshold: 500)).to be true
      end
    end

    context 'when remaining requests below threshold' do
      let(:rate_limit) { double(remaining: 50, resets_at: 1.hour.from_now) }

      it 'returns false' do
        expect(client.rate_limit_ok?).to be false
      end
    end
  end

  describe '#pull_requests' do
    let(:repo) { "owner/repo" }
    let(:pr_data) { [ { number: 1, title: "Test PR" } ] }

    before do
      allow(octokit_client).to receive(:pull_requests).and_return(pr_data)
    end

    it 'fetches pull requests' do
      expect(octokit_client).to receive(:pull_requests).with(
        repo,
        state: "all",
        sort: "updated",
        direction: "desc"
      )

      client.pull_requests(repo)
    end

    it 'returns PR data' do
      result = client.pull_requests(repo)
      expect(result).to eq(pr_data)
    end

    it 'checks rate limit' do
      expect(client).to receive(:check_rate_limit!)
      client.pull_requests(repo)
    end

    context 'with custom parameters' do
      it 'passes custom state' do
        expect(octokit_client).to receive(:pull_requests).with(
          repo,
          state: "open",
          sort: "updated",
          direction: "desc"
        )

        client.pull_requests(repo, state: "open")
      end
    end

    context 'when repository not found' do
      before do
        allow(octokit_client).to receive(:pull_requests).and_raise(Octokit::NotFound)
      end

      it 'returns empty array' do
        result = client.pull_requests(repo)
        expect(result).to eq([])
      end

      it 'logs error' do
        expect(Rails.logger).to receive(:error).with(/Repository not found/)
        client.pull_requests(repo)
      end
    end

    context 'when unauthorized' do
      before do
        allow(octokit_client).to receive(:pull_requests).and_raise(Octokit::Unauthorized)
      end

      it 'returns empty array' do
        result = client.pull_requests(repo)
        expect(result).to eq([])
      end

      it 'logs error' do
        expect(Rails.logger).to receive(:error).with(/authentication failed/)
        client.pull_requests(repo)
      end
    end
  end

  describe '#pull_request' do
    let(:repo) { "owner/repo" }
    let(:pr_number) { 123 }
    let(:pr_data) { { number: 123, title: "Test PR" } }

    before do
      allow(octokit_client).to receive(:pull_request).and_return(pr_data)
    end

    it 'fetches single PR' do
      expect(octokit_client).to receive(:pull_request).with(repo, pr_number)
      client.pull_request(repo, pr_number)
    end

    it 'returns PR data' do
      result = client.pull_request(repo, pr_number)
      expect(result).to eq(pr_data)
    end

    context 'when PR not found' do
      before do
        allow(octokit_client).to receive(:pull_request).and_raise(Octokit::NotFound)
      end

      it 'returns nil' do
        result = client.pull_request(repo, pr_number)
        expect(result).to be_nil
      end

      it 'logs error' do
        expect(Rails.logger).to receive(:error).with(/not found/)
        client.pull_request(repo, pr_number)
      end
    end
  end

  describe '#issue_comments' do
    let(:repo) { "owner/repo" }
    let(:number) { 123 }
    let(:comments) { [ { id: 1, body: "Test comment" } ] }

    before do
      allow(octokit_client).to receive(:issue_comments).and_return(comments)
    end

    it 'fetches issue comments' do
      expect(octokit_client).to receive(:issue_comments).with(repo, number)
      client.issue_comments(repo, number)
    end

    it 'returns comments' do
      result = client.issue_comments(repo, number)
      expect(result).to eq(comments)
    end

    context 'when not found' do
      before do
        allow(octokit_client).to receive(:issue_comments).and_raise(Octokit::NotFound)
      end

      it 'returns empty array' do
        result = client.issue_comments(repo, number)
        expect(result).to eq([])
      end
    end
  end

  describe '#review_comments' do
    let(:repo) { "owner/repo" }
    let(:number) { 123 }
    let(:comments) { [ { id: 1, body: "Review comment" } ] }

    before do
      allow(octokit_client).to receive(:pull_request_comments).and_return(comments)
    end

    it 'fetches review comments' do
      expect(octokit_client).to receive(:pull_request_comments).with(repo, number)
      client.review_comments(repo, number)
    end

    it 'returns comments' do
      result = client.review_comments(repo, number)
      expect(result).to eq(comments)
    end
  end

  describe '#reviews' do
    let(:repo) { "owner/repo" }
    let(:number) { 123 }
    let(:reviews) { [ { id: 1, state: "approved" } ] }

    before do
      allow(octokit_client).to receive(:pull_request_reviews).and_return(reviews)
    end

    it 'fetches reviews' do
      expect(octokit_client).to receive(:pull_request_reviews).with(repo, number)
      client.reviews(repo, number)
    end

    it 'returns reviews' do
      result = client.reviews(repo, number)
      expect(result).to eq(reviews)
    end
  end

  describe '#pull_request_files' do
    let(:repo) { "owner/repo" }
    let(:number) { 123 }
    let(:files) { [ { filename: "test.rb", additions: 10 } ] }

    before do
      allow(octokit_client).to receive(:pull_request_files).and_return(files)
    end

    it 'fetches PR files' do
      expect(octokit_client).to receive(:pull_request_files).with(repo, number)
      client.pull_request_files(repo, number)
    end

    it 'returns files' do
      result = client.pull_request_files(repo, number)
      expect(result).to eq(files)
    end
  end

  describe '#check_rate_limit!' do
    context 'when rate limit is OK' do
      it 'does not raise error' do
        expect { client.send(:check_rate_limit!) }.not_to raise_error
      end
    end

    context 'when rate limit is low but above 10' do
      let(:rate_limit) { double(remaining: 50, resets_at: 1.hour.from_now) }

      it 'logs warning' do
        expect(Rails.logger).to receive(:warn).with(/rate limit low/)
        client.send(:check_rate_limit!)
      end

      it 'does not raise error' do
        allow(Rails.logger).to receive(:warn)
        expect { client.send(:check_rate_limit!) }.not_to raise_error
      end
    end

    context 'when rate limit is critical' do
      let(:rate_limit) { double(remaining: 5, resets_at: 1.hour.from_now) }

      it 'raises RateLimitError' do
        expect { client.send(:check_rate_limit!) }.to raise_error(Github::Client::RateLimitError)
      end

      it 'logs warning before raising' do
        expect(Rails.logger).to receive(:warn)
        expect { client.send(:check_rate_limit!) }.to raise_error
      end
    end
  end
end
