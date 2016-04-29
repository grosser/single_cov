require 'bundler/setup'

$LOAD_PATH << File.expand_path('../../lib', __FILE__)

require 'single_cov'
root = File.expand_path("../../", __FILE__)
SingleCov.setup :minitest, root: root

require 'minitest/autorun'

SingleCov.covered!

require 'a'

describe A do
  it "does a" do
    assert A.new.a
  end
end
