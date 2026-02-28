# PR Knowledge Hub - System Design

**Date:** February 28, 2026  
**Project:** Pull Request Knowledge Management System

## Overview

A Rails application that aggregates Pull Requests from GitHub and transforms code review comments into a searchable knowledge base using AI analysis. Designed for small teams (3-10 people) to capture and learn from reviewer insights.

## Requirements Summary

- **Source:** Single GitHub repository via GitHub API
- **Data:** Complete PR information including timeline, comments, reviews, code changes, and CI/CD status
- **Knowledge Management:** Tag/categorize comments, full-text search, AI-generated insights and patterns
- **Sync Strategy:** Polling scheduled jobs (every X minutes)
- **AI Services:** Google Gemini (classification) + OpenAI GPT (deep insights)
- **Users:** Small team with simple authentication
- **Tech Stack:** Rails 7+ with Hotwire/Turbo, Tailwind CSS, PostgreSQL

## Rails Setup Command

```bash
rails new pr_knowledge_hub \
  --database=postgresql \
  --css=tailwind \
  --javascript=importmap \
  --skip-jbuilder \
  --skip-action-mailer \
  --skip-action-mailbox \
  --skip-action-text \
  --skip-active-storage
```

### Additional Dependencies

```ruby
# Gemfile additions
gem 'octokit'              # GitHub API client
gem 'sidekiq'              # Background jobs
gem 'pg_search'            # PostgreSQL full-text search
gem 'devise'               # Authentication (simple)
gem 'ruby-openai'          # OpenAI API
gem 'gemini-ai'            # Google Gemini API
```

## Database Schema

### Pull Requests Table
```ruby
create_table :pull_requests do |t|
  t.bigint :github_id, null: false, index: { unique: true }
  t.integer :number, null: false
  t.string :title, null: false
  t.text :body
  t.string :state # open, closed, merged
  t.string :author_name
  t.string :author_avatar
  t.string :repository_name
  t.string :repository_url
  
  # Metrics
  t.integer :additions, default: 0
  t.integer :deletions, default: 0
  t.integer :changed_files_count, default: 0
  t.string :mergeable_state
  t.boolean :draft, default: false
  
  # Timestamps
  t.datetime :github_created_at
  t.datetime :github_updated_at
  t.datetime :closed_at
  t.datetime :merged_at
  t.datetime :last_synced_at
  
  t.timestamps
end

add_index :pull_requests, :state
add_index :pull_requests, :github_created_at
```

### Comments Table
```ruby
create_table :comments do |t|
  t.bigint :github_id, null: false, index: { unique: true }
  t.references :pull_request, null: false, foreign_key: true
  t.text :body, null: false
  t.string :author_name
  t.string :author_avatar
  t.string :author_role # author, reviewer, contributor
  t.string :comment_type # issue_comment, review_comment, review
  
  # For inline code comments
  t.string :path
  t.integer :position
  t.integer :line
  
  # AI Analysis
  t.boolean :ai_analyzed, default: false
  t.text :ai_summary
  
  t.datetime :github_created_at
  t.datetime :github_updated_at
  t.timestamps
end

add_index :comments, :pull_request_id
add_index :comments, :author_name
add_index :comments, :ai_analyzed
```

### Tags Table
```ruby
create_table :tags do |t|
  t.string :name, null: false, index: { unique: true }
  t.string :color, default: '#6B7280'
  t.text :description
  t.string :category # security, performance, code_style, etc.
  t.timestamps
end
```

### Comment Tags (Join Table)
```ruby
create_table :comment_tags do |t|
  t.references :comment, null: false, foreign_key: true
  t.references :tag, null: false, foreign_key: true
  t.timestamps
end

add_index :comment_tags, [:comment_id, :tag_id], unique: true
```

### AI Insights Table
```ruby
create_table :ai_insights do |t|
  t.string :insight_type # pattern, lesson, recommendation
  t.string :title, null: false
  t.text :content, null: false
  t.jsonb :related_comments, default: []
  t.float :confidence_score
  t.string :ai_model # openai-gpt4, gemini-pro
  t.timestamps
end

add_index :ai_insights, :insight_type
add_index :ai_insights, :created_at
```

