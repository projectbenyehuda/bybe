# GitHub Copilot Workspace Setup Guide

This document provides setup instructions for GitHub Copilot Agent/Workspace environments to ensure proper functionality when running tests and code.

## Ruby Version

This project requires **Ruby 3.3.9** (as specified in `.ruby-version` and `Gemfile`).

The Copilot Agent environment typically has Ruby 3.2.3 by default, but Ruby 3.3.9 is available at `/opt/hostedtoolcache/Ruby/3.3.9/x64/bin/`.

## Quick Setup

### Option 1: Use the Setup Script (Recommended)

```bash
# Source the setup script to configure Ruby 3.3.9
source .github/setup_copilot_env.sh

# Install system dependencies (required for gems)
sudo apt-get update
sudo apt-get install -y \
  mysql-client \
  libmysqlclient-dev \
  wkhtmltopdf \
  pandoc \
  yaz \
  libyaz-dev \
  libmagickwand-dev \
  libpcap-dev \
  cmake

# Install Ruby dependencies
bundle install
```

### Option 2: Manual Setup

If the setup script doesn't work or you prefer manual setup:

```bash
# Add Ruby 3.3.9 to PATH
export PATH="/opt/hostedtoolcache/Ruby/3.3.9/x64/bin:$PATH"

# Verify Ruby version
ruby --version  # Should show ruby 3.3.9

# Install Bundler if not already installed
gem install bundler

# Install system dependencies (required for gems)
sudo apt-get update
sudo apt-get install -y \
  mysql-client \
  libmysqlclient-dev \
  wkhtmltopdf \
  pandoc \
  yaz \
  libyaz-dev \
  libmagickwand-dev \
  libpcap-dev \
  cmake

# Install Ruby dependencies
bundle install

# start Docker-managed services used for tests
docker compose up redis mysql elasticsearch -d

# Create test database
bundle exec rake db:create RAILS_ENV=test
bundle exec rake db:migrate RAILS_ENV=test

# Verify setup
bundle exec ruby --version
```

## Running Tests

After setup, you can run tests with:

```bash
# Ensure Ruby 3.3.9 is in PATH
export PATH="/opt/hostedtoolcache/Ruby/3.3.9/x64/bin:$PATH"

# Run all tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/path/to/spec_file.rb
```

## Running Linters

```bash
# Run Pronto (checks only changed files)
bundle exec pronto run -c <TARGET BRANCH>
```

Note: &lt;TARGET BRANCH&gt; is the branch you want to merge your changes into.
Usually it will be `origin/master`, but may be different in some tasks.

If there are some rubocop errors, you can fix them with following commands:
```bash
# Run RuboCop with auto-correct
bundle exec rubocop -a path/to/file.rb

# Run RuboCop with unsafe auto-correct
bundle exec rubocop -A path/to/file.rb
```

## Troubleshooting

### Wrong Ruby Version

If you see errors like "Your Ruby version is X.X.X, but your Gemfile specified 3.3.9":
- Make sure Ruby 3.3.9 is in your PATH: `export PATH="/opt/hostedtoolcache/Ruby/3.3.9/x64/bin:$PATH"`
- Verify with: `ruby --version`

### Bundle Install Fails

If `bundle install` fails:
1. Ensure all system dependencies are installed (see Quick Setup section)
2. Check that you have the correct Ruby version active
3. Try removing `Gemfile.lock` and running `bundle install` again (not recommended for production)

## Version Management

This project uses:
- **Ruby**: 3.3.9 (specified in `.ruby-version`, `Gemfile`, and `.tool-versions`)
- **Rails**: 8.0.2.1
- **Bundler**: 2.5.23 (from Gemfile.lock)

## Additional Resources

- Main README: `README.md`
- Docker setup: `README.docker.md`
- GitHub Actions workflows: `.github/workflows/`
