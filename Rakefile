# frozen_string_literal: true
require "bundler/setup"
require "bundler/gem_tasks"
require "bump/tasks"

task default: [:spec, :rubocop]

task :spec do
  sh "bundle exec rspec specs/single_cov_spec.rb --warnings"
end

task :rubocop do
  sh "bundle exec rubocop"
end