### Full-Text Search Setup
```ruby
# In Comment model
include PgSearch::Model
pg_search_scope :search_content,
  against: [:body, :author_name],
  using: {
    tsearch: { prefix: true }
  }
```

## Architecture & Components

### Models & Associations

```ruby
# app/models/pull_request.rb
class PullRequest < ApplicationRecord
  has_many :comments, dependent: :destroy
  
  scope :open, -> { where(state: 'open') }
  scope :merged, -> { where(state: 'merged') }
  scope :recent, -> { order(github_created_at: :desc) }
  
  def reviewer_comments
    comments.where.not(author_role: 'author')
  end
end

# app/models/comment.rb
class Comment < ApplicationRecord
  belongs_to :pull_request
  has_many :comment_tags, dependent: :destroy
  has_many :tags, through: :comment_tags
  
  scope :by_reviewers, -> { where.not(author_role: 'author') }
  scope :unanalyzed, -> { where(ai_analyzed: false) }
  
  include PgSearch::Model
  pg_search_scope :search_content,
    against: [:body, :author_name],
    using: { tsearch: { prefix: true } }
end

# app/models/tag.rb
class Tag < ApplicationRecord
  has_many :comment_tags
  has_many :comments, through: :comment_tags
  
  CATEGORIES = %w[
    security performance code_style best_practice
    bug refactoring testing documentation question
  ].freeze
end

# app/models/ai_insight.rb
class AiInsight < ApplicationRecord
  scope :patterns, -> { where(insight_type: 'pattern') }
  scope :lessons, -> { where(insight_type: 'lesson') }
  scope :recent, -> { order(created_at: :desc) }
end
```

### Service Layer

```ruby
# app/services/github/client.rb
module Github
  class Client
    def initialize
      @client = Octokit::Client.new(access_token: ENV['GITHUB_ACCESS_TOKEN'])
      @client.auto_paginate = true
    end
    
    def rate_limit
      @client.rate_limit
    end
    
    def pull_requests(repo, state: 'all')
      @client.pull_requests(repo, state: state)
    end
    
    def pull_request(repo, number)
      @client.pull_request(repo, number)
    end
    
    def issue_comments(repo, number)
      @client.issue_comments(repo, number)
    end
    
    def review_comments(repo, number)
      @client.pull_request_comments(repo, number)
    end
    
    def reviews(repo, number)
      @client.pull_request_reviews(repo, number)
    end
  end
end

# app/services/github/sync_service.rb
module Github
  class SyncService
    def initialize(repository_name)
      @repository_name = repository_name
      @client = Github::Client.new
    end
    
    def sync_all
      check_rate_limit!
      
      sync_pull_requests
      sync_comments_for_recent_prs
    end
    
    private
    
    def sync_pull_requests
      prs = @client.pull_requests(@repository_name)
      
      prs.each do |pr_data|
        PullRequestFetcher.new(@repository_name, pr_data.number).fetch
      end
    end
    
    def sync_comments_for_recent_prs
      PullRequest.recent.limit(50).find_each do |pr|
        CommentFetcher.new(@repository_name, pr.number).fetch
      end
    end
    
    def check_rate_limit!
      limit = @client.rate_limit
      raise RateLimitError if limit.remaining < 100
    end
  end
end

# app/services/github/pull_request_fetcher.rb
module Github
  class PullRequestFetcher
    def initialize(repository_name, pr_number)
      @repository_name = repository_name
      @pr_number = pr_number
      @client = Github::Client.new
    end
    
    def fetch
      pr_data = @client.pull_request(@repository_name, @pr_number)
      
      PullRequest.upsert({
        github_id: pr_data.id,
        number: pr_data.number,
        title: pr_data.title,
        body: pr_data.body,
        state: pr_data.state,
        author_name: pr_data.user.login,
        author_avatar: pr_data.user.avatar_url,
        repository_name: @repository_name,
        repository_url: pr_data.html_url,
        additions: pr_data.additions,
        deletions: pr_data.deletions,
        changed_files_count: pr_data.changed_files,
        mergeable_state: pr_data.mergeable_state,
        draft: pr_data.draft,
        github_created_at: pr_data.created_at,
        github_updated_at: pr_data.updated_at,
        closed_at: pr_data.closed_at,
        merged_at: pr_data.merged_at,
        last_synced_at: Time.current
      }, unique_by: :github_id)
    end
  end
end

# app/services/github/comment_fetcher.rb
module Github
  class CommentFetcher
    def initialize(repository_name, pr_number)
      @repository_name = repository_name
      @pr_number = pr_number
      @client = Github::Client.new
    end
    
    def fetch
      pr = PullRequest.find_by!(number: @pr_number)
      
      # Fetch 3 types of comments
      fetch_issue_comments(pr)
      fetch_review_comments(pr)
      fetch_reviews(pr)
    end
    
    private
    
    def fetch_issue_comments(pr)
      comments = @client.issue_comments(@repository_name, @pr_number)
      upsert_comments(pr, comments, 'issue_comment')
    end
    
    def fetch_review_comments(pr)
      comments = @client.review_comments(@repository_name, @pr_number)
      upsert_comments(pr, comments, 'review_comment')
    end
    
    def fetch_reviews(pr)
      reviews = @client.reviews(@repository_name, @pr_number)
      upsert_comments(pr, reviews, 'review')
    end
    
    def upsert_comments(pr, comments, type)
      comments.each do |comment|
        next if comment.body.blank?
        
        Comment.upsert({
          github_id: comment.id,
          pull_request_id: pr.id,
          body: comment.body,
          author_name: comment.user.login,
          author_avatar: comment.user.avatar_url,
          author_role: determine_role(comment, pr),
          comment_type: type,
          path: comment.try(:path),
          position: comment.try(:position),
          line: comment.try(:line),
          github_created_at: comment.created_at,
          github_updated_at: comment.updated_at
        }, unique_by: :github_id)
      end
    end
    
    def determine_role(comment, pr)
      if comment.user.login == pr.author_name
        'author'
      else
        'reviewer'
      end
    end
  end
end
```

