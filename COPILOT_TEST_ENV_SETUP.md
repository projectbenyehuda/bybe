# Copilot Test Environment Setup Guide

This document describes how to set up and verify the `copilot_test_environment` branch for running RSpec tests and Pronto linting tools.

## Quick Start

For a quick start, use the helper script:

```bash
# Make sure you've completed the setup steps first (see below)
# Then use the helper script:

./run_tests.sh rspec                    # Run all tests
./run_tests.sh rspec spec/models/       # Run model tests
./run_tests.sh pronto run -c master     # Run pronto linter
./run_tests.sh rubocop app/models/      # Run rubocop
```

## Prerequisites

- Ruby 3.3.9 (available at `/opt/hostedtoolcache/Ruby/3.3.9/x64/bin/`)
- Docker and Docker Compose
- System dependencies: mysql-client, libmysqlclient-dev, wkhtmltopdf, pandoc, yaz, libyaz-dev, libmagickwand-dev, libpcap-dev, cmake

## Setup Steps

### 1. Checkout the Branch

```bash
git fetch origin copilot_test_environment:copilot_test_environment
git checkout copilot_test_environment
```

### 2. Configure Ruby Environment

```bash
# Use the setup script (recommended)
source .github/setup_copilot_env.sh

# Or manually set PATH
export PATH="/opt/hostedtoolcache/Ruby/3.3.9/x64/bin:$PATH"
ruby --version  # Should show ruby 3.3.9
bundle --version
```

### 3. Install System Dependencies

```bash
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
```

### 4. Install Ruby Dependencies

```bash
bundle install
```

### 5. Start Docker Services

```bash
docker compose up redis mysql elasticsearch -d
```

This will start:
- MySQL on port 13306
- Elasticsearch on port 19200
- Redis on port 16379

### 6. Configure Test Environment

```bash
# Copy test configuration files
cp ./.github/workflows/rspec_config/* ./config/

# Remove .env.test (will use DATABASE_URL environment variable)
rm -f .env.test
```

### 7. Setup Test Database

```bash
RAILS_ENV=test \
DATABASE_URL=mysql2://root:root@127.0.0.1:13306/bybe_test \
bundle exec rails db:create

RAILS_ENV=test \
DATABASE_URL=mysql2://root:root@127.0.0.1:13306/bybe_test \
bundle exec rails db:migrate
```

## Running Tests

### RSpec

```bash
# Set environment variables
export PATH="/opt/hostedtoolcache/Ruby/3.3.9/x64/bin:$PATH"
export RAILS_ENV=test
export ELASTICSEARCH_HOST=localhost:19200
export DATABASE_URL=mysql2://root:root@127.0.0.1:13306/bybe_test

# Run all tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/models/tagging_spec.rb

# Run specific test by line number
bundle exec rspec spec/models/tagging_spec.rb:10
```

### Pronto (Linting)

Pronto compares your changes against a target branch and reports style violations.

```bash
# Set environment variables
export PATH="/opt/hostedtoolcache/Ruby/3.3.9/x64/bin:$PATH"

# Fetch master branch if not already fetched
git fetch origin master:master

# Run pronto against master branch
bundle exec pronto run -c master

# Run pronto on staged changes only
bundle exec pronto run --staged

# Run pronto and show all formatters
bundle exec pronto run -f text -c master
```

**Note:** Pronto uses the `-c` flag to specify the comparison branch. Use `master` instead of `origin/master` in this environment.

### RuboCop (Direct Linting)

You can also run RuboCop directly:

```bash
# Check specific file
bundle exec rubocop path/to/file.rb

# Auto-correct safe violations
bundle exec rubocop -a path/to/file.rb

# Auto-correct all violations (including unsafe)
bundle exec rubocop -A path/to/file.rb

# Check all files
bundle exec rubocop
```

## Verification

After setup, you should see:

1. **RSpec version:**
   ```
   RSpec 3.13
     - rspec-core 3.13.4
     - rspec-expectations 3.13.5
     - rspec-mocks 3.13.5
     - rspec-rails 7.1.1
     - rspec-support 3.13.4
   ```

2. **Pronto version:** `0.11.4`
   - Configured runners: brakeman, haml, rubocop

3. **RuboCop version:** `1.79.1`

4. **Docker services running:**
   - bybe-mysql-1 (port 13306)
   - bybe-elasticsearch-1 (port 19200)
   - bybe-redis-1 (port 16379)

## What Has Been Verified

The following has been tested and confirmed working on the `copilot_test_environment` branch:

✅ **Ruby Environment**
- Ruby 3.3.9 correctly installed and accessible
- Bundler 2.5.23 working
- All gem dependencies installed successfully

✅ **RSpec Tests**
- RSpec framework loads correctly
- Database connectivity works
- Test suite runs successfully (tested with 168 model specs, all passing)
- Individual spec files can be run

✅ **Pronto Linting**
- Pronto command available and working
- All three runners configured: brakeman, haml, rubocop
- Can compare against master branch
- Can analyze staged changes

✅ **Docker Services**
- MySQL 8.0.36 running on port 13306
- Elasticsearch 7.17.8 running on port 19200
- Redis 7.2.3 running on port 16379
- Test database created and migrated successfully

✅ **Configuration Files**
- Test config files copied from .github/workflows/rspec_config/
- Database connection string properly configured
- Elasticsearch host configured

## Troubleshooting

### Ruby version mismatch

If you see "Your Ruby version is X.X.X, but your Gemfile specified 3.3.9":
```bash
export PATH="/opt/hostedtoolcache/Ruby/3.3.9/x64/bin:$PATH"
ruby --version
```

### Bundle install fails

Ensure all system dependencies are installed (see step 3).

### Database connection errors

Verify Docker services are running:
```bash
docker compose ps
```

Check that MySQL is accessible:
```bash
mysql -h 127.0.0.1 -P 13306 -u root -proot -e "SHOW DATABASES;"
```

### Pronto "revspec not found" error

Fetch the master branch:
```bash
git fetch origin master:master
```

Then use `master` (not `origin/master`) in pronto commands:
```bash
bundle exec pronto run -c master
```

## Clean Up

To stop Docker services:
```bash
docker compose down
```

To also remove volumes (database data):
```bash
docker compose down -v
```

## Additional Resources

- Main project setup: `README.md`
- Docker setup: `README.docker.md`
- Copilot workspace setup: `.github/COPILOT_WORKSPACE_SETUP.md`
- GitHub Actions workflows: `.github/workflows/`
