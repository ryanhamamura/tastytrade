# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Common Development Tasks

### Running Tests
```bash
bundle exec rake spec         # Run all tests
bundle exec rspec spec/path   # Run specific test file
```

### Code Quality
```bash
bundle exec rake rubocop      # Run linter
bundle exec rubocop -a        # Auto-fix linting issues
```

### Development Console
```bash
bin/console                   # Interactive Ruby console with gem loaded
```

### Building and Installing Locally
```bash
bundle exec rake build        # Build gem to pkg/
bundle exec rake install      # Install gem locally
```

### Release Process
```bash
bin/release                   # Interactive release script
# OR manually:
# 1. Update version in lib/tastytrade/version.rb
# 2. Update CHANGELOG.md
# 3. bundle exec rake release
```

## Project Structure

```
tastytrade/
├── lib/
│   └── tastytrade/          # Main gem code
│       └── version.rb       # Version constant
├── spec/                    # RSpec tests
├── bin/                     # Executable scripts
│   ├── console             # Development console
│   ├── setup               # Setup script
│   └── release             # Release automation
├── docs/                    # Additional documentation
└── .github/workflows/       # CI/CD configuration
```

## Architecture Notes

This is a Ruby gem scaffold with professional tooling setup:
- RSpec for testing with SimpleCov for coverage
- RuboCop for code style enforcement
- GitHub Actions for multi-OS and multi-Ruby CI
- Security policy and contribution guidelines
- Professional README with badges and clear sections

## Key Development Patterns

1. **Version Management**: Version is defined in `lib/tastytrade/version.rb`
2. **Testing**: Mirror directory structure in spec/, use descriptive test names
3. **Documentation**: Use YARD format for method documentation
4. **Error Handling**: Raise specific error classes, not generic exceptions
5. **Dependencies**: Keep runtime dependencies minimal, use development dependencies liberally

## Gem-Specific Configurations

- Ruby 3.2.0+ required
- RuboCop configured with custom rules in `.rubocop.yml`
- RSpec configured in `.rspec` and `spec/spec_helper.rb`
- Git-based file inclusion in gemspec
- MFA required for RubyGems.org pushes