### AI Services

```ruby
# app/services/ai/comment_classifier.rb
module Ai
  class CommentClassifier
    CATEGORIES = Tag::CATEGORIES
    
    def initialize(ai_service: :gemini)
      @ai_service = ai_service
      @client = ai_service == :gemini ? GeminiClient.new : OpenaiClient.new
    end
    
    def classify_batch(comments)
      prompt = build_classification_prompt(comments)
      response = @client.complete(prompt)
      
      parse_and_apply_tags(response, comments)
    end
    
    private
    
    def build_classification_prompt(comments)
      comment_texts = comments.map.with_index do |comment, idx|
        "#{idx + 1}. #{comment.body}"
      end.join("\n\n")
      
      <<~PROMPT
        Analyze these code review comments and categorize each one.
        Categories: #{CATEGORIES.join(', ')}
        
        Comments:
        #{comment_texts}
        
        Return JSON array: [
          {"comment_number": 1, "categories": ["security", "best_practice"], "reasoning": "..."},
          ...
        ]
      PROMPT
    end
    
    def parse_and_apply_tags(response, comments)
      results = JSON.parse(response)
      
      results.each do |result|
        comment = comments[result['comment_number'] - 1]
        categories = result['categories']
        
        categories.each do |category|
          tag = Tag.find_or_create_by!(name: category, category: category)
          comment.tags << tag unless comment.tags.include?(tag)
        end
        
        comment.update!(
          ai_analyzed: true,
          ai_summary: result['reasoning']
        )
      end
    end
  end
end

# app/services/ai/insight_generator.rb
module Ai
  class InsightGenerator
    def initialize
      @client = OpenaiClient.new # Use GPT-4 for insights
    end
    
    def generate_weekly_insights
      generate_patterns
      generate_lessons
      generate_recommendations
    end
    
    private
    
    def generate_patterns
      Tag::CATEGORIES.each do |category|
        comments = Comment.joins(:tags)
                         .where(tags: { category: category })
                         .where('comments.created_at > ?', 1.week.ago)
                         .limit(50)
        
        next if comments.count < 5
        
        prompt = build_pattern_prompt(category, comments)
        content = @client.complete(prompt)
        
        AiInsight.create!(
          insight_type: 'pattern',
          title: "#{category.titleize} Patterns - Week #{Date.current.cweek}",
          content: content,
          related_comments: comments.pluck(:id),
          ai_model: 'openai-gpt4',
          confidence_score: calculate_confidence(comments)
        )
      end
    end
    
    def build_pattern_prompt(category, comments)
      comment_texts = comments.map { |c| "- #{c.body}" }.join("\n")
      
      <<~PROMPT
        You're analyzing code review comments about #{category}.
        Here are recent comments from a development team:
        
        #{comment_texts}
        
        Analyze and provide:
        1. Common patterns (what issues appear repeatedly)
        2. Severity assessment
        3. Root causes if identifiable
        
        Format as structured markdown with sections.
      PROMPT
    end
    
    def generate_lessons
      # Similar to patterns but focus on learning outcomes
    end
    
    def generate_recommendations
      # Similar but focus on actionable next steps
    end
    
    def calculate_confidence(comments)
      # Simple confidence based on sample size
      [comments.count / 10.0, 1.0].min
    end
  end
end

# app/services/ai/openai_client.rb
module Ai
  class OpenaiClient
    def initialize
      @client = OpenAI::Client.new(access_token: ENV['OPENAI_API_KEY'])
    end
    
    def complete(prompt, model: 'gpt-4')
      response = @client.chat(
        parameters: {
          model: model,
          messages: [{ role: 'user', content: prompt }],
          temperature: 0.3
        }
      )
      
      response.dig('choices', 0, 'message', 'content')
    end
  end
end

# app/services/ai/gemini_client.rb
module Ai
  class GeminiClient
    def initialize
      @client = Gemini.new(api_key: ENV['GEMINI_API_KEY'])
    end
    
    def complete(prompt, model: 'gemini-pro')
      response = @client.generate_content(
        model: model,
        contents: prompt
      )
      
      response['candidates'][0]['content']['parts'][0]['text']
    end
  end
end
```

