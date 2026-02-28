#!/bin/bash
set -e

cd /Users/nguyenhuuloc/Documents/pr_knowledge_hub_implementation

echo "Running RSpec tests..."
RAILS_ENV=test bundle exec rspec --format documentation --no-color 2>&1

echo ""
echo "Checking coverage..."
if [ -f coverage/.last_run.json ]; then
  cat coverage/.last_run.json
fi
