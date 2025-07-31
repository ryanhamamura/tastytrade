# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "rubocop/rake_task"
require "bundler/audit/task"

RSpec::Core::RakeTask.new(:spec) do |t|
  t.pattern = Dir.glob("spec/**/*_spec.rb")
end
RuboCop::RakeTask.new
Bundler::Audit::Task.new

desc "Run all checks (tests, style, security)"
task check: %i[spec rubocop bundle:audit]

task default: :check