### Background Jobs

```ruby
# app/jobs/sync_pull_requests_job.rb
class SyncPullRequestsJob < ApplicationJob
  queue_as :default
  
  def perform(repository_name)
    Github::SyncService.new(repository_name).sync_all
  rescue Github::RateLimitError => e
    # Retry in 1 hour
    self.class.set(wait: 1.hour).perform_later(repository_name)
  end
end

# config/sidekiq.yml
:schedule:
  sync_github_data:
    cron: '*/15 * * * *' # Every 15 minutes
    class: SyncPullRequestsJob
    args: ['owner/repo']

# app/jobs/analyze_comment_job.rb
class AnalyzeCommentJob < ApplicationJob
  queue_as :ai_analysis
  
  def perform(comment_id)
    comment = Comment.find(comment_id)
    Ai::CommentClassifier.new.classify_batch([comment])
  end
end

# app/jobs/generate_insights_job.rb
class GenerateInsightsJob < ApplicationJob
  queue_as :ai_analysis
  
  def perform
    Ai::InsightGenerator.new.generate_weekly_insights
  end
end

# config/sidekiq.yml (continued)
  generate_ai_insights:
    cron: '0 8 * * 1' # Every Monday at 8am
    class: GenerateInsightsJob
```

## Controllers & Routes

