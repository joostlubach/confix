require 'spec_helper'
require 'confix'

# TODO: Spec fetch

describe Confix do

  class TestConfig
    include Confix

    setting :one
    config :two do
      setting :three
      config :four do
        setting :five, 'five'
      end
    end

    template :six do
      setting :eight
    end
    config :six
    config :seven, :six do
      setting :nine
    end

  end

  before { @config = TestConfig.new }
  subject { @config }

  specify { @config.class.settings.should == [ 'one' ] }
  specify { @config.class.configs['two'].should < Confix::Config }
  specify { @config.class.configs['two'].settings.should == [ 'three' ] }
  specify { @config.class.configs['two'].configs['four'].should < Confix::Config }

  context 'when setting a basic setting' do

    it 'should be accessible by method' do
      @config.one = 'Hello'
      @config.one.should == 'Hello'
      @config[:one].should == 'Hello'
      @config['one'].should == 'Hello'
    end

    it 'should be accessible by symbol' do
      @config[:one] = 'Hello'
      @config.one.should == 'Hello'
      @config[:one].should == 'Hello'
      @config['one'].should == 'Hello'
    end

    it 'should be accessible by string' do
      @config['one'] = 'Hello'
      @config.one.should == 'Hello'
      @config[:one].should == 'Hello'
      @config['one'].should == 'Hello'
    end

    it 'should not accept an undefined setting' do
      -> { @config['four'] = 'Test' }.should raise_error(Confix::UndefinedSetting)
    end

  end

  context 'when accessing an intermediate config' do

    it 'should return a Confix::Config object by method' do
      @config.two.should be_a(Confix::Config)
    end

    it 'should all be the same' do
      @config.two.should be(@config[:two])
      @config.two.should be(@config['two'])
    end

    it 'should return a Confix::Config object within a child' do
      @config.two.four.should be_a(Confix::Config)
    end

    it 'should raise CannotModifyConfiguration when trying to set it' do
      -> { @config['two'] = 'Hallo' }.should raise_error(Confix::CannotModifyConfiguration)
    end

  end

  context 'when accessing a setting in a child object' do

    it 'should be accessible by method' do
      @config.two.three = 'Hello'
      @config.two.three.should == 'Hello'
      @config[:two].three.should == 'Hello'
      @config['two'].three.should == 'Hello'
    end

    it 'should be accessible by symbol' do
      @config[:two].three = 'Hello'
      @config.two.three.should == 'Hello'
      @config[:two].three.should == 'Hello'
      @config['two'].three.should == 'Hello'
    end

    it 'should be accessible by string' do
      @config['two'].three = 'Hello'
      @config.two.three.should == 'Hello'
      @config[:two].three.should == 'Hello'
      @config['two'].three.should == 'Hello'
    end

  end

  context 'when using root indexers' do

    it 'should access a root level setting' do
      @config.one = 'Hello'
      @config['one'].should == 'Hello'
    end

    it 'should access a level-1 setting' do
      @config.two.three = 'Hello2'
      @config['two.three'].should == 'Hello2'
    end

    it 'should access a level-2 setting' do
      @config.two.four.five = 'Hello3'
      @config['two.four.five'].should == 'Hello3'
    end

    it 'should not accept an undefined setting' do
      -> { @config['two.five'] = 'Test' }.should raise_error(Confix::UndefinedSetting)
    end

  end

  describe 'values method' do

    before {
      @config.one = 'One'
      @config.two.three = 'Three'
      @config.two.four.five = 'Five'
    }

    it "should report all values from the root" do
      @config.values.should == { 'one' => 'One', 'two.three' => 'Three', 'two.four.five' => 'Five' }
    end

  end

  describe 'defaults' do
    specify { @config.two.four.five.should == 'five' }
  end

  describe 'to_hash method' do

    before {
      @config.one = 'One'
      @config.two.three = 'Three'
      @config.two.four.five = 'Five'
    }

    it "should create a hash recursively" do
      @config.to_hash.should == {"one"=>"One", "two"=>{"three"=>"Three", "four"=>{"five"=>"Five"}}, "six"=>{"eight"=>nil}, "seven"=>{"eight"=>nil, "nine"=>nil}}
    end
    it "should create a hash recursively from any level" do
      @config.two.to_hash.should == {"three"=>"Three", "four"=>{"five"=>"Five"}}
    end

  end

  it "should allow setting a child configuration" do
    @config.two.four = { :five => 'Five' }
    @config.two = { :three => 'Three' }

    @config.two.to_hash.should == {"three"=>"Three", "four"=>{"five"=>"Five"}}
  end

  describe 'assigns' do
    it "should use the assigns hash for any string setting" do
      @config.assigns[:my_var] = 'test'
      @config.one = 'Setting %{my_var}'
      @config.one.should == 'Setting test'
    end
  end

  describe 'templates' do

    it "should apply template :six to config :six as no block was given" do
      @config.six.should respond_to(:eight)
    end
    it "should apply template :six to config :seven as it was explicitly mentioned" do
      @config.seven.should respond_to(:eight)
    end
    it "should also apply the given block" do
      @config.seven.should respond_to(:nine)
    end

  end

end