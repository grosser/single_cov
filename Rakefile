require "bundler/setup"
require "bundler/gem_tasks"
require "bump/tasks"

task :default do
  m = (Bundler.respond_to?(:with_unbundled_env) ? :with_unbundled_env : :with_clean_env)
  Bundler.send(m) do
    sh "bundle exec rspec specs/single_cov_spec.rb --warnings"
  end
end
