# frozen_string_literal: true

namespace :lint do
  desc "Run all linters (RuboCop + ERB Lint)"
  task all: [ :rubocop, :erb ] do
    puts "\n✅ All linting checks passed!"
  end

  desc "Run RuboCop linter for Ruby files"
  task :rubocop do
    puts "Running RuboCop..."
    system "bundle exec rubocop"
  end

  desc "Run RuboCop with auto-correct"
  task :rubocop_fix do
    puts "Running RuboCop with auto-correct..."
    system "bundle exec rubocop --auto-correct-all"
  end

  desc "Run ERB Lint for ERB template files"
  task :erb do
    puts "Running ERB Lint..."
    system "bundle exec erb_lint --lint-all"
  end

  desc "Run ERB Lint with auto-correct"
  task :erb_fix do
    puts "Running ERB Lint with auto-correct..."
    system "bundle exec erb_lint --lint-all --autocorrect"
  end

  desc "Run Brakeman security scanner"
  task :security do
    puts "Running Brakeman security scanner..."
    system "bundle exec brakeman -q -z"
  end

  desc "Fix all auto-correctable issues"
  task fix: [ :rubocop_fix, :erb_fix ] do
    puts "\n✅ All auto-corrections applied!"
  end

  desc "Run full lint check (including security)"
  task full: [ :all, :security ] do
    puts "\n✅ Full lint check completed!"
  end
end

# Make 'rake lint' run all linters
desc "Run all linters (alias for lint:all)"
task lint: "lint:all"
