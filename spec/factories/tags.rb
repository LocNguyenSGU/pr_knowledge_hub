FactoryBot.define do
  factory :tag do
    sequence(:name) { |n| "#{Tag::CATEGORIES.sample}_#{n}" }
    color { "##{%w[blue green red yellow purple orange].sample}-500" }
    description { "This is a test tag" }
    category { Tag::CATEGORIES.sample }

    trait :security do
      name { "security" }
      category { "security" }
      color { "#red-500" }
    end

    trait :performance do
      name { "performance" }
      category { "performance" }
      color { "#yellow-500" }
    end

    trait :code_style do
      name { "code_style" }
      category { "code_style" }
      color { "#blue-500" }
    end
  end
end
