FactoryBot.define do
  factory :comment do
    github_id { "" }
    pull_request { nil }
    body { "MyText" }
    author_name { "MyString" }
    author_avatar { "MyString" }
    author_role { "MyString" }
    comment_type { "MyString" }
    path { "MyString" }
    position { 1 }
    line { 1 }
    ai_analyzed { false }
    ai_summary { "MyText" }
    github_created_at { "2026-02-28 10:00:23" }
    github_updated_at { "2026-02-28 10:00:23" }
  end
end
