# frozen_string_literal: true
require_relative "spec_helper"

SingleCov.instance_variable_set(:@root, File.expand_path('fixtures/minitest', __dir__))

describe SingleCov do
  def self.it_does_not_complain_when_everything_is_covered(in_test: false)
    it "does not complain when everything is covered" do
      result = sh(in_test ? "cd test && ruby a_test.rb" : "ruby test/a_test.rb")
      assert_tests_finished_normally(result)
      expect(result).to_not include "uncovered"
    end
  end

  def add_missing_coverage(&block)
    change_file("test/a_test.rb", "A.new.a", "1 # no test ...", &block)
  end

  it "has a VERSION" do
    expect(SingleCov::VERSION).to match(/^[.\da-z]+$/)
  end

  describe "minitest" do
    let(:default_setup) { "SingleCov.setup :minitest, root: root" }

    around { |test| Dir.chdir("specs/fixtures/minitest", &test) }

    it_does_not_complain_when_everything_is_covered

    it "is silent" do
      result = sh "ruby test/a_test.rb"
      assert_tests_finished_normally(result)
      expect(result).to_not include "warning"
    end

    it "can redirect output" do
      create_file("err", "1") do
        result = change_file "test/a_test.rb", ":minitest, ", ":minitest, err: File.open('err', 'w'), " do
          change_file "test/a_test.rb", ".covered!", ".covered! uncovered: 3" do
            sh "ruby test/a_test.rb"
          end
        end
        assert_tests_finished_normally(result)
        expect(result).to_not include "lib/a.rb has less uncovered lines"
        expect(File.read("err")).to include "lib/a.rb has less uncovered lines"
      end
    end

    it "complains about missing implicit else for if" do
      change_file("lib/a.rb", "1", "1 if 1.to_s == '1'") do # does not work with `if true` since ruby inlines it
        result = sh "ruby test/a_test.rb", fail: true
        assert_tests_finished_normally(result)
        expect(result).to include "1 current"
        expect(result).to include "lib/a.rb:4:5-23"
      end
    end

    it "complains about missing implicit else for case" do
      change_file("lib/a.rb", "1", "case 1\nwhen 1 then 1\nend") do
        result = sh "ruby test/a_test.rb", fail: true
        assert_tests_finished_normally(result)
        expect(result).to include "1 current"
        expect(result).to include "lib/a.rb:4:5-6:4"
      end
    end

    describe "running in non-root" do
      it_does_not_complain_when_everything_is_covered in_test: true

      it "can report failure" do
        add_missing_coverage do
          result = sh "cd test && ruby a_test.rb", fail: true
          expect(result).to include "uncovered"
        end
      end
    end

    describe "fork" do
      it "does not complain in forks" do
        change_file("test/a_test.rb", %(it "does a" do), %(it "does a" do\nfork { }\n)) do
          result = sh "ruby test/a_test.rb"
          assert_tests_finished_normally(result)
          expect(result).to_not include("cover")
        end
      end

      # fork exists with 1 ... so our override ignores it ...
      it "does not complain when forking" do
        change_file("test/a_test.rb", "assert A.new.a", "assert fork { 1 }\nsleep 0.1\n") do
          result = sh "ruby test/a_test.rb", fail: true
          assert_tests_finished_normally(result)
          expect(result.scan(/missing coverage/).size).to eq 1
        end
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
      around { |block| add_missing_coverage(&block) }

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

      it "does not complain when individually disabled" do
        change_file("lib/a.rb", "1", "1 # uncovered") do
          sh "ruby test/a_test.rb"
        end
      end
    end

    describe "load order" do
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
    end

    describe "when file cannot be found from caller" do
      around { |test| move_file("test/a_test.rb", "test/b_test.rb", &test) }

      it "complains" do
        result = sh "ruby test/b_test.rb", fail: true
        expect(result).to include "Tried to guess covered file as lib/b.rb, but it does not exist."
        expect(result).to include "Use `SingleCov.covered! file: 'target_file.rb'` to set covered file location."
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
      # NOTE: SimpleCov also starts coverage and will break when we activated branches
      let(:branchless_setup) { default_setup.sub('root: root', 'root: root, branches: false') }

      around { |t| change_file("test/a_test.rb", default_setup, "#{branchless_setup}\nrequire 'simplecov'\nSimpleCov.start\n", &t) }

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

    describe "branch coverage" do
      around { |t| change_file("test/a_test.rb", "root: root", "root: root, branches: true", &t) }

      it_does_not_complain_when_everything_is_covered

      describe "with branches" do
        around { |t| change_file("lib/a.rb", "1", "2.times { |i| rand if i == 0 }", &t) }

        it_does_not_complain_when_everything_is_covered

        it "complains when branch coverage is missing" do
          change_file("lib/a.rb", "i == 0", "i != i") do
            result = sh "ruby test/a_test.rb", fail: true
            expect(result).to include ".lib/a.rb new uncovered lines introduced (1 current vs 0 configured)"
            expect(result).to include "lib/a.rb:4:19-23"
          end
        end

        it "complains sorted when line and branch coverage are bad" do
          change_file 'lib/a.rb', "def a", "def b\n1\nend\ndef a" do
            change_file("lib/a.rb", "i == 0", "i != i") do
              result = sh "ruby test/a_test.rb 2>&1", fail: true
              expect(result).to include "lib/a.rb new uncovered lines introduced (2 current vs 0 configured)"
              expect(result).to include "lib/a.rb:4\nlib/a.rb:7:19-23"
            end
          end
        end

        it "does not complain about branch being missing when line is not covered" do
          change_file("lib/a.rb", "end", "end\ndef b\n2.times { |i| rand if i == 0 }\nend\n") do
            result = sh "ruby test/a_test.rb", fail: true
            expect(result).to include ".lib/a.rb new uncovered lines introduced (1 current vs 0 configured)"
            expect(result).to include "lib/a.rb:7"
          end
        end

        it "does not duplicate coverage" do
          change_file("lib/a.rb", "i == 0", "i == 0 if i if 0 if false") do
            result = sh "ruby test/a_test.rb", fail: true
            expect(result).to include ".lib/a.rb new uncovered lines introduced (3 current vs 0 configured)"
            expect(result).to include "lib/a.rb:4:19-23\nlib/a.rb:4:19-33\nlib/a.rb:4:19-38"
          end
        end

        it "ignores 0 coverage from duplicate ensure branches" do
          change_file("lib/a.rb", "i == 0", "begin; i == 0; ensure; i == 0 if i == 0;end") do
            result = sh "ruby test/a_test.rb"
            assert_tests_finished_normally(result)
            expect(result).to_not include "uncovered"
          end
        end
      end
    end

    describe "generate_report" do
      around do |t|
        replace = "#{default_setup}\nSingleCov.coverage_report = 'coverage/.resultset.json'"
        change_file("test/a_test.rb", default_setup, replace, &t)
      end
      after { FileUtils.rm_rf("coverage") }

      it "generates when requested" do
        sh "ruby test/a_test.rb"
        result = JSON.parse(File.read("coverage/.resultset.json"))
        expect(result["Minitest"]["coverage"]).to eq(
          "#{Bundler.root}/specs/fixtures/minitest/lib/a.rb" => { "branches" => {}, "lines" => [nil, 1, 1, 1, nil, nil] }
        )
      end

      it "can force line coverage" do
        change_file("test/a_test.rb", default_setup, "#{default_setup}\nSingleCov.coverage_report_lines = true") do
          sh "ruby test/a_test.rb"
        end
        result = JSON.parse(File.read("coverage/.resultset.json"))
        coverage = [nil, 1, 1, 1, nil, nil]
        expect(result["Minitest"]["coverage"]).to eq(
          "#{Bundler.root}/specs/fixtures/minitest/lib/a.rb" => coverage
        )
      end

      it "does mot fail if file exists" do
        FileUtils.mkdir_p "coverage"
        File.write("coverage/.resultset.json", "NOT-JSON")
        sh "ruby test/a_test.rb"
        JSON.parse(File.read("coverage/.resultset.json")) # was updated
      end
    end
  end

  describe "rspec" do
    around { |test| Dir.chdir("specs/fixtures/rspec", &test) }

    it "does not complain when everything is covered" do
      result = sh "bundle exec rspec spec/a_spec.rb"
      assert_specs_finished_normally(result, 3)
      expect(result).to_not include "uncovered"
    end

    it "does not complain in forks when disabled" do
      change_file(
        "spec/a_spec.rb",
        %(it "does a" do), %{it "does a" do\nfork { SingleCov.remove_instance_variable(:@pid); SingleCov.disable }\n}
      ) do
        result = sh "bundle exec rspec spec/a_spec.rb"
        expect(result).to_not include "uncovered"
        assert_specs_finished_normally(result, 3)
      end
    end

    it "does not complain in forks by default" do
      change_file("spec/a_spec.rb", %(it "does a" do), %(it "does a" do\nfork { 11 }\n)) do
        result = sh "bundle exec rspec spec/a_spec.rb"
        assert_specs_finished_normally(result, 3)
        expect(result).to_not include "uncovered"
      end
    end

    describe "when something is uncovered" do
      around { |t| change_file("spec/a_spec.rb", "A.new.a", "1", &t) }

      it "complains when something is uncovered" do
        result = sh "bundle exec rspec spec/a_spec.rb", fail: true
        assert_specs_finished_normally(result, 3)
        expect(result).to include "uncovered"
      end

      it "does not complains when running a subset of tests by line" do
        result = sh "bundle exec rspec spec/a_spec.rb:15"
        assert_specs_finished_normally(result, 1)
        expect(result).to_not include "uncovered"
      end

      it "does not complains when running a subset of tests sub-line" do
        result = sh "bundle exec rspec spec/a_spec.rb[1:1]"
        assert_specs_finished_normally(result, 1)
        expect(result).to_not include "uncovered"
      end

      it "does not complains when running a subset of tests by name" do
        result = sh "bundle exec rspec spec/a_spec.rb -e 'does a'"
        assert_specs_finished_normally(result, 1)
        expect(result).to_not include "uncovered"
      end

      it "does not complain when tests failed" do
        change_file("spec/a_spec.rb", "eq 1", "eq 2") do
          result = sh "bundle exec rspec spec/a_spec.rb", fail: true
          expect(result).to include "3 examples, 1 failure"
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

  describe ".assert_full_coverage" do
    def call
      SingleCov.assert_full_coverage currently_complete: complete
    end

    let(:complete) { ["test/a_test.rb"] }

    around { |test| Dir.chdir("specs/fixtures/minitest", &test) }

    it "works when correct files are covered" do
      call
    end

    it "alerts when files are newly covered" do
      expect do
        complete.pop
        call
      end.to raise_error(/single_cov_spec\.rb.*test\/a_test.rb/m)
    end

    it "alerts when files lost coverage" do
      expect do
        change_file('test/a_test.rb', 'SingleCov.covered!', 'SingleCov.covered! uncovered: 12') { call }
      end.to raise_error(/test\/a_test.rb/)
    end

    it "ignores files not_covered" do
      complete.pop
      change_file('test/a_test.rb', 'SingleCov.covered!', 'SingleCov.not_covered!') { call }
    end

    it "ignores files with uncovered commented out" do
      change_file('test/a_test.rb', 'SingleCov.covered!', 'SingleCov.covered! # uncovered: 12') { call }
    end

    describe 'when file cannot be found from caller' do
      let(:complete) { ["test/b_test.rb"] }

      around { |test| move_file('test/a_test.rb', 'test/b_test.rb', &test) }

      it "works when files covered and configured" do
        change_file('test/b_test.rb', 'SingleCov.covered!', 'SingleCov.covered! file: lib/a.rb') { call }
      end

      it "alerts when files lost coverage and are configured" do
        expect do
          change_file('test/b_test.rb', 'SingleCov.covered!', 'SingleCov.covered!(uncovered: 12, file: lib/a.rb)') { call }
        end.to raise_error(/test\/b_test.rb/)
      end
    end
  end

  describe ".file_under_test" do
    def file_under_test(test)
      SingleCov.send(:guess_covered_file, "#{SingleCov.send(:root)}/#{test}:34:in `foobar'")
    end

    def self.it_maps_path(test, file, ignore)
      it "maps #{test} to #{file}#{" when ignoring prefixes" if ignore}" do
        stub_const('SingleCov::PREFIXES_TO_IGNORE', ['public']) if ignore
        expect(file_under_test(test)).to eq file
      end
    end

    [false, true].each do |ignore|
      {
        "test/models/xyz_test.rb" => "app/models/xyz.rb",
        "test/lib/xyz_test.rb" => "lib/xyz.rb",
        "spec/lib/xyz_spec.rb" => "lib/xyz.rb",
        "test/xyz_test.rb" => "lib/xyz.rb",
        "test/test_xyz.rb" => "lib/xyz.rb",
        "plugins/foo/test/lib/xyz_test.rb" => "plugins/foo/lib/xyz.rb",
        "plugins/foo/test/models/xyz_test.rb" => "plugins/foo/app/models/xyz.rb"
      }.each { |test, file| it_maps_path test, file, ignore }
    end

    it_maps_path "component/foo/test/public/models/xyz_test.rb", "component/foo/lib/public/models/xyz.rb", false
    it_maps_path "component/foo/test/public/models/xyz_test.rb", "component/foo/public/app/models/xyz.rb", true

    it "complains about files without test folder" do
      message = "oops_test.rb includes neither 'test' nor 'spec' folder ... unable to resolve"
      expect { file_under_test("oops_test.rb") }.to raise_error(RuntimeError, message)
    end

    it "complains about files without test extension" do
      message = "Unable to remove test extension from test/oops.rb ... /test_, _test.rb and _spec.rb are supported"
      expect { file_under_test("test/oops.rb") }.to raise_error(RuntimeError, message)
    end
  end

  # covering a weird edge case where the test folder is not part of the root directory because
  # a nested gemfile was used which changed Bundler.root
  describe ".guess_and_check_covered_file" do
    it "complains nicely when calling file is outside of root" do
      expect(SingleCov).to receive(:guess_covered_file).and_return('/oops/foo.rb')
      expect do
        SingleCov.send(:ensure_covered_file, nil)
      end.to raise_error(RuntimeError, /Found file \/oops\/foo.rb which is not relative to the root/)
    end
  end

  describe ".root" do
    it "ignores when bundler root is in a gemfiles folder" do
      old = SingleCov.send(:root)
      SingleCov.instance_variable_set(:@root, nil)
      expect(Bundler).to receive(:root).and_return(Pathname.new("#{old}/gemfiles"))
      expect(SingleCov.send(:root)).to eq old
    ensure
      SingleCov.instance_variable_set(:@root, old)
    end
  end

  def sh(command, options = {})
    m = (Bundler.respond_to?(:with_unbundled_env) ? :with_unbundled_env : :with_clean_env)
    result = Bundler.send(m) { `#{command} #{"2>&1" unless options[:keep_output]}` }
    raise "#{options[:fail] ? "SUCCESS" : "FAIL"} #{command}\n#{result}" if $?.success? == !!options[:fail]
    result
  end

  def change_file(file, find, replace)
    old = File.read(file)
    raise "Did not find #{find} in:\n#{old}" unless new = old.dup.sub!(find, replace)
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

  def assert_specs_finished_normally(result, examples)
    expect(result).to include "#{examples} example#{'s' if examples != 1}, 0 failures"
  end
end
