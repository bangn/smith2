# -*- encoding: utf-8 -*-

require 'pathname'
require 'spec_helper'
require 'smith/config'

describe Smith::Config do

  before(:all) do
    @tmp_dir = Pathname.new(`mktemp -d`.strip)
    @cwd = Pathname.pwd
    @root = Pathname.new(__FILE__).parent.parent

    FileUtils.copy_file(@root.join('fixtures', 'smithrc'), @tmp_dir.join('.smithrc'))
    FileUtils.copy_file(@root.join('fixtures', 'smithrc'), @tmp_dir.join('.smithrc'))
    FileUtils.copy_file(@root.join('fixtures', 'smithrc.1'), @tmp_dir.join('.smithrc.1'))
    FileUtils.copy_file(@root.join('fixtures', 'smithrc.with.amqp'), @tmp_dir.join('smithrc.with.amqp'))
    Dir.chdir(@tmp_dir)
  end

  after(:all) do
    Dir.chdir(@cwd)
    @tmp_dir.rmtree
  end

  context "General" do

    before(:each) do
      FileUtils.copy_file(@root.join('fixtures', 'smithrc'), @tmp_dir.join('.smithrc'))
      ENV["SMITH_CONFIG"] = @tmp_dir.join('.smithrc').to_s
    end

    let(:config) { Smith::Config.new }

    it "Config file Path" do
      expect(config.path).to eq(@tmp_dir.join('.smithrc'))
    end

    it "Reload with default file." do
      expect(config.smith.timeout).to eq(4)

      FileUtils.copy_file(@root.join('fixtures', 'smithrc.1'), @tmp_dir.join('.smithrc'))
      config.reload
      expect(config.smith.timeout).to eq(5)
    end

    it "Reload with named file." do
      set_env_for_block("SMITH_CONFIG", '.smithrc.named') do
        FileUtils.copy_file(@root.join('fixtures', 'smithrc'), @tmp_dir.join('.smithrc.named'))
        config = Smith::Config.new

        expect(config.smith.timeout).to eq(4)

        FileUtils.copy_file(@root.join('fixtures', 'smithrc.1'), @tmp_dir.join('.smithrc.named'))
        config.reload
        expect(config.smith.timeout).to eq(5)
      end
    end

    it "work with a minial config file" do
      FileUtils.copy_file(@root.join('fixtures', 'smithrc.minimal'), @tmp_dir.join('.smithrc'))
      config.reload

      expect(config.path).to eq(@tmp_dir.join('.smithrc'))
      expect(config.agency.acl_directories).to eq([Pathname.new("/var/lib/smith/acls"), Pathname.new(__dir__).parent.parent.join('lib/smith/messaging/acl')])
      expect(config.agency.agent_directories).to eq([Pathname.new("/var/lib/smith/agents")])
    end

    it "Load from system directory"
  end

  context "Default config file" do

    before(:each) do
      FileUtils.copy_file(@root.join('fixtures', 'smithrc'), @tmp_dir.join('.smithrc'))
      ENV["SMITH_CONFIG"] = @tmp_dir.join('.smithrc').to_s
    end

    let(:config) { Smith::Config.new }

    it "raise an exception if the config can't be found" do
      expect do
        set_env_for_block("SMITH_CONFIG", '.smithrc.nonexistent') do
          Smith::Config.new
        end
      end.to raise_error(Smith::ConfigNotFoundError)
    end

    it 'agent' do
      agent = config.agent
      expect(config.agent.monitor).to eq(false)
      expect(config.agent.singleton).to eq(true)
      expect(config.agent.metadata).to eq("")
      expect(config.agent.prefetch).to eq(2)
    end

    it 'smith' do
      expect(config.smith.namespace).to eq('smith')
      expect(config.smith.timeout).to eq(4)
    end

    it 'eventmachine' do
      expect(config.eventmachine.epoll).to eq(true)
      expect(config.eventmachine.kqueue).to eq(false)
      expect(config.eventmachine.file_descriptors).to eq(131072)
    end

    it 'amqp default' do
      expect(config.amqp.exchange).to eq({:durable => true, :auto_delete => false})
      expect(config.amqp.queue).to eq(:durable => true, :auto_delete => false)
      expect(config.amqp.publish).to eq(:headers => {})
      expect(config.amqp.subscribe).to eq(:ack => true)
      expect(config.amqp.pop).to eq({:ack => true})
    end

    it 'amqp overriden' do
      set_env_for_block("SMITH_CONFIG", 'smithrc.with.amqp') do
        config = Smith::Config.new
        expect(config.amqp.exchange).to eq({:durable => true, :auto_delete => false})
        expect(config.amqp.queue).to eq(:durable => true, :auto_delete => false)
        expect(config.amqp.publish).to eq(:headers => {})
        expect(config.amqp.subscribe).to eq(:ack => false)
        expect(config.amqp.pop).to eq({:ack => false})
      end
    end

    it 'amqp.broker' do
      expect(config.amqp.broker.host).to eq("localhost")
      expect(config.amqp.broker.port).to eq(5672)
      expect(config.amqp.broker.user).to eq("guest")
      expect(config.amqp.broker.password).to eq("guest")
      expect(config.amqp.broker.vhost).to eq("/")
    end

    it 'vm' do
      expect(config.vm.agent_default).to eq('ruby')
      expect(config.vm.null_agent).to eq('/usr/local/ruby-2.1.0/bin/ruby')
    end

    it 'agency' do
      expect(config.agency.pid_directory).to eq(Pathname.new("/run/smith"))
      expect(config.agency.cache_directory).to eq(Pathname.new("/var/cache/smith"))
      expect(config.agency.acl_directories).to eq([Pathname.new("/var/lib/smith/acls"), Pathname.new(__dir__).parent.parent.join('lib/smith/messaging/acl')])
      expect(config.agency.agent_directories).to eq([Pathname.new("/var/lib/smith/agents")])
    end

    it 'logging' do
      expect(config.logging.trace).to eq(true)
      expect(config.logging.level).to eq('debug')
    end

    it 'appender' do
      expect(config.logging.appender.filename).to eq("/var/log/smith/smith.log")
      expect(config.logging.appender.type).to eq("RollingFile")
      expect(config.logging.appender.age).to eq("daily")
      expect(config.logging.appender.keep).to eq(100)
    end

    it 'raise an error when items are missing' do
      set_env_for_block('SMITH_CONFIG', Pathname.new(__dir__).parent.parent.join('config/smithrc.toml')) do
        expect {
          config = Smith::Config.get
        }.to raise_error(Smith::MissingConfigItemError)
      end
    end
  end

  context "Load using class method" do
    it "Default file" do
      set_env_for_block("SMITH_CONFIG", @tmp_dir.join('.smithrc')) do
        config = Smith::Config.new
        expect(config.path).to eq(@tmp_dir.join('.smithrc'))
        expect(config.smith.timeout).to eq(4)
      end
    end
  end
end
