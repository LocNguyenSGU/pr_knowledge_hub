#!/usr/bin/env ruby
require_relative '../config/environment'

Rails.logger = Logger.new(STDOUT)
Rails.logger.level = Logger::DEBUG

puts "\n=== Testing Gemini Classification ===\n"

gemini = Ai::GeminiClient.new

test_comment = "This code has a SQL injection vulnerability. Use parameterized queries."

puts "Comment: #{test_comment}\n\n"

categories = gemini.classify_comment(test_comment)

puts "\n✓ Final categories: #{categories.inspect}"

if categories.empty?
  puts "\n⚠️  No categories returned - check logs above for details"
else
  puts "\n✅ Success! Classification working correctly"
end
