namespace :debug do
  desc "Debug Gemini API response"
  task gemini: :environment do
    require "json"

    puts "Testing Gemini API..."
    puts

    client = Gemini.new(
      credentials: {
        service: "generative-language-api",
        api_key: ENV["GEMINI_API_KEY"]
      },
      options: { model: "gemini-2.0-flash-exp", server_sent_events: true }
    )

    prompt = 'Classify this comment: "SQL injection vulnerability" into categories: security, performance, bug. Return JSON array like ["security"]'

    response = client.stream_generate_content({
      contents: { role: "user", parts: { text: prompt } }
    })

    full_text = ""
    response.each do |event|
      text = event.dig("candidates", 0, "content", "parts", 0, "text")
      full_text += text if text
    end

    puts "Response text:"
    puts full_text
    puts

    # Try to find JSON
    if full_text =~ /\[.*\]/m
      json_str = full_text.match(/\[.*\]/m)[0]
      puts "Found JSON: #{json_str}"

      begin
        parsed = JSON.parse(json_str)
        puts "Parsed: #{parsed.inspect}"
      rescue => e
        puts "Parse error: #{e.message}"
      end
    else
      puts "No JSON array found"
    end
  end

  desc "Debug with simpler non-streaming request"
  task gemini_simple: :environment do
    puts "Testing Gemini without streaming..."

    client = Gemini.new(
      credentials: {
        service: "generative-language-api",
        api_key: ENV["GEMINI_API_KEY"]
      },
      options: { model: "gemini-2.0-flash-exp", server_sent_events: false }
    )

    result = client.generate_content({
      contents: {
        role: "user",
        parts: {
          text: 'Return this exact JSON: ["security", "best_practice"]'
        }
      }
    })

    puts "Full result:"
    puts JSON.pretty_generate(result)
  end
end
