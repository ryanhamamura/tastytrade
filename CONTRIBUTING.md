# Contributing to Tastytrade

First off, thank you for considering contributing to Tastytrade! It's people like you that make Tastytrade such a great tool.

## Code of Conduct

This project and everyone participating in it is governed by our [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code.

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check existing issues as you might find out that you don't need to create one. When you are creating a bug report, please include as many details as possible:

* **Use a clear and descriptive title**
* **Describe the exact steps to reproduce the problem**
* **Provide specific examples to demonstrate the steps**
* **Describe the behavior you observed and what behavior you expected**
* **Include Ruby version, gem version, and OS information**

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion, please include:

* **Use a clear and descriptive title**
* **Provide a step-by-step description of the suggested enhancement**
* **Provide specific examples to demonstrate the steps**
* **Describe the current behavior and explain the expected behavior**
* **Explain why this enhancement would be useful**

### Pull Requests

1. Fork the repo and create your branch from `main`
2. If you've added code that should be tested, add tests
3. If you've changed APIs, update the documentation
4. Ensure the test suite passes (`bundle exec rake`)
5. Make sure your code follows the style guidelines (`bundle exec rubocop`)
6. Issue that pull request!

## Development Setup

1. Fork and clone the repo
2. Run `bin/setup` to install dependencies
3. Run `bundle exec rake spec` to run the tests
4. Run `bin/console` for an interactive prompt

## Style Guidelines

### Ruby Style Guide

We use RuboCop with a few customizations. Run `bundle exec rubocop` to check your code.

Key points:
* Use double quotes for strings
* Keep lines under 120 characters
* Write descriptive commit messages

### Commit Messages

* Use the present tense ("Add feature" not "Added feature")
* Use the imperative mood ("Move cursor to..." not "Moves cursor to...")
* Limit the first line to 72 characters or less
* Reference issues and pull requests liberally after the first line

## Testing

* Write RSpec tests for all new functionality
* Ensure all tests pass before submitting PR
* Aim for high test coverage but focus on testing behavior, not implementation
* Use descriptive test names that explain what is being tested

## Documentation

* Update the README.md with details of changes to the interface
* Update the CHANGELOG.md following the Keep a Changelog format
* Comment your code where necessary
* Use YARD documentation for public APIs

## Release Process

Maintainers will handle releases, but for reference:

1. Update version number in `lib/tastytrade/version.rb`
2. Update CHANGELOG.md
3. Run `bundle exec rake release`

## Questions?

Feel free to open an issue with the "question" label if you have any questions about contributing.