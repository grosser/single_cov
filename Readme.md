# Single Cov [![CI](https://github.com/grosser/single_cov/actions/workflows/actions.yml/badge.svg)](https://github.com/grosser/single_cov/actions?query=branch%3Amaster)

Actionable code coverage.

```Bash
rspec spec/foobar_spec.rb
......
114 example, 0 failures

lib/foobar.rb new uncovered lines introduced (2 current vs 0 configured)
Uncovered lines:
lib/foobar.rb:22
lib/foobar.rb:23:6-19
```

 - Missing coverage on every 💚 test run
 - Catch coverage issues before making PRs
 - Easily add coverage enforcement for legacy apps
 - 2-5% runtime overhead on small files, compared to 20% for `SimpleCov`
 - Branch coverage (disable via `branches: false`)
 - Use with [forking_test_runner](https://github.com/grosser/forking_test_runner) for exact per test coverage

```Ruby
# Gemfile
gem 'single_cov', group: :test

# spec/spec_helper.rb ... load single_cov before rails, libraries, minitest, or rspec
require 'single_cov'
SingleCov.setup :rspec # or :minitest

# spec/foobar_spec.rb ... add covered! call to test files
require 'spec_helper'
SingleCov.covered!

describe "xyz" do ...
```

### Missing target file

Each `covered!` call expects to find a matching file, if it does not:

```Ruby
# change all guessed paths
SingleCov.rewrite { |f| f.sub('lib/unit/', 'app/models/') }

# mark directory as being in app and not lib
SingleCov::RAILS_APP_FOLDERS << 'presenters'

# add 1-off
SingleCov.covered! file: 'scripts/weird_thing.rb'
```

### Known uncovered

Add the inline comment `# uncovered` to ignore uncovered code.

Prevent addition of new uncovered code, without having to cover all existing code by marking how many lines are uncovered:

```Ruby
SingleCov.covered! uncovered: 4
```

### Making a folder not get prefixed with lib/

For example packwerk components are hosted in `public` and not `lib/public`

```ruby
SingleCov::PREFIXES_TO_IGNORE << "public"
```

### Missing coverage for implicit `else` in `if` or `case` statements

```ruby
# needs one test case for true and one for false (implicit else)
raise if a == b

# needs one test case for `when b` and one for `else`  (implicit else)
case a
when b
end
```

### Verify all code has tests & coverage

```Ruby
# spec/coverage_spec.rb
SingleCov.not_covered! # not testing any code in lib/

describe "Coverage" do
  # recommended
  it "does not allow new tests without coverage check" do
    # option :tests to pass custom Dir.glob results
    SingleCov.assert_used
  end

  # recommended
  it "does not allow new untested files" do
    # option :tests and :files to pass custom Dir.glob results
    # :untested to get it passing with known untested files
    SingleCov.assert_tested
  end
  
  # optional for full coverage enforcement
  it "does not reduce full coverage" do
    # make sure that nobody adds `uncovered: 123` to any test that did not have it before
    # option :tests to pass custom Dir.glob results
    # option :currently_complete for expected list of full covered tests
    # option :location for if you store that list in a separate file
    SingleCov.assert_full_coverage currently_complete: ["test/a_test.rb"]
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

### Cover multiple files from a single test

When a single integration test covers multiple source files.

```ruby
SingleCov.covered! file: 'app/modes/user.rb'
SingleCov.covered! file: 'app/mailers/user_mailer.rb'
SingleCov.covered! file: 'app/controllers/user_controller.rb'
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
