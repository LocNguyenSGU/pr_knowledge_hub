namespace :sidekiq do
  desc "Show Sidekiq job statistics"
  task stats: :environment do
    require "sidekiq/api"

    stats = Sidekiq::Stats.new

    puts "\n=== Sidekiq Statistics ==="
    puts "Processed: #{stats.processed}"
    puts "Failed: #{stats.failed}"
    puts "Enqueued: #{stats.enqueued}"
    puts "Scheduled: #{stats.scheduled_size}"
    puts "Retry: #{stats.retry_size}"
    puts "Dead: #{stats.dead_size}"
    puts "Workers: #{stats.workers_size}"

    puts "\n=== Queue Stats ==="
    Sidekiq::Queue.all.each do |queue|
      puts "#{queue.name}: #{queue.size} jobs"
    end

    puts "\n=== Cron Jobs ==="
    Sidekiq::Cron::Job.all.each do |job|
      status = job.status
      last_run = job.last_enqueue_time

      puts "\n#{job.name}:"
      puts "  Status: #{status}"
      puts "  Schedule: #{job.cron}"
      puts "  Last run: #{last_run || 'Never'}"
      puts "  Enabled: #{job.enabled?}"
    end
  end

  desc "Clear all Sidekiq jobs"
  task clear: :environment do
    require "sidekiq/api"

    Sidekiq::Queue.all.each(&:clear)
    Sidekiq::RetrySet.new.clear
    Sidekiq::ScheduledSet.new.clear
    Sidekiq::DeadSet.new.clear

    puts "✓ All Sidekiq queues cleared"
  end

  desc "Enqueue a sync job for open PRs"
  task sync_open: :environment do
    SyncPullRequestsJob.perform_later("open")
    puts "✓ Enqueued sync job for open PRs"
  end

  desc "Enqueue a sync job for recently closed PRs"
  task sync_closed: :environment do
    SyncPullRequestsJob.perform_later("closed", 7)
    puts "✓ Enqueued sync job for recently closed PRs (last 7 days)"
  end

  desc "Enqueue analysis job for pending comments"
  task analyze: :environment do
    AnalyzeCommentsJob.perform_later
    puts "✓ Enqueued analysis job for pending comments"
  end

  desc "Enqueue insights generation job"
  task insights: :environment do
    GenerateInsightsJob.perform_later
    puts "✓ Enqueued insights generation job"
  end

  desc "Load cron jobs from schedule.yml"
  task load_schedule: :environment do
    schedule_file = Rails.root.join("config", "schedule.yml")

    if File.exist?(schedule_file)
      Sidekiq::Cron::Job.load_from_hash(YAML.load_file(schedule_file))
      puts "✓ Cron jobs loaded from schedule.yml"

      Sidekiq::Cron::Job.all.each do |job|
        puts "  - #{job.name} (#{job.cron})"
      end
    else
      puts "✗ schedule.yml not found"
    end
  end
end
