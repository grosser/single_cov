# frozen_string_literal: true
require 'bundler/setup'

$LOAD_PATH << File.expand_path('../lib', __dir__)

require 'single_cov'
root = File.expand_path('..', __dir__)
SingleCov.setup :rspec, root: root

SingleCov.covered!

require 'a'

describe A do
  it "does a" do
    expect(A.new.a).to eq 1
  end

  2.times do
    it "does i" do
      expect(1).to eq 1
    end
  end
end
