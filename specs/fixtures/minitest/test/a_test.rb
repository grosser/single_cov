# frozen_string_literal: true
require 'bundler/setup'

$LOAD_PATH << File.expand_path('../lib', __dir__)
$VERBOSE = true

require 'single_cov'
root = File.expand_path('..', __dir__)
SingleCov.setup :minitest, root: root

require 'minitest/autorun'

SingleCov.covered!

require 'a'

describe A do
  it "does a" do
    fork {} # rubocop:disable Lint/EmptyBlock

    assert A.new.a
  end
end
