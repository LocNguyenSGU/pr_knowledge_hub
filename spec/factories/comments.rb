FactoryBot.define do
  factory :comment do
    sequence(:github_id) { |n| n + 1000000 }
    association :pull_request
    body { "This is a test comment about code quality" }
    author_name { "octocat" }
    author_avatar { "https://github.com/images/error/octocat_happy.gif" }
    author_role { %w[member contributor owner].sample }
    comment_type { %w[issue_comment review_comment review].sample }
    path { nil }
    position { nil }
    line { nil }
    ai_analyzed { false }
    ai_summary { nil }
    github_created_at { 1.day.ago }
    github_updated_at { 1.day.ago }

    trait :analyzed do
      ai_analyzed { true }
      ai_summary { "This comment discusses code quality improvements" }
    end

    trait :with_tags do
      after(:create) do |comment|
        create_list(:tag, 2).each do |tag|
          comment.tags << tag
        end
      end
    end

    trait :review_comment do
      comment_type { "review_comment" }
      path { "app/models/user.rb" }
      position { 10 }
      line { 42 }
    end
  end
end