```ruby
# config/routes.rb
Rails.application.routes.draw do
  devise_for :users
  
  root 'dashboard#index'
  
  resources :pull_requests, only: [:index, :show] do
    resources :comments, only: [:index]
  end
  
  resources :insights, only: [:index, :show]
  
  namespace :api do
    post 'sync/trigger', to: 'sync#trigger'
  end
  
  get 'search', to: 'search#index'
end

# app/controllers/dashboard_controller.rb
class DashboardController < ApplicationController
  before_action :authenticate_user!
  
  def index
    @stats = {
      total_prs: PullRequest.count,
      open_prs: PullRequest.open.count,
      merged_this_week: PullRequest.merged.where('merged_at > ?', 1.week.ago).count,
      avg_review_time: calculate_avg_review_time
    }
    
    @recent_prs = PullRequest.recent.limit(20)
    @recent_insights = AiInsight.recent.limit(5)
  end
  
  private
  
  def calculate_avg_review_time
    # Time between PR created and merged
    PullRequest.merged
              .where.not(merged_at: nil)
              .where('merged_at > ?', 1.month.ago)
              .average('EXTRACT(EPOCH FROM (merged_at - github_created_at))')
              .to_i / 3600 # Convert to hours
  end
end

# app/controllers/pull_requests_controller.rb
class PullRequestsController < ApplicationController
  before_action :authenticate_user!
  
  def index
    @pull_requests = PullRequest.all
                                .then { |scope| filter_by_state(scope) }
                                .then { |scope| filter_by_author(scope) }
                                .then { |scope| filter_by_date(scope) }
                                .order(github_created_at: :desc)
                                .page(params[:page])
  end
  
  def show
    @pull_request = PullRequest.find(params[:id])
    @comments = @pull_request.comments
                             .includes(:tags)
                             .order(github_created_at: :asc)
    @related_insights = find_related_insights(@pull_request)
  end
  
  private
  
  def filter_by_state(scope)
    return scope unless params[:state].present?
    scope.where(state: params[:state])
  end
  
  def filter_by_author(scope)
    return scope unless params[:author].present?
    scope.where(author_name: params[:author])
  end
  
  def filter_by_date(scope)
    return scope unless params[:from].present?
    scope.where('github_created_at >= ?', params[:from])
  end
  
  def find_related_insights(pr)
    comment_ids = pr.comments.pluck(:id)
    AiInsight.where("related_comments && ARRAY[?]::bigint[]", comment_ids)
  end
end

# app/controllers/search_controller.rb
class SearchController < ApplicationController
  before_action :authenticate_user!
  
  def index
    @query = params[:q]
    
    if @query.present?
      @comments = Comment.search_content(@query)
                        .includes(:pull_request, :tags)
                        .page(params[:page])
    else
      @comments = Comment.none
    end
  end
end

# app/controllers/insights_controller.rb
class InsightsController < ApplicationController
  before_action :authenticate_user!
  
  def index
    @insights = AiInsight.order(created_at: :desc)
                        .then { |scope| filter_by_type(scope) }
                        .page(params[:page])
    
    @patterns = AiInsight.patterns.recent.limit(5)
    @lessons = AiInsight.lessons.recent.limit(5)
  end
  
  def show
    @insight = AiInsight.find(params[:id])
    @related_comments = Comment.where(id: @insight.related_comments)
  end
  
  private
  
  def filter_by_type(scope)
    return scope unless params[:type].present?
    scope.where(insight_type: params[:type])
  end
end
```

## Views & Hotwire Integration

### Dashboard Layout

```erb
<!-- app/views/layouts/application.html.erb -->
<!DOCTYPE html>
<html>
  <head>
    <title>PR Knowledge Hub</title>
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>
    <%= stylesheet_link_tag "tailwind", "inter-font", "data-turbo-track": "reload" %>
    <%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>
    <%= javascript_importmap_tags %>
  </head>

  <body class="bg-gray-50">
    <%= render 'shared/navbar' %>
    
    <main class="container mx-auto px-4 py-8">
      <%= render 'shared/flash' %>
      <%= yield %>
    </main>
  </body>
</html>

<!-- app/views/shared/_navbar.html.erb -->
<nav class="bg-white shadow-sm">
  <div class="container mx-auto px-4">
    <div class="flex justify-between items-center h-16">
      <div class="flex items-center">
        <h1 class="text-xl font-bold text-gray-800">🔍 PR Knowledge Hub</h1>
      </div>
      
      <div class="flex items-center space-x-4">
        <%= link_to 'Dashboard', root_path, class: 'text-gray-600 hover:text-gray-800' %>
        <%= link_to 'Pull Requests', pull_requests_path, class: 'text-gray-600 hover:text-gray-800' %>
        <%= link_to 'Insights', insights_path, class: 'text-gray-600 hover:text-gray-800' %>
        
        <%= button_to 'Sync Now', api_sync_trigger_path, 
            method: :post,
            class: 'px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600',
            data: { turbo_frame: 'sync_status' } %>
        
        <%= link_to 'Sign Out', destroy_user_session_path, 
            method: :delete,
            class: 'text-gray-600 hover:text-gray-800' %>
      </div>
    </div>
  </div>
</nav>
```

