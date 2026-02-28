#!/usr/bin/env ruby
# Script to test Gemini model names

require_relative '../config/environment'

puts "\n=== Testing Gemini Model Names ==="

models_to_test = [
  'gemini-flash',
  'gemini-pro',
  'gemini-1.5-flash',
  'gemini-1.5-pro',
  'gemini-2.0-flash',
  'gemini-2.5-flash',
  'gemini-3.0-flash',
  'models/gemini-flash',
  'models/gemini-1.5-flash',
  'models/gemini-pro'
]

api_key = ENV['GEMINI_API_KEY']

models_to_test.each do |model_name|
  print "\nTrying: #{model_name.ljust(30)}"

  begin
    client = Gemini.new(
      credentials: {
        service: 'generative-language-api',
        api_key: api_key
      },
      options: { model: model_name, server_sent_events: true }
    )

    response = client.stream_generate_content({
      contents: { role: 'user', parts: { text: 'Say OK' } }
    })

    # Try to get first response chunk
    result = nil
    response.each do |event|
      if event.dig('candidates', 0, 'content', 'parts', 0, 'text')
        result = event.dig('candidates', 0, 'content', 'parts', 0, 'text')
        break
      end
    end

    if result
      puts "✓ WORKS! Response: #{result.truncate(20)}"
      puts "\n✅ Found working model: #{model_name}"
      exit 0
    else
      puts "✗ No response"
    end

  rescue Faraday::ResourceNotFound => e
    puts "✗ 404 Not Found"
  rescue => e
    puts "✗ Error: #{e.message.split("\n").first.truncate(50)}"
  end
end

puts "\n❌ No working model found. Please check Gemini API documentation for current model names."
