require 'rails_helper'

RSpec.describe Github::PullRequestFetcher do
  let(:repository_name) { "owner/repo" }
  let(:pr_number) { 123 }
  let(:fetcher) { described_class.new(repository_name, pr_number) }
  let(:github_client) { instance_double(Github::Client) }

  let(:pr_data) do
    double(
      id: 12345,
      number: 123,
      title: "Test PR",
      body: "Test description",
      state: "open",
      user: double(login: "testuser", avatar_url: "https://example.com/avatar.png"),
      html_url: "https://github.com/owner/repo/pull/123",
      additions: 100,
      deletions: 50,
      changed_files: 5,
      mergeable_state: "clean",
      draft: false,
      created_at: 2.days.ago,
      updated_at: 1.day.ago,
      closed_at: nil,
      merged_at: nil
    )
  end

  before do
    allow(Github::Client).to receive(:new).and_return(github_client)
  end

  describe '#initialize' do
    it 'sets repository name' do
      expect(fetcher.repository_name).to eq(repository_name)
    end

    it 'sets PR number' do
      expect(fetcher.pr_number).to eq(pr_number)
    end

    it 'creates GitHub client' do
      expect(Github::Client).to receive(:new)
      described_class.new(repository_name, pr_number)
    end
  end

  describe '#fetch' do
    before do
      allow(github_client).to receive(:pull_request).and_return(pr_data)
    end

    context 'with valid PR data' do
      it 'fetches PR from GitHub' do
        expect(github_client).to receive(:pull_request).with(repository_name, pr_number)
        fetcher.fetch
      end

      it 'creates or updates PR in database' do
        expect { fetcher.fetch }.to change { PullRequest.count }.by(1)
      end

      it 'returns PR record' do
        result = fetcher.fetch
        expect(result).to be_a(PullRequest)
        expect(result.number).to eq(123)
      end

      it 'sets all attributes correctly' do
        pr = fetcher.fetch

        expect(pr.github_id).to eq(12345)
        expect(pr.title).to eq("Test PR")
        expect(pr.state).to eq("open")
        expect(pr.author_name).to eq("testuser")
        expect(pr.additions).to eq(100)
        expect(pr.deletions).to eq(50)
        expect(pr.changed_files_count).to eq(5)
      end

      it 'sets last_synced_at timestamp' do
        pr = fetcher.fetch
        expect(pr.last_synced_at).to be_present
        expect(pr.last_synced_at).to be_within(1.second).of(Time.current)
      end

      it 'logs sync' do
        expect(Rails.logger).to receive(:info).with(/Synced PR #123/)
        fetcher.fetch
      end
    end

    context 'when PR not found on GitHub' do
      before do
        allow(github_client).to receive(:pull_request).and_return(nil)
      end

      it 'returns nil' do
        result = fetcher.fetch
        expect(result).to be_nil
      end

      it 'does not create PR' do
        expect { fetcher.fetch }.not_to change { PullRequest.count }
      end
    end

    context 'when updating existing PR' do
      let!(:existing_pr) { create(:pull_request, github_id: 12345, title: "Old Title") }

      it 'updates existing record' do
        expect { fetcher.fetch }.not_to change { PullRequest.count }
      end

      it 'updates attributes' do
        fetcher.fetch
        existing_pr.reload
        expect(existing_pr.title).to eq("Test PR")
      end
    end

    context 'when merged PR' do
      let(:merged_pr_data) do
        double(
          id: pr_data.id,
          number: pr_data.number,
          title: pr_data.title,
          body: pr_data.body,
          state: "closed",
          user: pr_data.user,
          html_url: pr_data.html_url,
          additions: pr_data.additions,
          deletions: pr_data.deletions,
          changed_files: pr_data.changed_files,
          mergeable_state: pr_data.mergeable_state,
          draft: pr_data.draft,
          created_at: pr_data.created_at,
          updated_at: pr_data.updated_at,
          closed_at: pr_data.closed_at,
          merged_at: 1.day.ago
        )
      end

      before do
        allow(github_client).to receive(:pull_request).and_return(merged_pr_data)
      end

      it 'sets state to merged' do
        pr = fetcher.fetch
        expect(pr.state).to eq("merged")
      end
    end

    context 'when save fails' do
      before do
        allow_any_instance_of(PullRequest).to receive(:save).and_return(false)
        allow_any_instance_of(PullRequest).to receive(:errors).and_return(
          double(full_messages: [ "Title can't be blank" ])
        )
      end

      it 'returns nil' do
        result = fetcher.fetch
        expect(result).to be_nil
      end

      it 'logs error' do
        expect(Rails.logger).to receive(:error).with(/Failed to save/)
        fetcher.fetch
      end
    end
  end

  describe '#fetch_all' do
    let(:prs_data) { [ pr_data ] }

    before do
      allow(github_client).to receive(:pull_requests).and_return(prs_data)
    end

    it 'fetches all PRs from GitHub' do
      expect(github_client).to receive(:pull_requests).with(repository_name, state: "all")
      fetcher.fetch_all
    end

    it 'creates PRs in database' do
      expect { fetcher.fetch_all }.to change { PullRequest.count }.by(1)
    end

    it 'returns array of PRs' do
      result = fetcher.fetch_all
      expect(result).to be_an(Array)
      expect(result.first).to be_a(PullRequest)
    end

    context 'with custom state' do
      it 'passes state parameter' do
        expect(github_client).to receive(:pull_requests).with(repository_name, state: "open")
        fetcher.fetch_all(state: "open")
      end
    end

    context 'with multiple PRs' do
      let(:pr_data2) do
        double(
          id: 67890,
          number: 124,
          title: "Another PR",
          body: "Second PR body",
          state: "open",
          user: double(login: "author2", avatar_url: "https://example.com/avatar2.png"),
          html_url: "https://github.com/owner/repo/pull/124",
          additions: 50,
          deletions: 25,
          changed_files: 3,
          mergeable_state: "clean",
          draft: false,
          created_at: 2.days.ago,
          updated_at: 1.day.ago,
          closed_at: nil,
          merged_at: nil
        )
      end
      let(:prs_data) { [ pr_data, pr_data2 ] }

      it 'creates all PRs' do
        expect { fetcher.fetch_all }.to change { PullRequest.count }.by(2)
      end
    end
  end

  describe 'private methods' do
    describe '#determine_state' do
      context 'when merged' do
        let(:merged_data) { double(merged_at: 1.day.ago, state: "closed") }

        it 'returns merged' do
          result = fetcher.send(:determine_state, merged_data)
          expect(result).to eq("merged")
        end
      end

      context 'when not merged' do
        let(:open_data) { double(merged_at: nil, state: "open") }

        it 'returns original state' do
          result = fetcher.send(:determine_state, open_data)
          expect(result).to eq("open")
        end
      end
    end
  end
end