### Dashboard View

```erb
<!-- app/views/dashboard/index.html.erb -->
<div class="space-y-8">
  <!-- Stats Cards -->
  <%= turbo_frame_tag 'stats', class: 'grid grid-cols-1 md:grid-cols-4 gap-4' do %>
    <div class="bg-white p-6 rounded-lg shadow">
      <div class="text-sm text-gray-600">Total PRs</div>
      <div class="text-3xl font-bold text-gray-800"><%= @stats[:total_prs] %></div>
    </div>
    
    <div class="bg-white p-6 rounded-lg shadow">
      <div class="text-sm text-gray-600">Open PRs</div>
      <div class="text-3xl font-bold text-blue-600"><%= @stats[:open_prs] %></div>
    </div>
    
    <div class="bg-white p-6 rounded-lg shadow">
      <div class="text-sm text-gray-600">Merged This Week</div>
      <div class="text-3xl font-bold text-green-600"><%= @stats[:merged_this_week] %></div>
    </div>
    
    <div class="bg-white p-6 rounded-lg shadow">
      <div class="text-sm text-gray-600">Avg Review Time</div>
      <div class="text-3xl font-bold text-purple-600"><%= @stats[:avg_review_time] %>h</div>
    </div>
  <% end %>
  
  <!-- Recent PRs -->
  <div class="bg-white rounded-lg shadow">
    <div class="p-6 border-b">
      <h2 class="text-xl font-semibold">Recent Pull Requests</h2>
    </div>
    
    <%= turbo_frame_tag 'recent_prs' do %>
      <div class="divide-y">
        <% @recent_prs.each do |pr| %>
          <%= render 'pull_requests/pr_card', pr: pr %>
        <% end %>
      </div>
    <% end %>
  </div>
  
  <!-- AI Insights -->
  <div class="bg-white rounded-lg shadow" data-controller="collapsible">
    <div class="p-6 border-b flex justify-between items-center cursor-pointer" 
         data-action="click->collapsible#toggle">
      <h2 class="text-xl font-semibold">💡 AI Insights</h2>
      <svg class="w-5 h-5 transform transition-transform" data-collapsible-target="icon">
        <!-- chevron icon -->
      </svg>
    </div>
    
    <div class="p-6 space-y-4" data-collapsible-target="content">
      <% @recent_insights.each do |insight| %>
        <%= render 'insights/insight_card', insight: insight %>
      <% end %>
      
      <%= link_to 'View All Insights →', insights_path, 
          class: 'text-blue-600 hover:text-blue-800 font-medium' %>
    </div>
  </div>
</div>
```

### PR Show View

