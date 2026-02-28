module Github
  class SyncService
    attr_reader :repository_name, :client

    def initialize(repository_name = nil)
      @repository_name = repository_name || ENV["GITHUB_REPOSITORY"]
      @client = Github::Client.new

      raise ArgumentError, "Repository name is required" if @repository_name.blank?
    end

    # Sync everything: PRs and their comments
    def sync_all(state: "all", limit: nil)
      check_rate_limit!

      Rails.logger.info("Starting full sync for #{repository_name}")

      # Step 1: Sync Pull Requests
      prs = sync_pull_requests(state: state, limit: limit)

      # Step 2: Sync comments for each PR
      recent_prs = prs.sort_by(&:github_updated_at).reverse
      recent_prs = recent_prs.first(limit) if limit

      sync_comments_for_prs(recent_prs)

      Rails.logger.info("Sync completed: #{prs.size} PRs, #{Comment.count} total comments")

      {
        synced_prs: prs.size,
        total_comments: Comment.count,
        rate_limit_remaining: client.rate_limit.remaining
      }
    end

    # Sync only pull requests
    def sync_pull_requests(state: "all", limit: nil)
      fetcher = Github::PullRequestFetcher.new(repository_name, nil)
      prs = fetcher.fetch_all(state: state)

      prs = prs.first(limit) if limit

      Rails.logger.info("Synced #{prs.size} pull requests")
      prs
    end

    # Sync comments for specific PRs
    def sync_comments_for_prs(prs)
      prs.each do |pr|
        sync_comments_for_pr(pr)
      end
    end

    # Sync comments for a single PR
    def sync_comments_for_pr(pr)
      fetcher = Github::CommentFetcher.new(repository_name, pr.number)
      fetcher.fetch
    rescue => e
      Rails.logger.error("Failed to sync comments for PR ##{pr.number}: #{e.message}")
    end

    # Sync recent activity (last 7 days)
    def sync_recent(days: 7)
      cutoff_date = days.days.ago

      # Get recently updated PRs
      prs = PullRequest.where("github_updated_at > ?", cutoff_date)
                      .order(github_updated_at: :desc)

      Rails.logger.info("Syncing #{prs.count} recently updated PRs")

      prs.each do |pr|
        # Re-fetch PR data
        fetcher = Github::PullRequestFetcher.new(repository_name, pr.number)
        fetcher.fetch

        # Sync comments
        sync_comments_for_pr(pr)
      end
    end

    # Sync a specific PR and its comments
    def sync_pr(pr_number)
      check_rate_limit!

      Rails.logger.info("Syncing PR ##{pr_number}")

      # Fetch PR
      pr_fetcher = Github::PullRequestFetcher.new(repository_name, pr_number)
      pr = pr_fetcher.fetch

      return nil unless pr

      # Fetch comments
      comment_fetcher = Github::CommentFetcher.new(repository_name, pr_number)
      comments = comment_fetcher.fetch

      Rails.logger.info("Synced PR ##{pr_number}: #{comments.size} comments")

      { pr: pr, comments: comments }
    end

    # Get sync statistics
    def sync_stats
      {
        total_prs: PullRequest.count,
        open_prs: PullRequest.open.count,
        merged_prs: PullRequest.merged.count,
        total_comments: Comment.count,
        unanalyzed_comments: Comment.unanalyzed.count,
        rate_limit: {
          remaining: client.rate_limit.remaining,
          limit: client.rate_limit.limit,
          resets_at: client.rate_limit.resets_at
        }
      }
    end

    private

    def check_rate_limit!
      unless client.rate_limit_ok?(threshold: 100)
        raise Github::Client::RateLimitError,
              "Rate limit too low: #{client.rate_limit.remaining} remaining"
      end
    end
  end
end
