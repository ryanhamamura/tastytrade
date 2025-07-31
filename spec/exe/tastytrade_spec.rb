# frozen_string_literal: true

require "spec_helper"
require "open3"

RSpec.describe "tastytrade executable" do
  let(:exe_path) { File.expand_path("../../exe/tastytrade", __dir__) }

  def run_command(*args)
    cmd = [exe_path] + args
    stdout, stderr, status = Open3.capture3(*cmd)
    { stdout: stdout, stderr: stderr, status: status }
  end

  it "exists and is executable" do
    expect(File.exist?(exe_path)).to be true
    expect(File.executable?(exe_path)).to be true
  end

  describe "version command" do
    it "displays version information" do
      result = run_command("version")
      expect(result[:status].success?).to be true
      expect(result[:stdout]).to include("Tastytrade CLI v#{Tastytrade::VERSION}")
    end

    it "works with --version flag" do
      result = run_command("--version")
      expect(result[:status].success?).to be true
      expect(result[:stdout]).to include(Tastytrade::VERSION)
    end
  end

  describe "help command" do
    it "displays help information" do
      result = run_command("help")
      expect(result[:status].success?).to be true
      expect(result[:stdout]).to include("Tastytrade commands:")
      expect(result[:stdout]).to include("login")
      expect(result[:stdout]).to include("accounts")
      expect(result[:stdout]).to include("balance")
    end

    it "works with --help flag" do
      result = run_command("--help")
      expect(result[:status].success?).to be true
      expect(result[:stdout]).to include("Tastytrade commands:")
    end

    it "works with -h flag" do
      result = run_command("-h")
      expect(result[:status].success?).to be true
      expect(result[:stdout]).to include("Tastytrade commands:")
    end
  end

  describe "global options" do
    it "accepts --test flag" do
      result = run_command("help", "--test")
      expect(result[:status].success?).to be true
      expect(result[:stdout]).to include("Tastytrade commands:")
    end
  end

  describe "invalid commands" do
    it "shows error for unknown command" do
      result = run_command("invalid-command")
      expect(result[:status].success?).to be false
      expect(result[:stderr]).to include("Could not find command").or include("Unknown command")
    end
  end

  describe "command stubs" do
    it "has login command" do
      result = run_command("help", "login")
      expect(result[:status].success?).to be true
      expect(result[:stdout]).to include("Login to Tastytrade")
    end

    it "has accounts command" do
      result = run_command("help", "accounts")
      expect(result[:status].success?).to be true
      expect(result[:stdout]).to include("List all accounts")
    end

    it "has select command" do
      result = run_command("help", "select")
      expect(result[:status].success?).to be true
      expect(result[:stdout]).to include("Select an account to use")
    end

    it "has logout command" do
      result = run_command("help", "logout")
      expect(result[:status].success?).to be true
      expect(result[:stdout]).to include("Logout from Tastytrade")
    end

    it "has balance command" do
      result = run_command("help", "balance")
      expect(result[:status].success?).to be true
      expect(result[:stdout]).to include("Display account balance")
    end
  end
end
