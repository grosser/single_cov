require "bundler/setup"
require "bundler/gem_tasks"
require "bump/tasks"

task :default do
  Bundler.with_unbundled_env do
    sh "bundle exec rspec specs/single_cov_spec.rb --warnings"
  end
end
