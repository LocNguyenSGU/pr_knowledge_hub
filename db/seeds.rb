# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Create predefined tags for comment classification
Tag::CATEGORIES.each do |category|
  Tag.find_or_create_by!(name: category) do |tag|
    tag.category = category
    tag.description = "#{category.titleize} related comments"
    tag.color = case category
               when 'security' then '#EF4444'
               when 'performance' then '#F59E0B'
               when 'code_style' then '#3B82F6'
               when 'best_practice' then '#10B981'
               when 'bug' then '#DC2626'
               when 'refactoring' then '#8B5CF6'
               when 'testing' then '#14B8A6'
               when 'documentation' then '#6366F1'
               when 'question' then '#6B7280'
               else '#6B7280'
               end
  end
end

puts "Created #{Tag.count} tags"

# Create a sample PR for testing (optional)
if Rails.env.development?
  pr = PullRequest.find_or_create_by!(github_id: 1) do |pr|
    pr.number = 1
    pr.title = "Add user authentication"
    pr.body = "This PR adds user authentication using Devise gem."
    pr.state = "merged"
    pr.author_name = "john_doe"
    pr.author_avatar = "https://github.com/identicons/jasonlong.png"
    pr.repository_name = "example/repo"
    pr.repository_url = "https://github.com/example/repo/pull/1"
    pr.additions = 150
    pr.deletions = 20
    pr.changed_files_count = 8
    pr.draft = false
    pr.github_created_at = 3.days.ago
    pr.merged_at = 1.day.ago
  end

  # Create sample comments
  unless pr.comments.exists?(github_id: 101)
    comment1 = pr.comments.create!(
      github_id: 101,
      body: "Make sure to add input validation for the email field to prevent XSS attacks.",
      author_name: "jane_reviewer",
      author_avatar = "https://github.com/identicons/jane.png",
      author_role: "reviewer",
      comment_type: "review_comment",
      github_created_at: 2.days.ago
    )

    # Tag the security comment
    security_tag = Tag.find_by(name: 'security')
    comment1.tags << security_tag if security_tag
  end

  unless pr.comments.exists?(github_id: 102)
    pr.comments.create!(
      github_id: 102,
      body: "Good catch! I'll add email validation with regex.",
      author_name: "john_doe",
      author_avatar: "https://github.com/identicons/jasonlong.png",
      author_role: "author",
      comment_type: "issue_comment",
      github_created_at: 2.days.ago
    )
  end

  puts "Created sample PR with #{pr.comments.count} comments"
end

puts "Seed data completed!"