```erb
<!-- app/views/pull_requests/show.html.erb -->
<div class="grid grid-cols-1 lg:grid-cols-4 gap-6">
  <!-- Main Content -->
  <div class="lg:col-span-3 space-y-6">
    <!-- PR Header -->
    <div class="bg-white rounded-lg shadow p-6">
      <%= link_to '← Back', pull_requests_path, class: 'text-blue-600 hover:text-blue-800 mb-4 inline-block' %>
      
      <div class="flex items-start justify-between">
        <div>
          <h1 class="text-2xl font-bold text-gray-800">
            #<%= @pull_request.number %> - <%= @pull_request.title %>
          </h1>
          
          <div class="mt-2 flex items-center space-x-4 text-sm text-gray-600">
            <span class="flex items-center">
              <img src="<%= @pull_request.author_avatar %>" class="w-6 h-6 rounded-full mr-2">
              <%= @pull_request.author_name %>
            </span>
            <span><%= time_ago_in_words(@pull_request.github_created_at) %> ago</span>
          </div>
        </div>
        
        <%= render 'shared/pr_state_badge', pr: @pull_request %>
      </div>
      
      <% if @pull_request.body.present? %>
        <div class="mt-4 prose max-w-none">
          <%= simple_format(@pull_request.body) %>
        </div>
      <% end %>
      
      <div class="mt-4 flex space-x-4 text-sm">
        <span class="text-green-600">+<%= @pull_request.additions %></span>
        <span class="text-red-600">-<%= @pull_request.deletions %></span>
        <span class="text-gray-600"><%= @pull_request.changed_files_count %> files</span>
      </div>
    </div>
    
    <!-- Comments Timeline -->
    <div class="bg-white rounded-lg shadow" data-controller="timeline">
      <div class="p-6 border-b">
        <h2 class="text-xl font-semibold">Timeline</h2>
      </div>
      
      <div class="p-6">
        <div class="space-y-6">
          <% @comments.each do |comment| %>
            <%= render 'comments/comment_item', comment: comment %>
          <% end %>
        </div>
      </div>
    </div>
  </div>
  
  <!-- Sidebar -->
  <div class="lg:col-span-1 space-y-6">
    <!-- Knowledge Sidebar -->
    <div class="bg-white rounded-lg shadow p-6">
      <h3 class="text-lg font-semibold mb-4">📚 Related Insights</h3>
      
      <% if @related_insights.any? %>
        <div class="space-y-3">
          <% @related_insights.each do |insight| %>
            <%= link_to insight.title, insight_path(insight), 
                class: 'block text-sm text-blue-600 hover:text-blue-800' %>
          <% end %>
        </div>
      <% else %>
        <p class="text-sm text-gray-600">No related insights yet</p>
      <% end %>
    </div>
    
    <!-- Tags Summary -->
    <div class="bg-white rounded-lg shadow p-6">
      <h3 class="text-lg font-semibold mb-4">🏷️ Topics</h3>
      
      <div class="flex flex-wrap gap-2">
        <% @pull_request.comments.flat_map(&:tags).uniq.each do |tag| %>
          <%= render 'shared/tag_badge', tag: tag %>
        <% end %>
      </div>
    </div>
  </div>
</div>
```

### Stimulus Controllers

```javascript
// app/javascript/controllers/collapsible_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "icon"]
  
  toggle() {
    this.contentTarget.classList.toggle("hidden")
    this.iconTarget.classList.toggle("rotate-180")
  }
}

// app/javascript/controllers/search_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "results"]
  static values = { url: String }
  
  search() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => {
      this.performSearch()
    }, 300)
  }
  
  performSearch() {
    const query = this.inputTarget.value
    
    if (query.length < 3) {
      this.resultsTarget.innerHTML = ""
      return
    }
    
    fetch(`${this.urlValue}?q=${encodeURIComponent(query)}`, {
      headers: { "Accept": "text/vnd.turbo-stream.html" }
    })
  }
}

// app/javascript/controllers/filter_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form"]
  
  submit() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => {
      this.formTarget.requestSubmit()
    }, 500)
  }
}
```

## Configuration & Environment

```bash
# .env.example
DATABASE_URL=postgresql://localhost/pr_knowledge_hub_development
GITHUB_ACCESS_TOKEN=ghp_your_token_here
GITHUB_REPOSITORY=owner/repo

OPENAI_API_KEY=sk-your-key-here
GEMINI_API_KEY=your-key-here

REDIS_URL=redis://localhost:6379/1

# Production
RAILS_ENV=production
SECRET_KEY_BASE=your-secret-key
```

```ruby
# config/initializers/octokit.rb
Octokit.configure do |c|
  c.access_token = ENV['GITHUB_ACCESS_TOKEN']
  c.auto_paginate = true
end

# config/initializers/sidekiq.rb
Sidekiq.configure_server do |config|
  config.redis = { url: ENV['REDIS_URL'] }
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV['REDIS_URL'] }
end
```

## Deployment Considerations

### Infrastructure Requirements
- **Web Server:** Puma (default Rails)
- **Background Jobs:** Sidekiq + Redis
- **Database:** PostgreSQL 14+
- **Caching:** Redis (shared with Sidekiq)

