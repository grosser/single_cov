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

desc "bundle all gemfiles CMD=install"
task :bundle do
  extra = ENV["CMD"] || "install"
  Bundler.with_original_env do
    Dir["{Gemfile,gemfiles/*.gemfile}"].reverse.each do |gemfile|
      sh "BUNDLE_GEMFILE=#{gemfile} bundle #{extra}"
    end
  end
end
