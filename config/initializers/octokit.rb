# Configure Octokit for GitHub API access
Octokit.configure do |c|
  c.access_token = ENV["GITHUB_ACCESS_TOKEN"]
  c.auto_paginate = true

  # Middleware configuration
  c.middleware = Faraday::RackBuilder.new do |builder|
    builder.use Faraday::Retry::Middleware, {
      max: 3,
      interval: 0.5,
      interval_randomness: 0.5,
      backoff_factor: 2,
      exceptions: [ Faraday::TimeoutError, Faraday::ConnectionFailed ]
    }
    builder.use Octokit::Middleware::FollowRedirects
    builder.use Octokit::Response::RaiseError
    builder.adapter Faraday.default_adapter
  end
end
