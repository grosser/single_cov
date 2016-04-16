require "spec_helper"

describe SingleCov do
  it "has a VERSION" do
    SingleCov::VERSION.should =~ /^[\.\da-z]+$/
  end
end
