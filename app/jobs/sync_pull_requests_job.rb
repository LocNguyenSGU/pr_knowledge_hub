# Background job to sync pull requests from GitHub
# Can sync by state: 'open', 'closed', or 'all'
class SyncPullRequestsJob < ApplicationJob
  queue_as :default

  # @param state [String] PR state to sync: 'open', 'closed', or 'all'
  # @param days [Integer] For closed PRs, how many days back to sync (default: 7)
  def perform(state = "open", days = 7)
    service = Github::SyncService.new

    case state
    when "open"
      Rails.logger.info "Starting sync of open pull requests"
      result = service.sync_all(state: "open")
      log_result(result)

    when "closed"
      Rails.logger.info "Starting sync of recently closed pull requests (last #{days} days)"
      result = service.sync_recent(days: days)
      log_result(result)

    when "all"
      Rails.logger.info "Starting full sync of all pull requests"
      result = service.sync_all(state: "all")
      log_result(result)

    else
      Rails.logger.error "Invalid state: #{state}. Must be 'open', 'closed', or 'all'"
    end

  rescue Github::Client::RateLimitError => e
    Rails.logger.warn "Rate limit reached: #{e.message}. Will retry later."
    raise # Let retry mechanism handle it

  rescue StandardError => e
    Rails.logger.error "Failed to sync pull requests: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise
  end

  private

  def log_result(result)
    if result
      Rails.logger.info "Sync completed: #{result[:synced]} PRs synced, #{result[:comments]} comments synced"
    end
  end
end
