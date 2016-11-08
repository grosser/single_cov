require_relative "spec_helper"

SingleCov.instance_variable_set(:@root, File.expand_path("../fixtures/minitest", __FILE__))

describe SingleCov do
  it "has a VERSION" do
    expect(SingleCov::VERSION).to match /^[\.\da-z]+$/
  end

  describe "minitest" do
    let(:default_setup) { "SingleCov.setup :minitest, root: root" }

    around { |test| Dir.chdir("specs/fixtures/minitest", &test) }

    it "does not complain when everything is covered" do
      result = sh "ruby test/a_test.rb"
      assert_tests_finished_normally(result)
      expect(result).to_not include "uncovered"
    end

    it "can run from non-root" do
      result = sh "cd test && ruby a_test.rb"
      assert_tests_finished_normally(result)
      expect(result).to_not include "uncovered"
    end

    # fork exists with 1 ... so our override ignores it ...
    it "does not complain when forking" do
      change_file("test/a_test.rb", "assert A.new.a", "assert fork { 1 }\nsleep 0.1\n") do
        result = sh "ruby test/a_test.rb", fail: true
        assert_tests_finished_normally(result)
        expect(result.scan(/missing coverage/).size).to eq 1
      end
    end

    describe "when coverage has increased" do
      around { |t| change_file("test/a_test.rb", "SingleCov.covered!", "SingleCov.covered! uncovered: 1", &t) }

      # we might be running multiple files or have some special argument ... don't blow up
      it "warns" do
        result = sh "ruby test/a_test.rb"
        assert_tests_finished_normally(result)
        message = "lib/a.rb has less uncovered lines (0 current vs 1 configured), decrement configured uncovered?"
        expect(result).to include message
      end

      it "does not warn when running multiple files" do
        create_file 'test/b_test.rb', 'SingleCov.covered! file: "lib/a.rb"' do
          result = sh "ruby -r bundler/setup -r ./test/a_test.rb -r ./test/b_test.rb -e 1"
          assert_tests_finished_normally(result)
          expect(result).to_not include "has less uncovered lines"
        end
      end
    end

    describe "when something is uncovered" do
      around { |test| change_file("test/a_test.rb", "A.new.a", "1 # no test ...", &test) }

      it "complains" do
        result = sh "ruby test/a_test.rb", fail: true
        assert_tests_finished_normally(result)
        expect(result).to include "uncovered"
      end

      it "does not complain when only running selected tests via option" do
        result = sh "ruby test/a_test.rb -n /a/"
        assert_tests_finished_normally(result)
        expect(result).to_not include "uncovered"
      end

      it "does not complain when only running selected tests via = option" do
        result = sh "ruby test/a_test.rb -n=/a/"
        assert_tests_finished_normally(result)
        expect(result).to_not include "uncovered"
      end

      it "does not complain when only running selected tests via options and rails" do
        result = sh "bin/rails test test/a_test.rb -n '/foo/'"
        assert_tests_finished_normally(result)
        expect(result).to_not include "uncovered"
      end

      it "does not complain when only running selected tests via line number" do
        result = sh "bin/rails test test/a_test.rb:12"
        assert_tests_finished_normally(result)
        expect(result).to_not include "uncovered"
      end

      it "does not complain when tests failed" do
        change_file("test/a_test.rb", "assert", "refute") do
          result = sh "ruby test/a_test.rb", fail: true
          expect(result).to include "1 runs, 1 assertions, 1 failures"
          expect(result).to_not include "uncovered"
        end
      end
    end

    it "complains when minitest was started before and setup will not work" do
      change_file("test/a_test.rb", "require 'single_cov'", "require 'single_cov'\nrequire 'minitest/autorun'") do
        result = sh "ruby test/a_test.rb", fail: true
        expect(result).to include "Load minitest after setting up SingleCov"
      end
    end

    it "does not complain when minitest was loaded before setup" do
      change_file("test/a_test.rb", "require 'single_cov'", "require 'single_cov'\nmodule Minitest;end\n") do
        result = sh "ruby test/a_test.rb"
        assert_tests_finished_normally(result)
      end
    end

    describe "when file cannot be found from caller" do
      around { |test| move_file("test/a_test.rb", "test/b_test.rb", &test) }

      it "complains" do
        result = sh "ruby test/b_test.rb", fail: true
        expect(result).to include "Tried to guess covered file as lib/b.rb, but it does not exist."
        expect(result).to include "Use `SingleCov.covered file: 'target_file.rb'` to set covered file location."
      end

      it "works with a rewrite" do
        change_file("test/b_test.rb", "SingleCov.covered!", "SingleCov.rewrite { |f| 'lib/a.rb' }\nSingleCov.covered!") do
          result = sh "ruby test/b_test.rb"
          assert_tests_finished_normally(result)
        end
      end

      it "works with configured file" do
        change_file("test/b_test.rb", "SingleCov.covered!", "SingleCov.covered! file: 'lib/a.rb'") do
          result = sh "ruby test/b_test.rb"
          assert_tests_finished_normally(result)
        end
      end
    end

    describe "when SimpleCov was loaded after" do
      around { |t| change_file("test/a_test.rb", default_setup, "#{default_setup}\nrequire 'simplecov'\nSimpleCov.start\n", &t) }

      it "works" do
        result = sh "ruby test/a_test.rb"
        assert_tests_finished_normally(result)
        expect(result).to include "3 / 3 LOC (100.0%) covered" # SimpleCov
      end

      it "complains when coverage is bad" do
        change_file 'lib/a.rb', "def a", "def b\n1\nend\ndef a" do
          result = sh "ruby test/a_test.rb", fail: true
          assert_tests_finished_normally(result)
          expect(result).to include "4 / 5 LOC (80.0%) covered" # SimpleCov
          expect(result).to include "(1 current vs 0 configured)" # SingleCov
        end
      end
    end

    describe "when SimpleCov was defined but did not start" do
      around { |t| change_file("test/a_test.rb", default_setup, "#{default_setup}\nrequire 'simplecov'\n", &t) }

      it "falls back to Coverage and complains" do
        change_file 'lib/a.rb', "def a", "def b\n1\nend\ndef a" do
          result = sh "ruby test/a_test.rb", fail: true
          assert_tests_finished_normally(result)
          expect(result).to include "(1 current vs 0 configured)" # SingleCov
        end
      end
    end
  end

  describe "rspec" do
    around { |test| Dir.chdir("specs/fixtures/rspec", &test) }

    it "does not complain when everything is covered" do
      result = sh "bundle exec rspec spec/a_spec.rb"
      assert_specs_finished_normally(result)
      expect(result).to_not include "uncovered"
    end

    describe "when something is uncovered" do
      around { |t| change_file("spec/a_spec.rb", "A.new.a", "1", &t) }

      it "complains when something is uncovered" do
        result = sh "bundle exec rspec spec/a_spec.rb", fail: true
        assert_specs_finished_normally(result)
        expect(result).to include "uncovered"
      end

      it "does not complains when running a subset of tests by line" do
        result = sh "bundle exec rspec spec/a_spec.rb:14"
        assert_specs_finished_normally(result)
        expect(result).to_not include "uncovered"
      end

      it "does not complains when running a subset of tests sub-line" do
        result = sh "bundle exec rspec spec/a_spec.rb[1:1]"
        assert_specs_finished_normally(result)
        expect(result).to_not include "uncovered"
      end

      it "does not complains when running a subset of tests by name" do
        result = sh "bundle exec rspec spec/a_spec.rb -e 'does a'"
        assert_specs_finished_normally(result)
        expect(result).to_not include "uncovered"
      end

      it "does not complain when tests failed" do
        change_file("spec/a_spec.rb", "eq 1", "eq 2") do
          result = sh "bundle exec rspec spec/a_spec.rb", fail: true
          expect(result).to include "1 example, 1 failure"
          expect(result).to_not include "uncovered"
        end
      end
    end
  end

  describe ".assert_used" do
    around { |test| Dir.chdir("specs/fixtures/minitest", &test) }

    it "work when all tests have SingleCov" do
      SingleCov.assert_used
    end

    it "works when using .not_covered!" do
      change_file "test/a_test.rb", "SingleCov.covered!", 'SingleCov.not_covered!' do
        SingleCov.assert_used
      end
    end

    describe "when a test does not have SingleCov" do
      around { |t| change_file("test/a_test.rb", "SingleCov.covered", 'Nope', &t) }

      it "raises" do
        message = "test/a_test.rb: needs to use SingleCov.covered!"
        expect { SingleCov.assert_used }.to raise_error(RuntimeError, message)
      end

      it "works with custom files" do
        SingleCov.assert_used tests: []
      end
    end
  end

  describe ".assert_tested" do
    around { |test| Dir.chdir("specs/fixtures/minitest", &test) }

    it "work when all files have a test" do
      SingleCov.assert_tested
    end

    it "complains when untested are now tested" do
      message = "Remove [\"lib/b.rb\"] from untested!"
      expect { SingleCov.assert_tested untested: ['lib/b.rb'] }.to raise_error(RuntimeError, message)
    end

    describe "when a file is missing a test" do
      around { |t| move_file('lib/a.rb', 'lib/b.rb', &t) }

      it "complains " do
        message = "missing test for lib/b.rb"
        expect { SingleCov.assert_tested }.to raise_error(RuntimeError, message)
      end

      it "does not complain when it is marked as untested" do
        SingleCov.assert_tested untested: ['lib/b.rb']
      end
    end
  end

  describe ".file_under_test" do
    def file_under_test(test)
      SingleCov.send(:file_under_test, "#{SingleCov.send(:root)}/#{test}:34:in `foobar'")
    end

    {
      "test/models/xyz_test.rb" => "app/models/xyz.rb",
      "test/lib/xyz_test.rb" => "lib/xyz.rb",
      "spec/lib/xyz_spec.rb" => "lib/xyz.rb",
      "test/xyz_test.rb" => "lib/xyz.rb",
      "plugins/foo/test/lib/xyz_test.rb" => "plugins/foo/lib/xyz.rb",
      "plugins/foo/test/models/xyz_test.rb" => "plugins/foo/app/models/xyz.rb"
    }.each do |test, file|
      it "maps #{test} to #{file}" do
        expect(file_under_test(test)).to eq file
      end
    end

    it "complains about files without test folder" do
      message = "oops_test.rb includes neither 'test' nor 'spec' folder ... unable to resolve"
      expect { file_under_test("oops_test.rb") }.to raise_error(RuntimeError, message)
    end

    it "complains about files without test extension" do
      message = "Unable to remove test extension from test/oops.rb ... _test.rb and _spec.rb are supported"
      expect { file_under_test("test/oops.rb") }.to raise_error(RuntimeError, message)
    end
  end

  # covering a weird edge case where the test folder is not part of the root directory because
  # a nested gemfile was used which changed Bundler.root
  describe ".guess_and_check_covered_file" do
    it "complains nicely when calling file is outside of root" do
      expect(SingleCov).to receive(:file_under_test).and_return('/oops/foo.rb')
      expect do
        SingleCov.send(:guess_and_check_covered_file, nil)
      end.to raise_error(RuntimeError, /Found file \/oops\/foo.rb which is not relative to the root/)
    end
  end

  describe ".root" do
    it "ignores when bundler root is in a gemfiles folder" do
      begin
        old = SingleCov.send(:root)
        SingleCov.instance_variable_set(:@root, nil)
        expect(Bundler).to receive(:root).and_return(Pathname.new(old + '/gemfiles'))
        expect(SingleCov.send(:root)).to eq old
      ensure
        SingleCov.instance_variable_set(:@root, old)
      end
    end
  end

  def sh(command, options={})
    result = Bundler.with_clean_env { `#{command} #{"2>&1" unless options[:keep_output]}` }
    raise "#{options[:fail] ? "SUCCESS" : "FAIL"} #{command}\n#{result}" if $?.success? == !!options[:fail]
    result
  end

  def change_file(file, find, replace)
    old = File.read(file)
    raise "Did not find #{find}" unless new = old.dup.sub!(find, replace)
    File.write(file, new)
    yield
  ensure
    File.write(file, old)
  end

  def create_file(file, content)
    File.write(file, content)
    yield
  ensure
    File.unlink(file)
  end

  def move_file(a, b)
    FileUtils.mv(a, b)
    yield
  ensure
    FileUtils.mv(b, a)
  end

  def assert_tests_finished_normally(result)
    expect(result).to include "1 runs, 1 assertions, 0 failures"
  end

  def assert_specs_finished_normally(result)
    expect(result).to include "1 example, 0 failures"
  end
end
