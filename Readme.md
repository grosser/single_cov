# Single Cov [![Build Status](https://travis-ci.org/grosser/single_cov.svg)](https://travis-ci.org/grosser/single_cov) [![coverage](https://img.shields.io/badge/coverage-100%25-success.svg)](https://github.com/grosser/single_cov)

Actionable code coverage.

```Bash
rspec spec/foobar_spec.rb
......
114 example, 0 failures

lib/foobar.rb new uncovered lines introduced (2 current vs 0 configured)",
Uncovered lines:
lib/foobar.rb:22
lib/foobar.rb:23:6-19
```

 - Missing coverage on every 💚 test run
 - Catch coverage issues before making PRs
 - Easily add coverage enforcement for legacy apps
 - 2-5% runtime overhead on small files, compared to 20% for `SimpleCov`
 - Branch coverage (disable via `branches: false`)
 - Use with [forking_test_runner](https://github.com/grosser/forking_test_runner) for per test coverage

```Ruby
# Gemfile
gem 'single_cov', group: :test

# spec/spec_helper.rb ... load before loading rails / minitest / libraries
require 'single_cov'
SingleCov.setup :rspec

# spec/foobar_spec.rb ... add covered! call to test files
require 'spec_helper'
SingleCov.covered!

describe "xyz" do ...
```

### Minitest

Call setup before loading minitest.

```Ruby
SingleCov.setup :minitest
require 'minitest/autorun'
```

### Unfound target file

```Ruby
# change all guessed paths
SingleCov.rewrite { |f| f.sub('lib/unit/', 'app/models/') }

# mark directory as being in app and not lib
SingleCov::APP_FOLDERS << 'presenters'

# add 1-off
SingleCov.covered! file: 'scripts/weird_thing.rb'
```

### Known uncovered

Add the inline comment `# uncovered` to not be alerted about it being uncovered.

Prevent addition of new uncovered code, without having to cover all existing code.

Alternatively mark how many lines are uncovered:

```Ruby
SingleCov.covered! uncovered: 4
```

### Verify all code has tests & coverage

```Ruby
# spec/coverage_spec.rb
SingleCov.not_covered! # not testing any code in lib/

describe "Coverage" do
  it "does not allow new untested code" do
    # option :tests to pass custom Dir.glob results
    SingleCov.assert_used
  end

  it "does not allow new untested files" do
    # option :tests and :files to pass custom Dir.glob results
    # :untested to get it passing with known untested files
    SingleCov.assert_tested
  end
end
```

### Automatic bootstrap

Run this from `irb` to get SingleCov added to all test files.

```Ruby
tests = Dir['spec/**/*_spec.rb']
command = "bundle exec rspec %{file}"

tests.each do |f|
  content = File.read(f)
  next if content.include?('SingleCov.')

  # add initial SingleCov call
  content = content.split(/\n/, -1)
  insert = content.index { |l| l !~ /require/ && l !~ /^#/ }
  content[insert...insert] = ["", "SingleCov.covered!"]
  File.write(f, content.join("\n"))

  # run the test to check coverage
  result = `#{command.sub('%{file}', f)} 2>&1`
  if $?.success?
    puts "#{f} is good!"
    next
  end

  if uncovered = result[/\((\d+) current/, 1]
    # configure uncovered
    puts "Uncovered for #{f} is #{uncovered}"
    content[insert+1] = "SingleCov.covered! uncovered: #{uncovered}"
    File.write(f, content.join("\n"))
  else
    # mark bad tests for manual cleanup
    content[insert+1] = "# SingleCov.covered! # TODO: manually fix this"
    File.write(f, content.join("\n"))
    puts "Manually fix: #{f} ... output is:\n#{result}"
  end
end
```

### Generating a coverage report

```ruby
SingleCov.coverage_report = "coverage/.resultset.json"
SingleCov.coverage_report_lines = true # only report line coverage for coverage systems that do not support branch coverage
```

Author
======
[Michael Grosser](http://grosser.it)<br/>
michael@grosser.it<br/>
License: MIT
