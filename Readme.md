Actionable code coverage.

 - Easily add coverage tracking/enforcement for legacy apps
 - Get actionable feedback on every test run
 - Only 2-5% runtime overhead on small files compared to 50% for `SimpleCov`
 - No more PRs with bad test coverage

```Ruby
# Gemfile
gem 'single_cov', group: :test

# test/test_helper.rb ... load before loading rails / minitest / libraries
require 'single_cov'
SingleCov.setup :minitest
require 'minitest/autorun'

# test/foobar_test.rb ... add covered! call to every test file
require_relative '../test_helper'
SingleCov.covered!

describe "xyz" do ...
```

```Bash
ruby test/foobar_test.rb
......
100 runs, 150 assertions, 0 failures

lib/foobar.rb new uncovered lines introduced (2 current vs 0 configured)",
Uncovered lines:
lib/foobar.rb:22
lib/foobar.rb:23
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
it "has coverage for all tests" do
  # option :tests and :files to pass custom Dir.glob results
  # :untested to get it passing with known untested files
  SingleCov.assert_tested
end
```

Author
======
[Michael Grosser](http://grosser.it)<br/>
michael@grosser.it<br/>
License: MIT<br/>
[![Build Status](https://travis-ci.org/grosser/single_cov.png)](https://travis-ci.org/grosser/single_cov)
