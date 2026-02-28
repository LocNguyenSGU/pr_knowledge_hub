# Base class for all jobs in the application
class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  discard_on ActiveJob::DeserializationError

  # Retry on rate limit errors with exponential backoff
  retry_on Github::Client::RateLimitError, wait: :exponentially_longer, attempts: 5

  # Retry on Octokit errors with backoff
  retry_on Octokit::Error, wait: 5.minutes, attempts: 3
end
