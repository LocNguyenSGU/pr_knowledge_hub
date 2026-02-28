class Sync::BaseController < ApplicationController
  before_action :authenticate_user!
  skip_before_action :verify_authenticity_token, only: [ :pull_requests, :comments, :analyze ]

  def pull_requests
    SyncPullRequestsJob.perform_later(params[:state] || "open")

    render json: {
      status: "queued",
      message: "Pull requests sync job has been queued",
      job: "SyncPullRequestsJob"
    }
  end

  def comments
    pr_number = params[:pr_number]

    if pr_number
      # Sync comments for specific PR
      pr = PullRequest.find_by(number: pr_number)

      if pr
        Github::CommentFetcher.new(ENV["GITHUB_REPOSITORY"], pr_number.to_i).fetch
        render json: { status: "success", message: "Comments synced for PR ##{pr_number}" }
      else
        render json: { status: "error", message: "PR ##{pr_number} not found" }, status: :not_found
      end
    else
      # Sync comments for recent PRs
      SyncPullRequestsJob.perform_later("open")
      render json: { status: "queued", message: "Comments sync job has been queued" }
    end
  end

  def analyze
    AnalyzeCommentsJob.perform_later

    render json: {
      status: "queued",
      message: "Comment analysis job has been queued",
      job: "AnalyzeCommentsJob"
    }
  end

  def status
    require "sidekiq/api"

    stats = Sidekiq::Stats.new
    queues = Sidekiq::Queue.all.map do |queue|
      { name: queue.name, size: queue.size }
    end

    scheduled_jobs = Sidekiq::Cron::Job.all.map do |job|
      {
        name: job.name,
        enabled: job.enabled?,
        last_run: job.last_enqueue_time,
        status: job.status
      }
    end

    render json: {
      sidekiq: {
        processed: stats.processed,
        failed: stats.failed,
        enqueued: stats.enqueued,
        scheduled: stats.scheduled_size,
        retry: stats.retry_size,
        dead: stats.dead_size,
        workers: stats.workers_size
      },
      queues: queues,
      scheduled_jobs: scheduled_jobs,
      database: {
        total_prs: PullRequest.count,
        open_prs: PullRequest.open.count,
        total_comments: Comment.count,
        analyzed_comments: Comment.where(ai_analyzed: true).count,
        total_insights: AiInsight.count
      }
    }
  end
end
