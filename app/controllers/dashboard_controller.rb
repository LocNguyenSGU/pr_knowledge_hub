class DashboardController < ApplicationController
  def index
    @stats = calculate_stats
    @recent_prs = PullRequest.recent.limit(10)
    @recent_insights = AiInsight.order(created_at: :desc).limit(5)
    @top_tags = top_tags_with_counts
  end

  private

  def calculate_stats
    {
      total_prs: PullRequest.count,
      open_prs: PullRequest.open.count,
      merged_prs: PullRequest.merged.count,
      total_comments: Comment.count,
      analyzed_comments: Comment.where(ai_analyzed: true).count,
      total_insights: AiInsight.count,
      avg_comments_per_pr: (Comment.count.to_f / [ PullRequest.count, 1 ].max).round(1)
    }
  end

  def top_tags_with_counts
    Tag.joins(:comments)
       .select("tags.*, COUNT(comments.id) as comments_count")
       .group("tags.id")
       .order("comments_count DESC")
       .limit(10)
  end
end