### Recommended Platforms
- **Heroku:** Easy setup, auto-scaling
- **Render:** Modern alternative, good free tier
- **Railway:** Simple deployment, great DX
- **DigitalOcean App Platform:** Cost-effective

### Performance Optimizations
1. **Database Indexes:** Already covered in schema
2. **N+1 Queries:** Use `includes(:tags, :pull_request)` in controllers
3. **Caching:** Fragment caching for dashboard stats
4. **Rate Limiting:** Implement with Rack::Attack
5. **Background Processing:** Offload AI analysis to jobs

### Monitoring & Observability
- **Error Tracking:** Sentry or Rollbar
- **Application Monitoring:** New Relic or Scout APM
- **Job Monitoring:** Sidekiq Web UI
- **Logging:** LogDNA or Papertrail

## Security Considerations

### Authentication
```ruby
# Simple Devise setup for team
# config/initializers/devise.rb
Devise.setup do |config|
  config.mailer_sender = 'noreply@example.com'
  config.password_length = 8..128
end

# Create admin user in seeds
User.create!(
  email: 'admin@example.com',
  password: 'changeme',
  password_confirmation: 'changeme'
)
```

### API Security
- Store GitHub token in environment variables (never commit)
- Use read-only GitHub token (minimal permissions)
- Rotate tokens regularly
- Implement rate limiting on sync endpoints

### Data Protection
- Never store sensitive PR content if dealing with private repos
- Implement audit logs for user actions
- Regular database backups

## Testing Strategy

```ruby
# Test Coverage Priorities
1. Unit Tests
   - Models: associations, scopes, validations
   - Services: GitHub API integration, AI classification
   
2. Integration Tests
   - Background jobs execution
   - Full sync workflow
   
3. System Tests
   - Dashboard interaction
   - PR detail view
   - Search functionality
   
# Example model test
# spec/models/pull_request_spec.rb
RSpec.describe PullRequest, type: :model do
  describe 'associations' do
    it { should have_many(:comments) }
  end
  
  describe 'scopes' do
    it 'filters open PRs' do
      create(:pull_request, state: 'open')
      create(:pull_request, state: 'closed')
      
      expect(PullRequest.open.count).to eq(1)
    end
  end
end

# Example service test with VCR
# spec/services/github/pull_request_fetcher_spec.rb
RSpec.describe Github::PullRequestFetcher do
  it 'fetches and stores PR data', :vcr do
    fetcher = described_class.new('rails/rails', 1)
    
    expect { fetcher.fetch }.to change { PullRequest.count }.by(1)
  end
end
```

## Future Enhancements (Post-MVP)

1. **Multi-Repository Support**
   - Add repositories table
   - Update schema with repository_id foreign keys
   
2. **Advanced Analytics**
   - Reviewer leaderboard
   - Code quality trends
   - Review time heatmaps
   
3. **Notifications**
   - Email digests of weekly insights
   - Slack integration for new patterns
   
4. **Export Features**
   - PDF reports
   - CSV exports for analysis
   
5. **Custom Tagging**
   - User-defined tags
   - Tag management UI
   
6. **API Development**
   - RESTful API for external integrations
   - Webhooks support

## Success Metrics

Track these to measure value:
- **Usage:** Daily active users, sessions per user
- **Data Quality:** % of comments analyzed, accuracy of tags
- **Knowledge Discovery:** Search queries, insight views
- **Team Impact:** Survey feedback on usefulness
- **Technical:** Sync success rate, API rate limit usage

## Summary

This design provides a solid foundation for a PR Knowledge Hub that:
- ✅ Aggregates GitHub PR data efficiently
- ✅ Captures valuable reviewer comments
- ✅ Uses AI to discover patterns and lessons
- ✅ Provides intuitive search and discovery
- ✅ Built with modern Rails stack (Hotwire + Tailwind)
- ✅ Scalable architecture for future growth

The system balances simplicity (polling, single repo) with powerful features (AI insights, full-text search) suitable for a small team starting their knowledge management journey.
