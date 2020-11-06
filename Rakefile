require "bundler/setup"
require "bundler/gem_tasks"
require "bump/tasks"

task :default do
  sh "rspec specs/single_cov_spec.rb --warnings"
  sh "rubocop"
end
