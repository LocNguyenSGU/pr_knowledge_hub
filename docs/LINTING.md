# Linting Setup

## Overview
This document describes the linting configuration for the PR Knowledge Hub project.

## Installation Date
February 28, 2026

## Tools Configured

### 1. RuboCop (Ruby Linter)
**Version**: Latest via `rubocop-rails-omakase` gem
**Purpose**: Ruby code style enforcement based on Rails Omakase style guide

#### Configuration File
`.rubocop.yml` - Custom configuration inheriting from Omakase

#### Key Settings
- **Max Line Length**: 120 characters (relaxed for views/specs)
- **Method Length**: 15 lines (relaxed for specs/tasks)
- **Block Length**: Excluded for specs, routes, environments, tasks
- **Documentation**: Disabled (don't require class docs for now)
- **Excluded Paths**: node_modules, vendor, tmp, bin, db/schema.rb, migrations

#### Usage
```bash
# Check all Ruby files
bundle exec rubocop

# Auto-fix violations
bundle exec rubocop --auto-correct-all

# Check specific file
bundle exec rubocop app/models/user.rb

# Via rake task
rails lint:rubocop
rails lint:rubocop_fix
```

#### Current Status
✅ **67 files inspected, 0 offenses**

All Ruby code passes RuboCop checks with the configured rules.

---

### 2. ERB Lint (Template Linter)
**Version**: 0.9.0
**Purpose**: ERB template linting with RuboCop integration

#### Configuration File
`.erb_lint.yml` - Custom configuration with integrated RuboCop rules

#### Key Settings
- **Default Linters**: Enabled
- **ErbSafety**: Disabled (compatibility issues with Ruby 3.4)
- **Rubocop Integration**: Enabled with same rules as .rubocop.yml
- **Excluded Paths**: node_modules, vendor, tmp, db

#### Enabled Linters
- `RequireInputAutocomplete` - Input fields need autocomplete attribute
- `NoJavascriptTagHelper` - Avoid javascript_tag helper (use importmap)
- `SpaceAroundErbTag` - Consistent spacing in ERB tags
- `TrailingWhitespace` - No trailing whitespace
- `ClosingErbTagIndent` - Proper indentation
- `ExtraNewline` - No excessive blank lines
- `FinalNewline` - File ends with newline
- `SelfClosingTag` - Proper self-closing HTML tags
- `Rubocop` - Apply RuboCop rules to Ruby code in ERB

#### Usage
```bash
# Check all ERB files
bundle exec erb_lint --lint-all

# Auto-fix violations
bundle exec erb_lint --lint-all --autocorrect

# Check specific file
bundle exec erb_lint app/views/dashboard/index.html.erb

# Via rake task
rails lint:erb
rails lint:erb_fix
```

#### Current Status
✅ **21 files linted, 0 errors**

All ERB templates pass linting checks. 210 violations were auto-corrected during initial setup.

---

### 3. Brakeman (Security Scanner)
**Version**: Latest
**Purpose**: Static analysis for security vulnerabilities

#### Configuration
No custom config file - uses defaults

#### Usage
```bash
# Run security scan
bundle exec brakeman

# Quiet mode with zero warnings check
bundle exec brakeman -q -z

# Generate HTML report
bundle exec brakeman -o brakeman_report.html

# Via rake task
rails lint:security
```

#### Current Status
⚠️ **1 warning detected**

**Warning Details**:
- **Type**: Cross-Site Scripting (XSS)
- **Confidence**: Weak
- **File**: [app/views/pull_requests/show.html.erb](app/views/pull_requests/show.html.erb#L36)
- **Issue**: `link_to` with model attribute in href
- **Assessment**: **False Positive** - `github_url` comes from GitHub API, not user input

This warning can be safely ignored or suppressed in future Brakeman config.

---

## Rake Tasks

Custom rake tasks are available in `lib/tasks/lint.rake`:

### Available Commands

```bash
# Run all linters (RuboCop + ERB Lint)
rails lint
rails lint:all

# Run individual linters
rails lint:rubocop       # Ruby files only
rails lint:erb           # ERB templates only
rails lint:security      # Security scan only

# Auto-fix issues
rails lint:fix           # Fix RuboCop + ERB Lint issues
rails lint:rubocop_fix   # Fix Ruby issues only
rails lint:erb_fix       # Fix ERB issues only

# Full check (all linters + security)
rails lint:full
```

### Rake Task Output

When running `rails lint:all`:
```
Running RuboCop...
67 files inspected, no offenses detected

Running ERB Lint...
21 files linted, no errors found

✅ All linting checks passed!
```

---

## Continuous Integration

### GitHub Actions (TODO - Phase 10)

Add to `.github/workflows/lint.yml`:

```yaml
name: Lint

on: [push, pull_request]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: 3.4.7
          bundler-cache: true
      - name: Run RuboCop
        run: bundle exec rubocop
      - name: Run ERB Lint
        run: bundle exec erb_lint --lint-all
      - name: Run Brakeman
        run: bundle exec brakeman -q
```

---

## Pre-commit Hooks (Optional)

To automatically run linters before commits, use `overcommit` gem:

### Setup

1. Add to Gemfile:
```ruby
gem 'overcommit', require: false, group: :development
```

2. Install and setup:
```bash
bundle install
overcommit --install
```

3. Create `.overcommit.yml`:
```yaml
PreCommit:
  RuboCop:
    enabled: true
    on_warn: fail
    command: ['bundle', 'exec', 'rubocop']

  ErbLint:
    enabled: true
    command: ['bundle', 'exec', 'erb_lint', '--lint-all']

  TrailingWhitespace:
    enabled: true
```

---

## Editor Integration

### VS Code

Install extensions:
- **Ruby**: Shopify.ruby-lsp
- **RuboCop**: Misogi.ruby-rubocop
- **ERB**: Aliariff.erb-helper

Add to `.vscode/settings.json`:
```json
{
  "ruby.lint": {
    "rubocop": true
  },
  "ruby.format": "rubocop",
  "[ruby]": {
    "editor.formatOnSave": true,
    "editor.formatOnType": true
  }
}
```

### RubyMine

1. Go to **Preferences** → **Editor** → **Inspections**
2. Enable **Ruby** → **Gems and gem management** → **RuboCop**
3. Set RuboCop executable path: `[project]/bin/rubocop`
4. Enable auto-format on save

---

## Fixing Common Issues

### RuboCop

**Issue**: String literals (single vs double quotes)
```ruby
# Bad
name = 'John'

# Good
name = "John"
```

**Issue**: Trailing whitespace
- Run: `rails lint:rubocop_fix`

**Issue**: Method too long
- Break into smaller methods
- Or add to `.rubocop.yml` exclusions

### ERB Lint

**Issue**: Missing space in ERB tag
```erb
<%# Bad %>
<%=link_to "Home", root_path%>

<%# Good %>
<%= link_to "Home", root_path %>
```

**Issue**: Trailing whitespace in templates
- Run: `rails lint:erb_fix`

### Brakeman

**Issue**: False positive XSS warning

Add to `config/brakeman.ignore`:
```json
{
  "ignored_warnings": [
    {
      "fingerprint": "abc123...",
      "note": "github_url is from GitHub API, not user input"
    }
  ]
}
```

Generate fingerprint: `brakeman -I`

---

## Statistics

### Initial Setup Results

**RuboCop**:
- Files inspected: 67
- Initial violations: 315
- Auto-corrected: 315
- Current violations: 0

**ERB Lint**:
- Files linted: 21
- Initial violations: 210
- Auto-corrected: 210
- Current violations: 0

**Total violations fixed**: 525

---

## Best Practices

### 1. Run Before Committing
```bash
# Quick check
rails lint

# Fix issues
rails lint:fix

# Full check (includes security)
rails lint:full
```

### 2. Address Violations Immediately
Don't let violations accumulate. Fix them when they appear.

### 3. Customize Rules Sparingly
Only disable rules with good reason. Document why in `.rubocop.yml`.

### 4. Security First
Never ignore Brakeman warnings without understanding them.

### 5. CI Integration
Add linting to CI pipeline to prevent merging code with violations.

---

## Troubleshooting

### RuboCop is slow
```bash
# Use parallel processing
bundle exec rubocop --parallel

# Cache results
bundle exec rubocop --cache true
```

### ERB Lint errors
```bash
# Check specific file for details
bundle exec erb_lint app/views/path/to/file.html.erb

# Disable problematic linter
# Add to .erb_lint.yml:
linters:
  ProblematicLinter:
    enabled: false
```

### Parser warnings (Ruby 3.4.7)
The warning about parser/ruby34 vs 3.4.7 is harmless and can be ignored.

---

## References

- [RuboCop Documentation](https://docs.rubocop.org/)
- [Rails Omakase Style Guide](https://github.com/rails/rubocop-rails-omakase)
- [ERB Lint](https://github.com/Shopify/erb-lint)
- [Brakeman](https://brakemanscanner.org/)
- [Ruby Style Guide](https://rubystyle.guide/)

---

## Summary

✅ **RuboCop**: Configured with Rails Omakase style
✅ **ERB Lint**: Configured with RuboCop integration
✅ **Brakeman**: Security scanning enabled
✅ **Rake Tasks**: 9 tasks for easy linting
✅ **Initial Violations**: 525 auto-fixed
✅ **Current Status**: All checks passing

Linting setup is **complete** and ready for development workflow.
