
describe MultiRedis::Future do

  describe "#value" do

    it "should raise an error if the value has not yet been set" do
      expect{ subject.value }.to raise_error(MultiRedis::FutureNotReady, "Value will be available once the operation executes.")
    end

    it "should return the value once set" do
      subject.value = 'foo'
      expect(subject.value).to eq('foo')
    end
  end
end
