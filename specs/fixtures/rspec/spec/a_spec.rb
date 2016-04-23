require 'bundler/setup'

$LOAD_PATH << File.expand_path('../../lib', __FILE__)

require 'single_cov'
SingleCov.setup :rspec

SingleCov.covered!

require 'a'

describe A do
  it "does a" do
    expect(A.new.a).to eq 1
  end
end
