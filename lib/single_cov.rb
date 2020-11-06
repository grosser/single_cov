# frozen_string_literal: true
module SingleCov
  COVERAGES = []
  MAX_OUTPUT = 40
  RAILS_APP_FOLDERS = ["models", "serializers", "helpers", "controllers", "mailers", "views", "jobs", "channels"]
  UNCOVERED_COMMENT_MARKER = /#.*uncovered/

  class << self
    # enable coverage reporting: path to output file, changed by forking-test-runner at runtime to combine many reports
    attr_accessor :coverage_report

    # emit only line coverage in coverage report for older coverage systems
    attr_accessor :coverage_report_lines

    # optionally rewrite the matching path single-cov guessed with a lambda
    def rewrite(&block)
      @rewrite = block
    end

    # mark a test file as not covering anything to make assert_used pass
    def not_covered!
      main_process!
    end

    # mark the file under test as needing coverage
    def covered!(file: nil, uncovered: 0)
      file = ensure_covered_file(file)
      COVERAGES << [file, uncovered]
      main_process!
    end

    def all_covered?(result)
      errors = COVERAGES.flat_map do |file, expected_uncovered|
        next no_coverage_error(file) unless coverage = result["#{root}/#{file}"]

        uncovered = uncovered(coverage)
        next if uncovered.size == expected_uncovered

        # ignore lines that are marked as uncovered via comments
        # TODO: warn when using uncovered but the section is indeed covered
        content = File.readlines(file)
        uncovered.reject! do |line_start, _, _, _|
          content[line_start - 1].match?(UNCOVERED_COMMENT_MARKER)
        end
        next if uncovered.size == expected_uncovered

        bad_coverage_error(file, expected_uncovered, uncovered)
      end.compact

      return true if errors.empty?

      errors[MAX_OUTPUT..-1] = "... coverage output truncated" if errors.size >= MAX_OUTPUT
      warn errors

      errors.all? { |l| warning?(l) }
    end

    def assert_used(tests: default_tests)
      bad = tests.select do |file|
        File.read(file) !~ /SingleCov.(not_)?covered!/
      end
      unless bad.empty?
        raise bad.map { |f| "#{f}: needs to use SingleCov.covered!" }.join("\n")
      end
    end

    def assert_tested(files: glob('{app,lib}/**/*.rb'), tests: default_tests, untested: [])
      missing = files - tests.map { |t| guess_covered_file(t) }
      fixed = untested - missing
      missing -= untested

      if fixed.any?
        raise "Remove #{fixed.inspect} from untested!"
      elsif missing.any?
        raise missing.map { |f| "missing test for #{f}" }.join("\n")
      end
    end

    def setup(framework, root: nil, branches: true)
      if defined?(SimpleCov)
        raise "Load SimpleCov after SingleCov"
      end

      @branches = branches
      @root = root

      case framework
      when :minitest
        minitest_should_not_be_running!
        return if minitest_running_subset_of_tests?
      when :rspec
        return if rspec_running_subset_of_tests?
      else
        raise "Unsupported framework #{framework.inspect}"
      end

      start_coverage_recording

      override_at_exit do |status, _exception|
        if enabled? && main_process? && status == 0
          results = coverage_results
          generate_report results
          exit 1 unless SingleCov.all_covered?(results)
        end
      end
    end

    # use this in forks when using rspec to silence duplicated output
    def disable
      @disabled = true
    end

    private

    def uncovered(coverage)
      return coverage unless coverage.is_a?(Hash) # just lines

      # [nil, 1, 0, 1, 0] -> [3, 5]
      uncovered_lines = coverage.fetch(:lines)
        .each_with_index
        .select { |c, _| c == 0 }
        .map { |_, i| i + 1 }
        .compact

      uncovered_branches = uncovered_branches(coverage[:branches] || {})
      uncovered_branches.reject! { |k| uncovered_lines.include?(k[0]) } # remove duplicates

      all = uncovered_lines.concat uncovered_branches
      all.sort_by! { |line_start, char_start, _, _| [line_start, char_start || 0] } # branches are unsorted
      all
    end

    def enabled?
      (!defined?(@disabled) || !@disabled)
    end

    # assuming that the main process will load all the files, we store it's pid
    def main_process!
      @main_process_pid = Process.pid
    end

    def main_process?
      (!defined?(@main_process_pid) || @main_process_pid == Process.pid)
    end

    def uncovered_branches(coverage)
      # {[branch_id] => {[branch_part] => coverage}} --> {branch_part -> sum-of-coverage}
      sum = Hash.new(0)
      coverage.each_value do |branch|
        branch.each do |k, v|
          sum[k.slice(2, 4)] += v
        end
      end

      sum.select! { |_, v| v == 0 } # keep missing coverage
      found = sum.map { |k, _| [k[0], k[1] + 1, k[2], k[3] + 1] }
      found.uniq!
      found
    end

    def default_tests
      glob("{test,spec}/**/*_{test,spec}.rb")
    end

    def glob(pattern)
      Dir["#{root}/#{pattern}"].map! { |f| f.sub("#{root}/", '') }
    end

    # do not ask for coverage when SimpleCov already does or it conflicts
    def coverage_results
      if defined?(SimpleCov) && (result = SimpleCov.instance_variable_get(:@result))
        result = result.original_result
        # singlecov 1.18+ puts string "lines" into the result that we cannot read
        if result.each_value.first.is_a?(Hash)
          result = result.transform_values { |v| v.transform_keys(&:to_sym) }
        end
        result
      else
        Coverage.result
      end
    end

    # start recording before classes are loaded or nothing can be recorded
    # SimpleCov might start coverage again, but that does not hurt ...
    def start_coverage_recording
      require 'coverage'
      if @branches
        Coverage.start(lines: true, branches: true)
      else
        Coverage.start(lines: true)
      end
    end

    # not running rake or a whole folder
    def running_single_file?
      COVERAGES.size == 1
    end

    # we cannot insert our hooks when minitest is already running
    def minitest_should_not_be_running!
      return unless defined?(Minitest)
      return unless Minitest.class_variable_defined?(:@@installed_at_exit)
      return unless Minitest.class_variable_get(:@@installed_at_exit)

      # untested
      # https://github.com/rails/rails/pull/26515 rails loads autorun before test
      # but it works out for some reason
      return if Minitest.extensions.include?('rails')

      # untested
      # forking test runner does some hacky acrobatics to fake minitest status
      # and the resets it ... works out ok in the end ...
      return if faked_by_forking_test_runner?

      # ... but only if it's used with `--merge-coverage` otherwise the coverage reporting is useless
      if $0.end_with?("/forking-test-runner")
        raise "forking-test-runner only work with single_cov when using --merge-coverage"
      end

      raise "Load minitest after setting up SingleCov"
    end

    # ForkingTestRunner fakes an initialized minitest to avoid multiple hooks being installed
    # so hooks still get added in order https://github.com/grosser/forking_test_runner/pull/4
    def faked_by_forking_test_runner?
      defined?(Coverage) && Coverage.respond_to?(:capture_coverage!)
    end

    # do not record or verify when only running selected tests since it would be missing data
    def minitest_running_subset_of_tests?
      # via direct option (ruby test.rb -n /foo/)
      (ARGV.map { |a| a.split('=', 2).first } & ['-n', '--name', '-l', '--line']).any? ||

      # via testrbl or mtest or rails with direct line number (mtest test.rb:123)
      (ARGV.first =~ /:\d+\Z/) ||

      # via rails test which preloads mintest, removes ARGV and fills options
      (
        defined?(Minitest) &&
        defined?(Minitest.reporter) &&
        Minitest.reporter &&
        (reporter = Minitest.reporter.reporters.first) &&
        reporter.options[:filter]
      )
    end

    def rspec_running_subset_of_tests?
      (ARGV & ['-t', '--tag', '-e', '--example']).any? || ARGV.any? { |a| a =~ /:\d+$|\[[\d:]+\]$/ }
    end

    # code stolen from SimpleCov
    def override_at_exit
      at_exit do
        exit_status = if $! # was an exception thrown?
          # if it was a SystemExit, use the accompanying status
          # otherwise set a non-zero status representing termination by
          # some other exception (see github issue 41)
          $!.is_a?(SystemExit) ? $!.status : 1
        else
          # Store the exit status of the test run since it goes away
          # after calling the at_exit proc...
          0
        end

        yield exit_status, $!

        # Force exit with stored status (see github issue #5)
        # unless it's nil or 0 (see github issue #281)
        Kernel.exit exit_status if exit_status && exit_status > 0
      end
    end

    def ensure_covered_file(file)
      raise "Use paths relative to project root." if file&.start_with?("/")

      if file
        raise "#{file} does not exist, use paths relative to project root." unless File.exist?("#{root}/#{file}")
      else
        file = guess_covered_file(caller[1])
        if file.start_with?("/")
          raise "Found file #{file} which is not relative to the root #{root}.\nUse `SingleCov.covered! file: 'target_file.rb'` to set covered file location."
        elsif !File.exist?("#{root}/#{file}")
          raise "Tried to guess covered file as #{file}, but it does not exist.\nUse `SingleCov.covered! file: 'target_file.rb'` to set covered file location."
        end
      end

      file
    end

    def bad_coverage_error(file, expected_uncovered, uncovered)
      details = "(#{uncovered.size} current vs #{expected_uncovered} configured)"
      if expected_uncovered > uncovered.size
        if running_single_file?
          warning "#{file} has less uncovered lines #{details}, decrement configured uncovered"
        end
      else
        [
          "#{file} new uncovered lines introduced #{details}",
          red("Lines missing coverage:"),
          *uncovered.map do |line_start, char_start, line_end, char_end|
            if char_start # branch coverage
              if line_start == line_end
                "#{file}:#{line_start}:#{char_start}-#{char_end}"
              else # possibly unreachable since branches always seem to be on the same line
                "#{file}:#{line_start}:#{char_start}-#{line_end}:#{char_end}"
              end
            else
              "#{file}:#{line_start}"
            end
          end
        ]
      end
    end

    def warning(msg)
      "#{msg}?"
    end

    def warning?(msg)
      msg.end_with?("?")
    end

    def red(text)
      if $stdin.tty?
        "\e[31m#{text}\e[0m"
      else
        text
      end
    end

    def no_coverage_error(file)
      if $LOADED_FEATURES.include?("#{root}/#{file}")
        # we cannot enforce $LOADED_FEATURES during covered! since it would fail when multiple files are loaded
        "#{file} was expected to be covered, but was already loaded before coverage started, which makes it uncoverable."
      else
        "#{file} was expected to be covered, but was never loaded."
      end
    end

    def guess_covered_file(test)
      file = test.dup

      # remove caller junk to get nice error messages when something fails
      file.sub!(/\.rb\b.*/, '.rb')

      # resolve all kinds of relativity
      file = File.expand_path(file)

      # remove project root
      file.sub!("#{root}/", '')

      # preserve subfolders like foobar/test/xxx_test.rb -> foobar/lib/xxx_test.rb
      subfolder, file_part = file.split(%r{(?:^|/)(?:test|spec)/}, 2)
      unless file_part
        raise "#{file} includes neither 'test' nor 'spec' folder ... unable to resolve"
      end

      # rails things live in app
      file_part[0...0] = if file_part =~ /^(?:#{RAILS_APP_FOLDERS.map { |f| Regexp.escape(f) }.join('|')})\//
        "app/"
      elsif file_part.start_with?("lib/") # don't add lib twice
        ""
      else # everything else lives in lib
        "lib/"
      end

      # remove test extension
      if !file_part.sub!(/_(?:test|spec)\.rb\b.*/, '.rb') && !file_part.sub!(/\/test_/, "/")
        raise "Unable to remove test extension from #{file} ... /test_, _test.rb and _spec.rb are supported"
      end

      # put back the subfolder
      file_part[0...0] = "#{subfolder}/" unless subfolder.empty?

      file_part = @rewrite.call(file_part) if defined?(@rewrite) && @rewrite

      file_part
    end

    def root
      @root ||= (defined?(Bundler) && Bundler.root.to_s.sub(/\/gemfiles$/, '')) || Dir.pwd
    end

    def generate_report(results)
      return unless report = coverage_report

      # not a hard dependency for the whole library
      require "json"
      require "fileutils"

      used = COVERAGES.map { |f, _| "#{root}/#{f}" }
      covered = results.select { |k, _| used.include?(k) }

      if coverage_report_lines
        covered = covered.transform_values { |v| v.is_a?(Hash) ? v.fetch(:lines) : v }
      end

      # chose "Minitest" because it is what simplecov uses for reports and "Unit Tests" makes sonarqube break
      data = JSON.pretty_generate(
        "Minitest" => { "coverage" => covered, "timestamp" => Time.now.to_i }
      )
      FileUtils.mkdir_p(File.dirname(report))
      File.write report, data
    end
  end
end
