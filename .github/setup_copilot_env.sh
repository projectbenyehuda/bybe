#!/bin/bash
# Setup script for GitHub Copilot Workspace environments
# Source this file to set up the correct Ruby version: source .github/setup_copilot_env.sh

# Check if Ruby 3.3.9 is available
if [ -d "/opt/hostedtoolcache/Ruby/3.3.9/x64/bin" ]; then
    export PATH="/opt/hostedtoolcache/Ruby/3.3.9/x64/bin:$PATH"
    echo "✓ Ruby 3.3.9 added to PATH"
    ruby --version
else
    echo "⚠ Warning: Ruby 3.3.9 not found in /opt/hostedtoolcache/Ruby/3.3.9/x64/bin"
    echo "  Current Ruby version: $(ruby --version)"
fi

# Check if bundler is available
if command -v bundle &> /dev/null; then
    echo "✓ Bundler is available (version: $(bundle --version))"
else
    echo "⚠ Warning: Bundler not found. Installing..."
    gem install bundler
fi

echo ""
echo "Environment setup complete. You can now run:"
echo "  bundle install   - Install Ruby dependencies"
echo "  bundle exec rspec - Run tests"
echo "  bundle exec rubocop - Run linter"
