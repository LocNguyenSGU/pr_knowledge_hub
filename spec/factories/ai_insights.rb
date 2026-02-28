FactoryBot.define do
  factory :ai_insight do
    insight_type { "MyString" }
    title { "MyString" }
    content { "MyText" }
    related_comments { "" }
    confidence_score { 1.5 }
    ai_model { "MyString" }
  end
end
