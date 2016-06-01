Actionable code coverage.

 - Easily add coverage tracking/enforcement for legacy apps
 - Get actionable feedback on every test run
 - Only 2-5% runtime overhead on small files compared to 50% for `SimpleCov`
 - No more PRs with bad test coverage

```Ruby
# Gemfile
gem 'single_cov', group: :test

# spec/spec_helper.rb ... load before loading rails / minitest / libraries
require 'single_cov'
SingleCov.setup :rspec

# spec/foobar_spec.rb ... add covered! call to every test file
require 'spec_helper'
SingleCov.covered!

describe "xyz" do ...
```

```Bash
rspec spec/foobar_spec.rb
......
114 example, 0 failures

lib/foobar.rb new uncovered lines introduced (2 current vs 0 configured)",
Uncovered lines:
lib/foobar.rb:22
lib/foobar.rb:23
```

### Minitest

Call setup before loading minitest.

```Ruby
SingleCov.setup :minitest
require 'minitest/autorun'
```

### Strange file locations

```Ruby
SingleCov.rewrite { |f| f.sub('lib/unit/', 'app/models/') }
```

### Known uncovered

Prevent addition of new uncovered code, without having to cover all existing code.

```Ruby
SingleCov.covered! uncovered: 4
```

### Unconventional files

```Ruby
SingleCov.covered! file: 'scripts/weird_thing.rb'
```

### Checking usage

Making sure every newly added file has coverage tracking.

```Ruby
# spec/kitchen_sink_spec.rb
it "has coverage for all tests" do
  # option :tests to pass custom Dir.glob results
  SingleCov.assert_used
end
```

### Checking global coverage

Making sure every newly added file has a corresponding test.

```Ruby
# spec/kitchen_sink_spec.rb
it "has tests for all files" do
  # option :tests and :files to pass custom Dir.glob results
  # :untested to get it passing with known untested files
  SingleCov.assert_tested
end
```

### Automatic bootstrap

Run this from `irb` to get SingleCov added to all test files.

```Ruby
tests = Dir['spec/**/*_spec.rb']

tests.each do |f|
  content = File.read(f)
  next if content.include?('SingleCov.')

  # add initial SingleCov call
  content = content.split(/\n/, -1)
  insert = content.index { |l| l !~ /require/ }
  content[insert...insert] = ["", "SingleCov.covered!"]
  File.write(f, content.join("\n"))

  # run the test to check coverage
  result = `rspec #{f} 2>&1`
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

Author
======
[Michael Grosser](http://grosser.it)<br/>
michael@grosser.it<br/>
License: MIT<br/>
[![Build Status](https://travis-ci.org/grosser/single_cov.png)](https://travis-ci.org/grosser/single_cov)
