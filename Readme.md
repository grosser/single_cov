Actionable code coverage.

 - Easily add coverage tracking/enforcement for legacy apps
 - Get actionable feedback on every test run
 - Only 2-5% runtime overhead on small files compared to 50% for `SimpleCov`
 - No more PRs with bad test coverage

```Ruby
# Gemfile
gem 'single_cov', group: :test

# spec/spec_helper.rb
SingleCover.setup :rspec # ... or :minitest

# spec/foobar_spec.rb
SingleCover.covered!
```

```Bash
rspec spec/foobar_spec.rb
lib/foobar.rb new uncovered lines introduced 2 current vs 0 previous",
Uncovered lines:
lib/foobar.rb:22
lib/foobar.rb:23
```

### Known uncovered

Prevent addition of new uncovered code, without having to cover all existing code.

```
SingleCov.covered! uncovered: 4
```

### Unconventional files

```
SingleCov.covered! file: 'scripts/weird_thing.rb'
```

### Checking usage
 
Making sure every newly added file has coverage tracking.

```
# spec/kitchen_sink_spec.rb
it "has coverage for all tests" do
  # option :tests to pass custom Dir.glob results 
  SingleCover.assert_used
end
```

### Checking global coverage
 
Making sure every newly added file has a corresponding test.

```
# spec/kitchen_sink_spec.rb
it "has coverage for all tests" do
  # option :tests and :files to pass custom Dir.glob results
  # :untested to get it passing with known untested files
  SingleCover.assert_tested
end
```

Author
======
[Michael Grosser](http://grosser.it)<br/>
michael@grosser.it<br/>
License: MIT<br/>
[![Build Status](https://travis-ci.org/grosser/single_cov.png)](https://travis-ci.org/grosser/single_cov)
