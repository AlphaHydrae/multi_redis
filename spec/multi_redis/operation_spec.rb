require 'helper'

describe MultiRedis::Operation do
  Step ||= MultiRedis::Step
  Future ||= MultiRedis::Future
  Executor ||= MultiRedis::Executor

  before :each do
    Step.stub(:new){ |*args| args }
  end

  it "should define steps" do
    
    blocks = Array.new(6){ |i| lambda{} }

    op = described_class.new do 
      run &blocks[0]
      pipelined &blocks[1]
    end

    op.configure do
      multi &blocks[2]
      pipelined &blocks[3]
    end

    op.add :multi, &blocks[4]
    op.add :multi, &blocks[5]

    expect(op.steps).to have(6).items
    expect(op.steps[0]).to eq([ op, :call, blocks[0] ])
    expect(op.steps[1]).to eq([ op, :pipelined, blocks[1] ])
    expect(op.steps[2]).to eq([ op, :multi, blocks[2] ])
    expect(op.steps[3]).to eq([ op, :pipelined, blocks[3] ])
    expect(op.steps[4]).to eq([ op, :multi, blocks[4] ])
    expect(op.steps[5]).to eq([ op, :multi, blocks[5] ])
  end

  it "should allow the target to be set through options" do

    target = Object.new
    blocks = Array.new(3){ |i| lambda{} }
    op = described_class.new target: target do
      run &blocks[0]
      pipelined &blocks[1]
      multi &blocks[2]
    end

    expect(op.steps).to have(3).items
    expect(op.steps[0]).to eq([ target, :call, blocks[0] ])
    expect(op.steps[1]).to eq([ target, :pipelined, blocks[1] ])
    expect(op.steps[2]).to eq([ target, :multi, blocks[2] ])
  end

  describe "#add" do

    it "should refuse unknown types" do
      expect{ subject.add :foo, &lambda{} }.to raise_error(ArgumentError, "Unknown type foo, must be one of call, pipelined, multi.")
    end
  end

  describe "#execute" do
    let(:result){ double }
    let(:executor){ double add: nil, execute: [ result ] }
    let(:executing){ false }
    let(:future){ double }

    before :each do
      Executor.stub new: executor unless executing
      MultiRedis.stub executing?: executing
      Future.stub new: future
    end

    it "should execute the operation through an executor" do

      expect(Executor).to receive(:new).with(redis: nil)
      expect(executor).to receive(:add).with(subject, :foo, :bar)
      expect(Future).to receive(:new).with(result)

      expect(subject.execute(:foo, :bar)).to be(result)
      expect(subject.future).to be(future)
    end

    describe "in a multi redis execution block" do
      let(:executing){ true }

      before :each do
        MultiRedis.stub executor: executor
      end

      it "should add the operation to the multi redis executor" do

        expect(executor).to receive(:add).with(subject, :baz, :qux)
        expect(Future).to receive(:new).with(no_args)

        expect(subject.execute(:baz, :qux)).to be(future)
        expect(subject.future).to be(future)
      end
    end
  end

  describe "redis client" do
    let(:redis){ double }

    it "should be configurable through options" do
      expect(described_class.new(redis: redis).redis).to be(redis)
    end

    it "should be configurable through an accessor" do
      subject.redis = redis
      expect(subject.redis).to eq(redis)
    end
  end
end
