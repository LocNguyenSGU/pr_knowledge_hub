require 'rails_helper'

RSpec.describe Github::CommentFetcher do
  let(:repository_name) { "owner/repo" }
  let(:pr_number) { 123 }
  let(:pull_request) { create(:pull_request, number: pr_number) }
  let(:fetcher) { described_class.new(repository_name, pr_number) }
  let(:github_client) { instance_double(Github::Client) }

  let(:comment_data) do
    double(
      id: 456,
      body: "Test comment",
      user: double(login: "reviewer", avatar_url: "https://example.com/avatar.png"),
      created_at: 1.day.ago,
      updated_at: 1.day.ago,
      path: nil,
      position: nil,
      line: nil,
      original_line: nil
    )
  end

  let(:review_comment_data) do
    double(
      id: 789,
      body: "Review comment",
      user: double(login: "reviewer2", avatar_url: "https://example.com/avatar2.png"),
      created_at: 1.day.ago,
      updated_at: 1.day.ago,
      path: "app/models/user.rb",
      position: 10,
      line: 42,
      original_line: 42
    )
  end

  let(:review_data) do
    double(
      id: 999,
      body: "LGTM! Great work",
      user: double(login: "approver", avatar_url: "https://example.com/avatar3.png"),
      created_at: 1.day.ago,
      updated_at: 1.day.ago
    )
  end

  before do
    pull_request # Force creation for tests that need it
    allow(Github::Client).to receive(:new).and_return(github_client)
    allow(github_client).to receive(:issue_comments).and_return([ comment_data ])
    allow(github_client).to receive(:review_comments).and_return([ review_comment_data ])
    allow(github_client).to receive(:reviews).and_return([ review_data ])
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

    it 'finds pull request' do
      expect(fetcher.pull_request).to eq(pull_request)
    end
  end

  describe '#fetch' do
    context 'with valid PR' do
      it 'fetches all 3 types of comments' do
        expect(github_client).to receive(:issue_comments)
        expect(github_client).to receive(:review_comments)
        expect(github_client).to receive(:reviews)

        fetcher.fetch
      end

      it 'creates comments in database' do
        expect { fetcher.fetch }.to change { Comment.count }.by(3)
      end

      it 'returns array of comments' do
        result = fetcher.fetch
        expect(result).to be_an(Array)
        expect(result.size).to eq(3)
      end

      it 'logs sync' do
        expect(Rails.logger).to receive(:info).with(/Synced 3 comments/)
        fetcher.fetch
      end
    end

    context 'when PR not found in database' do
      let(:pr_number) { 999 }

      before do
        # Don't create PR for this context
        allow(PullRequest).to receive(:find_by).with(number: 999).and_return(nil)
      end

      it 'returns empty array' do
        result = fetcher.fetch
        expect(result).to eq([])
      end

      it 'logs error' do
        expect(Rails.logger).to receive(:error).with(/not found in database/)
        fetcher.fetch
      end

      it 'does not create comments' do
        expect { fetcher.fetch }.not_to change { Comment.count }
      end
    end

    context 'with existing comments' do
      let!(:existing_comment) { create(:comment, github_id: 456, pull_request: pull_request, body: "Old body") }

      it 'updates existing comment' do
        expect { fetcher.fetch }.to change { Comment.count }.by(2) # Only 2 new ones
      end

      it 'updates body' do
        fetcher.fetch
        existing_comment.reload
        expect(existing_comment.body).to eq("Test comment")
      end
    end
  end

  describe 'private methods' do
    describe '#fetch_issue_comments' do
      it 'fetches issue comments from GitHub' do
        expect(github_client).to receive(:issue_comments).with(repository_name, pr_number)
        fetcher.send(:fetch_issue_comments)
      end

      it 'upserts comments with correct type' do
        comments = fetcher.send(:fetch_issue_comments)
        expect(comments.first.comment_type).to eq("issue_comment")
      end
    end

    describe '#fetch_review_comments' do
      it 'fetches review comments from GitHub' do
        expect(github_client).to receive(:review_comments).with(repository_name, pr_number)
        fetcher.send(:fetch_review_comments)
      end

      it 'upserts comments with correct type' do
        comments = fetcher.send(:fetch_review_comments)
        expect(comments.first.comment_type).to eq("review_comment")
      end

      it 'stores path and line information' do
        comments = fetcher.send(:fetch_review_comments)
        comment = comments.first

        expect(comment.path).to eq("app/models/user.rb")
        expect(comment.position).to eq(10)
        expect(comment.line).to eq(42)
      end
    end

    describe '#fetch_reviews' do
      it 'fetches reviews from GitHub' do
        expect(github_client).to receive(:reviews).with(repository_name, pr_number)
        fetcher.send(:fetch_reviews)
      end

      it 'only saves reviews with body' do
        empty_review = double(id: 888, body: "", user: review_data.user, created_at: 1.day.ago, updated_at: 1.day.ago)
        allow(github_client).to receive(:reviews).and_return([ review_data, empty_review ])

        comments = fetcher.send(:fetch_reviews)
        expect(comments.size).to eq(1)
      end

      it 'upserts comments with correct type' do
        comments = fetcher.send(:fetch_reviews)
        expect(comments.first.comment_type).to eq("review")
      end
    end

    describe '#upsert_comments' do
      let(:comments_data) { [ comment_data ] }

      it 'creates comments' do
        expect {
          fetcher.send(:upsert_comments, comments_data, "issue_comment")
        }.to change { Comment.count }.by(1)
      end

      it 'sets correct attributes' do
        comments = fetcher.send(:upsert_comments, comments_data, "issue_comment")
        comment = comments.first

        expect(comment.github_id).to eq(456)
        expect(comment.body).to eq("Test comment")
        expect(comment.author_name).to eq("reviewer")
        expect(comment.comment_type).to eq("issue_comment")
        expect(comment.pull_request).to eq(pull_request)
      end

      it 'skips comments with blank body' do
        blank_comment = double(comment_data.as_null_object, body: "")
        comments = fetcher.send(:upsert_comments, [ blank_comment ], "issue_comment")

        expect(comments).to be_empty
      end

      it 'logs debug message' do
        allow(Rails.logger).to receive(:debug).and_call_original
        expect(Rails.logger).to receive(:debug).with(/Synced comment/).at_least(:once).and_call_original
        fetcher.send(:upsert_comments, comments_data, "issue_comment")
      end

      context 'when save fails' do
        before do
          allow_any_instance_of(Comment).to receive(:save).and_return(false)
          allow_any_instance_of(Comment).to receive(:errors).and_return(
            double(full_messages: [ "Body can't be blank" ])
          )
        end

        it 'logs error' do
          expect(Rails.logger).to receive(:error).with(/Failed to save comment/)
          fetcher.send(:upsert_comments, comments_data, "issue_comment")
        end

        it 'returns empty array' do
          result = fetcher.send(:upsert_comments, comments_data, "issue_comment")
          expect(result).to be_empty
        end
      end
    end

    describe '#determine_author_role' do
      it 'returns author role' do
        allow(comment_data).to receive(:author_association).and_return("CONTRIBUTOR")
        role = fetcher.send(:determine_author_role, comment_data)

        expect(role).to eq("contributor")
      end

      it 'handles nil association' do
        allow(comment_data).to receive(:author_association).and_return(nil)
        role = fetcher.send(:determine_author_role, comment_data)

        expect(role).to eq("unknown")
      end
    end
  end
end
