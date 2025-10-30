#!/bin/bash
# Helper script to run tests on copilot_test_environment branch

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  Copilot Test Environment Runner    ${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""

# Setup Ruby environment
echo -e "${YELLOW}Setting up Ruby 3.3.9 environment...${NC}"
export PATH="/opt/hostedtoolcache/Ruby/3.3.9/x64/bin:$PATH"

# Setup test environment variables
export RAILS_ENV=test
export ELASTICSEARCH_HOST=localhost:19200
export DATABASE_URL=mysql2://root:root@127.0.0.1:13306/bybe_test

echo -e "${GREEN}✓ Ruby version: $(ruby --version)${NC}"
echo -e "${GREEN}✓ Bundler version: $(bundle --version)${NC}"
echo ""

# Check if command line argument is provided
if [ $# -eq 0 ]; then
    echo "Usage:"
    echo "  $0 rspec [args...]    - Run RSpec tests"
    echo "  $0 pronto [args...]   - Run Pronto linter"
    echo "  $0 rubocop [args...]  - Run RuboCop"
    echo ""
    echo "Examples:"
    echo "  $0 rspec                              # Run all tests"
    echo "  $0 rspec spec/models/user_spec.rb     # Run specific test file"
    echo "  $0 pronto -c master                   # Run pronto against master"
    echo "  $0 rubocop app/models/user.rb         # Lint specific file"
    exit 1
fi

COMMAND=$1
shift  # Remove first argument, leaving any additional args

case $COMMAND in
    rspec)
        echo -e "${YELLOW}Running RSpec tests...${NC}"
        bundle exec rspec "$@"
        ;;
    pronto)
        echo -e "${YELLOW}Running Pronto linter...${NC}"
        bundle exec pronto "$@"
        ;;
    rubocop)
        echo -e "${YELLOW}Running RuboCop...${NC}"
        bundle exec rubocop "$@"
        ;;
    *)
        echo -e "${RED}Unknown command: $COMMAND${NC}"
        echo "Use: rspec, pronto, or rubocop"
        exit 1
        ;;
esac
