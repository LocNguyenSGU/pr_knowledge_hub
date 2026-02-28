namespace :github do
  desc "Sync pull requests and comments from GitHub"
  task sync: :environment do
    repository = ENV["GITHUB_REPOSITORY"]

    if repository.blank?
      puts "Error: GITHUB_REPOSITORY environment variable not set"
      puts "Usage: GITHUB_REPOSITORY=owner/repo rails github:sync"
      exit 1
    end

    puts "Syncing repository: #{repository}"
    puts "-" * 50

    begin
      service = Github::SyncService.new(repository)

      # Show rate limit before sync
      puts "Rate limit before: #{service.sync_stats[:rate_limit][:remaining]}/#{service.sync_stats[:rate_limit][:limit]}"

      # Sync all PRs (limit to 10 for testing)
      result = service.sync_all(state: "all", limit: 10)

      puts "\nSync completed!"
      puts "  - Synced PRs: #{result[:synced_prs]}"
      puts "  - Total comments: #{result[:total_comments]}"
      puts "  - Rate limit remaining: #{result[:rate_limit_remaining]}"

    rescue Github::Client::RateLimitError => e
      puts "Rate limit error: #{e.message}"
      exit 1
    rescue => e
      puts "Error: #{e.message}"
      puts e.backtrace.first(5).join("\n")
      exit 1
    end
  end

  desc "Sync a specific PR by number"
  task :sync_pr, [ :number ] => :environment do |t, args|
    repository = ENV["GITHUB_REPOSITORY"]
    pr_number = args[:number]&.to_i

    if repository.blank? || pr_number.nil?
      puts "Usage: GITHUB_REPOSITORY=owner/repo rails github:sync_pr[123]"
      exit 1
    end

    puts "Syncing PR ##{pr_number} from #{repository}"

    begin
      service = Github::SyncService.new(repository)
      result = service.sync_pr(pr_number)

      if result
        puts "Synced PR ##{result[:pr].number}: #{result[:pr].title}"
        puts "  - Comments: #{result[:comments].size}"
      else
        puts "PR not found"
      end
    rescue => e
      puts "Error: #{e.message}"
      exit 1
    end
  end

  desc "Show GitHub sync statistics"
  task stats: :environment do
    repository = ENV["GITHUB_REPOSITORY"]

    if repository.blank?
      puts "Error: GITHUB_REPOSITORY environment variable not set"
      exit 1
    end

    service = Github::SyncService.new(repository)
    stats = service.sync_stats

    puts "GitHub Sync Statistics"
    puts "=" * 50
    puts "Pull Requests:"
    puts "  - Total: #{stats[:total_prs]}"
    puts "  - Open: #{stats[:open_prs]}"
    puts "  - Merged: #{stats[:merged_prs]}"
    puts "\nComments:"
    puts "  - Total: #{stats[:total_comments]}"
    puts "  - Unanalyzed: #{stats[:unanalyzed_comments]}"
    puts "\nGitHub API Rate Limit:"
    puts "  - Remaining: #{stats[:rate_limit][:remaining]}/#{stats[:rate_limit][:limit]}"
    puts "  - Resets at: #{stats[:rate_limit][:resets_at]}"
  end
end
