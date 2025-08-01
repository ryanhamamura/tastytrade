# frozen_string_literal: true

require "spec_helper"
require "tastytrade/cli"

RSpec.describe "Tastytrade::CLI positions command" do
  let(:cli) { Tastytrade::CLI.new }
  let(:output) { StringIO.new }
  let(:error_output) { StringIO.new }
  let(:mock_session) { instance_double(Tastytrade::Session, authenticated?: true) }
  let(:mock_account) do
    instance_double(
      Tastytrade::Models::Account,
      account_number: "5WX12345",
      nickname: "Main Account"
    )
  end

  before do
    # Capture stdout
    allow($stdout).to receive(:puts) { |msg| output.puts(msg) }

    # Capture stderr more comprehensively
    original_stderr = $stderr
    allow($stderr).to receive(:puts) { |msg| error_output.puts(msg) }
    allow($stderr).to receive(:print) { |msg| error_output.print(msg) }
    allow($stderr).to receive(:write) { |msg| error_output.write(msg) }

    # Capture Kernel.warn which is used by error/warning helpers
    allow(cli).to receive(:warn) do |msg|
      error_output.puts(msg)
    end

    # Mock CLI internals
    allow(cli).to receive(:current_session).and_return(mock_session)
    allow(cli).to receive(:current_account).and_return(mock_account)
    allow(cli).to receive(:exit)
    allow(cli).to receive(:options).and_return({})
  end

  describe "#positions" do
    context "when not authenticated" do
      before do
        allow(cli).to receive(:current_session).and_return(nil)
      end

      it "requires authentication" do
        allow(cli).to receive(:exit).with(1).and_raise(SystemExit.new(1))

        expect { cli.positions }.to raise_error(SystemExit)
        expect(error_output.string).to include("Error: You must be logged in to use this command.")
      end
    end

    context "with no positions" do
      before do
        allow(mock_account).to receive(:get_positions).and_return([])
      end

      it "displays warning message" do
        cli.positions
        expect(error_output.string).to include("Warning: No positions found")
      end

      it "displays fetching message" do
        cli.positions
        expect(output.string).to include("Fetching positions for account 5WX12345")
      end
    end

    context "with positions" do
      let(:position1) do
        instance_double(
          Tastytrade::Models::CurrentPosition,
          symbol: "AAPL",
          quantity: BigDecimal("100"),
          instrument_type: "Equity",
          average_open_price: BigDecimal("150.00"),
          close_price: BigDecimal("155.00"),
          unrealized_pnl: BigDecimal("500.00"),
          unrealized_pnl_percentage: BigDecimal("3.33"),
          option?: false,
          short?: false
        )
      end

      let(:position2) do
        instance_double(
          Tastytrade::Models::CurrentPosition,
          symbol: "MSFT",
          quantity: BigDecimal("50"),
          instrument_type: "Equity",
          average_open_price: BigDecimal("300.00"),
          close_price: BigDecimal("295.00"),
          unrealized_pnl: BigDecimal("-250.00"),
          unrealized_pnl_percentage: BigDecimal("-1.67"),
          option?: false,
          short?: false
        )
      end

      before do
        allow(mock_account).to receive(:get_positions).and_return([position1, position2])
      end

      it "displays positions in table format" do
        cli.positions
        output_str = output.string
        expect(output_str).to include("Symbol")
        expect(output_str).to include("Quantity")
        expect(output_str).to include("Type")
        expect(output_str).to include("Avg Price")
        expect(output_str).to include("Current Price")
        expect(output_str).to include("P/L")
        expect(output_str).to include("P/L %")
      end

      it "displays position data" do
        cli.positions
        output_str = output.string
        expect(output_str).to include("AAPL")
        expect(output_str).to include("100")
        expect(output_str).to include("Equity")
        expect(output_str).to include("$150.00")
        expect(output_str).to include("$155.00")
      end

      it "displays summary statistics" do
        cli.positions
        output_str = output.string
        expect(output_str).to include("Summary: 2 positions")
        expect(output_str).to include("Winners: 1, Losers: 1")
      end
    end

    context "with symbol filter" do
      before do
        allow(cli).to receive(:options).and_return({ symbol: "AAPL" })
      end

      it "passes symbol filter to get_positions" do
        expect(mock_account).to receive(:get_positions).with(
          mock_session,
          hash_including(symbol: "AAPL")
        ).and_return([])
        cli.positions
      end
    end

    context "with underlying symbol filter" do
      before do
        allow(cli).to receive(:options).and_return({ underlying_symbol: "SPY" })
      end

      it "passes underlying symbol filter to get_positions" do
        expect(mock_account).to receive(:get_positions).with(
          mock_session,
          hash_including(underlying_symbol: "SPY")
        ).and_return([])
        cli.positions
      end
    end

    context "with include_closed option" do
      before do
        allow(cli).to receive(:options).and_return({ include_closed: true })
      end

      it "passes include_closed flag to get_positions" do
        expect(mock_account).to receive(:get_positions).with(
          mock_session,
          hash_including(include_closed: true)
        ).and_return([])
        cli.positions
      end
    end

    context "with account option" do
      before do
        allow(cli).to receive(:options).and_return({ account: "5WX67890" })
        allow(Tastytrade::Models::Account).to receive(:get).and_return(mock_account)
      end

      it "fetches the specified account" do
        expect(Tastytrade::Models::Account).to receive(:get).with(mock_session, "5WX67890")
        allow(mock_account).to receive(:get_positions).and_return([])
        cli.positions
      end
    end

    context "on API error" do
      before do
        allow(mock_account).to receive(:get_positions).and_raise(
          Tastytrade::Error, "Network error"
        )
      end

      it "displays error message" do
        allow(cli).to receive(:exit).with(1).and_raise(SystemExit.new(1))

        expect { cli.positions }.to raise_error(SystemExit)
        expect(error_output.string).to include("Error: Failed to fetch positions: Network error")
      end

      it "exits with status 1" do
        expect(cli).to receive(:exit).with(1)
        cli.positions rescue SystemExit
      end
    end

    context "with short position" do
      let(:short_position) do
        instance_double(
          Tastytrade::Models::CurrentPosition,
          symbol: "TSLA",
          quantity: BigDecimal("50"),
          instrument_type: "Equity",
          average_open_price: BigDecimal("200.00"),
          close_price: BigDecimal("195.00"),
          unrealized_pnl: BigDecimal("250.00"),
          unrealized_pnl_percentage: BigDecimal("2.50"),
          option?: false,
          short?: true
        )
      end

      before do
        allow(mock_account).to receive(:get_positions).and_return([short_position])
      end

      it "displays negative quantity for short positions" do
        cli.positions
        output_str = output.string
        expect(output_str).to include("-50")
      end
    end

    context "with option position" do
      let(:option_position) do
        instance_double(
          Tastytrade::Models::CurrentPosition,
          symbol: "AAPL 240119C00150000",
          display_symbol: "AAPL 150C 1/19",
          quantity: BigDecimal("5"),
          instrument_type: "Option",
          average_open_price: BigDecimal("5.50"),
          close_price: BigDecimal("7.25"),
          unrealized_pnl: BigDecimal("875.00"),
          unrealized_pnl_percentage: BigDecimal("31.82"),
          option?: true,
          short?: false
        )
      end

      before do
        allow(mock_account).to receive(:get_positions).and_return([option_position])
      end

      it "displays formatted option symbol" do
        cli.positions
        output_str = output.string
        # The table may truncate the symbol, so just check for the key parts
        expect(output_str).to match(/AAPL 150C/)
      end
    end
  end
end
