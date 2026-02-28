module Github
  class Client
    class RateLimitError < StandardError; end

    attr_reader :client

    def initialize
      @client = Octokit::Client.new(access_token: ENV["GITHUB_ACCESS_TOKEN"])
      @client.auto_paginate = true
    end

    # Get rate limit information
    def rate_limit
      @client.rate_limit
    end

    # Check if we have enough remaining requests
    def rate_limit_ok?(threshold: 100)
      rate_limit.remaining > threshold
    end

    # Pull Requests
    def pull_requests(repo, state: "all", sort: "updated", direction: "desc")
      check_rate_limit!
      @client.pull_requests(repo, state: state, sort: sort, direction: direction)
    rescue Octokit::NotFound => e
      Rails.logger.error("Repository not found: #{repo} - #{e.message}")
      []
    rescue Octokit::Unauthorized => e
      Rails.logger.error("GitHub authentication failed: #{e.message}")
      []
    end

    def pull_request(repo, number)
      check_rate_limit!
      @client.pull_request(repo, number)
    rescue Octokit::NotFound => e
      Rails.logger.error("PR ##{number} not found in #{repo}: #{e.message}")
      nil
    end

    # Comments
    def issue_comments(repo, number)
      check_rate_limit!
      @client.issue_comments(repo, number)
    rescue Octokit::NotFound
      []
    end

    def review_comments(repo, number)
      check_rate_limit!
      @client.pull_request_comments(repo, number)
    rescue Octokit::NotFound
      []
    end

    def reviews(repo, number)
      check_rate_limit!
      @client.pull_request_reviews(repo, number)
    rescue Octokit::NotFound
      []
    end

    # Files changed in PR
    def pull_request_files(repo, number)
      check_rate_limit!
      @client.pull_request_files(repo, number)
    rescue Octokit::NotFound
      []
    end

    private

    def check_rate_limit!
      unless rate_limit_ok?
        remaining = rate_limit.remaining
        resets_at = rate_limit.resets_at
        error_msg = "GitHub API rate limit low (#{remaining} remaining). Resets at #{resets_at}"
        Rails.logger.warn(error_msg)
        raise RateLimitError, error_msg if remaining < 10
      end
    end
  end
end
