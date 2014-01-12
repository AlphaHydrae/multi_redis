require 'helper'

describe MultiRedis::Data do

  it "should start empty" do
    expect(subject).to be_empty
  end

  it "should be a hash" do
    expect(subject).to be_a_kind_of(Hash)
  end

  it "should behave like an open structure" do

    expect(subject.foo).to be_nil
    expect(subject.foo = 'bar').to eq('bar')
    expect(subject.foo).to eq('bar')
    expect(subject[:foo]).to eq('bar')

    subject[:baz] = 'qux'
    expect(subject.baz).to eq('qux')
  end

  it "should not allow existing methods to be overriden" do
    expect{ subject.to_s = 'foo' }.to raise_error(ArgumentError, "Cannot set property to_s, method #to_s already exists")
  end

  it "should still fail for unknown methods" do
    expect{ subject.foo 'bar' }.to raise_error(NoMethodError)
    expect{ subject.send :baz=, :ham, :eggs }.to raise_error(NoMethodError)
  end
end
