package main

import (
	"bufio"
	"context"
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/ryanhamamura/tastytrade/pkg/tastytrade"
)

// Global variables
var (
	client        *tastytrade.Client
	ctx           context.Context
	cancel        context.CancelFunc
	accountNumber string
	accounts      []tastytrade.Account
	reader        *bufio.Reader
)

func main() {
	// Initialize
	reader = bufio.NewReader(os.Stdin)
	ctx, cancel = context.WithCancel(context.Background())
	defer cancel()

	// Create client with debug mode
	client = tastytrade.NewClient(false, tastytrade.WithDebug(true))

	fmt.Println("=== TastyTrade API CLI ===")
	fmt.Println("This tool allows you to interact with the TastyTrade API")

	// Main loop
	authenticated := false
	for {
		if !authenticated {
			authenticated = authenticate()
			if !authenticated {
				fmt.Println("Authentication failed. Try again.")
				continue
			}
			loadAccounts()
		}

		// Display main menu
		fmt.Println("\n=== Main Menu ===")
		fmt.Println("1. Account Information")
		fmt.Println("2. Market Data")
		fmt.Println("3. Order Placement")
		fmt.Println("4. Order Management")
		fmt.Println("5. Position Management")
		fmt.Println("0. Exit")
		fmt.Print("Select an option: ")

		choice := readLine()
		switch choice {
		case "1":
			accountMenu()
		case "2":
			marketDataMenu()
		case "3":
			orderPlacementMenu()
		case "4":
			orderManagementMenu()
		case "5":
			positionManagementMenu()
		case "0":
			fmt.Println("Exiting...")
			return
		default:
			fmt.Println("Invalid option. Please try again.")
		}
	}
}

// readLine reads a line from stdin and trims spaces
func readLine() string {
	line, _ := reader.ReadString('\n')
	return strings.TrimSpace(line)
}

// authenticate performs login to TastyTrade
func authenticate() bool {
	fmt.Print("Enter username: ")
	username := readLine()

	fmt.Print("Enter password: ")
	password := readLine()

	fmt.Println("Authenticating...")
	err := client.Login(ctx, username, password)
	if err != nil {
		fmt.Printf("Login failed: %v\n", err)
		return false
	}

	fmt.Println("Authentication successful")
	return true
}

// loadAccounts loads user accounts
func loadAccounts() {
	fmt.Println("Loading accounts...")
	var err error
	accounts, err = client.GetAccounts(ctx)
	if err != nil {
		fmt.Printf("Failed to load accounts: %v\n", err)
		return
	}

	// Display accounts and select one
	fmt.Println("\nAvailable accounts:")
	for i, account := range accounts {
		fmt.Printf("%d. %s (%s)\n", i+1, account.Name, account.AccountNumber)
	}

	if len(accounts) == 1 {
		accountNumber = accounts[0].AccountNumber
		fmt.Printf("Selected account: %s\n", accountNumber)
	} else if len(accounts) > 1 {
		fmt.Print("Select account number (1-" + strconv.Itoa(len(accounts)) + "): ")
		choice := readLine()
		index, err := strconv.Atoi(choice)
		if err != nil || index < 1 || index > len(accounts) {
			fmt.Println("Invalid selection. Using first account.")
			accountNumber = accounts[0].AccountNumber
		} else {
			accountNumber = accounts[index-1].AccountNumber
		}
		fmt.Printf("Selected account: %s\n", accountNumber)
	} else {
		fmt.Println("No accounts found.")
	}
}

// accountMenu displays account-related options
func accountMenu() {
	for {
		fmt.Println("\n=== Account Menu ===")
		fmt.Println("1. Account Details")
		fmt.Println("2. Account Balances")
		fmt.Println("3. Select Different Account")
		fmt.Println("0. Back to Main Menu")
		fmt.Print("Select an option: ")

		choice := readLine()
		switch choice {
		case "1":
			displayAccountDetails()
		case "2":
			displayAccountBalances()
		case "3":
			loadAccounts()
		case "0":
			return
		default:
			fmt.Println("Invalid option. Please try again.")
		}
	}
}

// displayAccountDetails shows details of the selected account
func displayAccountDetails() {
	if accountNumber == "" {
		fmt.Println("No account selected.")
		return
	}

	// Find the account in the list
	var account tastytrade.Account
	found := false
	for _, acc := range accounts {
		if acc.AccountNumber == accountNumber {
			account = acc
			found = true
			break
		}
	}

	if !found {
		fmt.Println("Account not found.")
		return
	}

	fmt.Println("\n=== Account Details ===")
	fmt.Printf("Account Number: %s\n", account.AccountNumber)
	fmt.Printf("Name: %s\n", account.Name)
	fmt.Printf("Account Type: %s\n", account.AccountType)
	fmt.Printf("Is Margin: %v\n", account.IsMargin)
	fmt.Printf("Is Funded: %v\n", account.IsFunded)
	fmt.Printf("Option Level: %s\n", account.OptionLevel)
	fmt.Printf("Futures Enabled: %v\n", account.Futures)
	fmt.Printf("Cryptos Enabled: %v\n", account.Cryptos)
	fmt.Printf("Equities Enabled: %v\n", account.Equities)
	fmt.Printf("Day Trader Status: %v\n", account.DayTrader)
}

// displayAccountBalances shows the balances of the selected account
func displayAccountBalances() {
	if accountNumber == "" {
		fmt.Println("No account selected.")
		return
	}

	balances, err := client.GetBalances(ctx, accountNumber)
	if err != nil {
		fmt.Printf("Failed to get balances: %v\n", err)
		return
	}

	fmt.Println("\n=== Account Balances ===")
	fmt.Printf("Net Liquidation Value: $%.2f\n", balances.NetLiq)
	fmt.Printf("Buying Power: $%.2f\n", balances.BuyingPower)
	fmt.Printf("Cash: $%.2f\n", balances.Cash)
	fmt.Printf("Long Stock Value: $%.2f\n", balances.LongStockValue)
	fmt.Printf("Short Stock Value: $%.2f\n", balances.ShortStockValue)
	fmt.Printf("Long Option Value: $%.2f\n", balances.LongOptionValue)
	fmt.Printf("Short Option Value: $%.2f\n", balances.ShortOptionValue)
	fmt.Printf("Maintenance Requirement: $%.2f\n", balances.MaintenanceRequirement)
}

// marketDataMenu displays market data options
func marketDataMenu() {
	for {
		fmt.Println("\n=== Market Data Menu ===")
		fmt.Println("1. Get Quotes")
		fmt.Println("2. Get Option Chain")
		fmt.Println("3. Get Equity Details")
		fmt.Println("0. Back to Main Menu")
		fmt.Print("Select an option: ")

		choice := readLine()
		switch choice {
		case "1":
			getQuotes()
		case "2":
			getOptionChain()
		case "3":
			getEquityDetails()
		case "0":
			return
		default:
			fmt.Println("Invalid option. Please try again.")
		}
	}
}

// getQuotes gets and displays quotes for requested symbols
func getQuotes() {
	fmt.Print("Enter symbols (comma-separated): ")
	symbolsInput := readLine()
	symbolsList := strings.Split(symbolsInput, ",")

	// Trim spaces from symbols
	symbols := make([]string, 0, len(symbolsList))
	for _, symbol := range symbolsList {
		trimmed := strings.TrimSpace(symbol)
		if trimmed != "" {
			symbols = append(symbols, trimmed)
		}
	}

	if len(symbols) == 0 {
		fmt.Println("No valid symbols entered.")
		return
	}

	fmt.Printf("Getting quotes for: %s\n", strings.Join(symbols, ", "))
	quotes, err := client.GetQuotes(ctx, symbols)
	if err != nil {
		fmt.Printf("Failed to get quotes: %v\n", err)
		return
	}

	fmt.Println("\n=== Quotes ===")
	for symbol, quote := range quotes {
		fmt.Printf("\nSymbol: %s\n", symbol)
		fmt.Printf("Last Price: $%.2f\n", quote.LastPrice)
		fmt.Printf("Bid Price: $%.2f\n", quote.BidPrice)
		fmt.Printf("Ask Price: $%.2f\n", quote.AskPrice)
		fmt.Printf("Volume: %d\n", quote.Volume)
		fmt.Printf("Net Change: $%.2f (%.2f%%)\n", quote.NetChange, quote.PercentChange)
	}
}

// getOptionChain gets and displays an option chain for a symbol
func getOptionChain() {
	fmt.Print("Enter underlying symbol: ")
	symbol := readLine()

	if symbol == "" {
		fmt.Println("No symbol entered.")
		return
	}

	fmt.Printf("Getting option chain for: %s\n", symbol)
	chains, err := client.GetOptionChain(ctx, symbol)
	if err != nil {
		fmt.Printf("Failed to get option chain: %v\n", err)
		return
	}

	// Display expirations
	fmt.Println("\n=== Available Expirations ===")
	for i, chain := range chains {
		fmt.Printf("%d. %s\n", i+1, chain.ExpirationDate)
	}

	if len(chains) == 0 {
		fmt.Println("No expirations found.")
		return
	}

	fmt.Print("Select expiration (1-" + strconv.Itoa(len(chains)) + "): ")
	choice := readLine()
	index, err := strconv.Atoi(choice)
	if err != nil || index < 1 || index > len(chains) {
		fmt.Println("Invalid selection.")
		return
	}

	selectedChain := chains[index-1]
	fmt.Printf("\n=== Option Chain for %s Expiring %s ===\n", symbol, selectedChain.ExpirationDate)
	fmt.Println("Strike   | Call Bid/Ask      | Put Bid/Ask")
	fmt.Println("--------|-------------------|------------------")

	// Display a subset of calls and puts (near the money)
	callsDisplayed := 0
	for i := 0; i < len(selectedChain.Calls) && i < len(selectedChain.Puts) && callsDisplayed < 10; i++ {
		call := selectedChain.Calls[i]
		put := selectedChain.Puts[i]

		fmt.Printf("$%-7.2f | $%-7.2f / $%-7.2f | $%-7.2f / $%-7.2f\n",
			call.StrikePrice,
			call.BidPrice, call.AskPrice,
			put.BidPrice, put.AskPrice)

		callsDisplayed++
	}
}

// getEquityDetails gets and displays details for an equity
func getEquityDetails() {
	fmt.Print("Enter equity symbol: ")
	symbol := readLine()

	if symbol == "" {
		fmt.Println("No symbol entered.")
		return
	}

	fmt.Printf("Getting equity details for: %s\n", symbol)

	// For this CLI demo, we'll just get a quote as a simplification
	quotes, err := client.GetQuotes(ctx, []string{symbol})
	if err != nil {
		fmt.Printf("Failed to get equity details: %v\n", err)
		return
	}

	quote, exists := quotes[symbol]
	if !exists {
		fmt.Println("Symbol not found.")
		return
	}

	fmt.Println("\n=== Equity Details ===")
	fmt.Printf("Symbol: %s\n", symbol)
	fmt.Printf("Last Price: $%.2f\n", quote.LastPrice)
	fmt.Printf("Bid/Ask: $%.2f / $%.2f\n", quote.BidPrice, quote.AskPrice)
	fmt.Printf("Day Range: $%.2f - $%.2f\n", quote.DayLow, quote.DayHigh)
	fmt.Printf("Volume: %d\n", quote.Volume)
	fmt.Printf("Open Price: $%.2f\n", quote.OpenPrice)
	fmt.Printf("Previous Close: $%.2f\n", quote.PreviousClose)
}

// orderPlacementMenu displays order placement options
func orderPlacementMenu() {
	for {
		fmt.Println("\n=== Order Placement Menu ===")
		fmt.Println("1. Place Equity Market Order")
		fmt.Println("2. Place Equity Limit Order")
		fmt.Println("3. Place Notional Market Order (Fractional Shares)")
		fmt.Println("4. Place Stop Limit Order")
		fmt.Println("5. Place Option Order")
		fmt.Println("0. Back to Main Menu")
		fmt.Print("Select an option: ")

		choice := readLine()
		switch choice {
		case "1":
			placeEquityMarketOrder()
		case "2":
			placeEquityLimitOrder()
		case "3":
			placeNotionalMarketOrder()
		case "4":
			placeStopLimitOrder()
		case "5":
			placeOptionOrder()
		case "0":
			return
		default:
			fmt.Println("Invalid option. Please try again.")
		}
	}
}

// placeEquityMarketOrder places a market order for an equity
func placeEquityMarketOrder() {
	if accountNumber == "" {
		fmt.Println("No account selected.")
		return
	}

	fmt.Print("Enter symbol: ")
	symbol := readLine()

	fmt.Print("Enter quantity: ")
	quantityStr := readLine()
	quantity, err := strconv.ParseFloat(quantityStr, 64)
	if err != nil || quantity <= 0 {
		fmt.Println("Invalid quantity.")
		return
	}

	fmt.Print("Buy or Sell? (buy/sell): ")
	action := readLine()
	var orderDirection tastytrade.OrderDirection
	if strings.ToLower(action) == "buy" {
		orderDirection = tastytrade.OrderDirectionBuyToOpen
	} else if strings.ToLower(action) == "sell" {
		orderDirection = tastytrade.OrderDirectionSellToOpen
	} else {
		fmt.Println("Invalid action.")
		return
	}

	// Confirm the order
	fmt.Printf("\nYou are about to place a market order to %s %.2f shares of %s\n",
		strings.ToLower(action), quantity, symbol)
	fmt.Print("Confirm? (yes/no): ")
	confirm := readLine()
	if strings.ToLower(confirm) != "yes" {
		fmt.Println("Order cancelled.")
		return
	}

	// Place the order (dry run first)
	dryRunCtx, cancel := context.WithTimeout(ctx, 10*time.Second)
	defer cancel()

	// Create order request
	qty := quantity
	order := tastytrade.OrderRequest{
		OrderType:   tastytrade.OrderTypeMarket,
		TimeInForce: tastytrade.TimeInForceDay,
		Legs: []tastytrade.OrderLeg{
			{
				Symbol:         symbol,
				Quantity:       &qty,
				Action:         orderDirection,
				InstrumentType: tastytrade.InstrumentTypeEquity,
			},
		},
	}

	// Dry run the order
	fmt.Println("Validating order...")
	dryRunResp, err := client.DryRunOrder(dryRunCtx, accountNumber, order)
	if err != nil {
		fmt.Printf("Order validation failed: %v\n", err)
		return
	}

	// Check for warnings
	if len(dryRunResp.Warnings) > 0 {
		fmt.Println("\nOrder has warnings:")
		for _, warning := range dryRunResp.Warnings {
			fmt.Printf("- %s\n", warning)
		}
		fmt.Print("Continue anyway? (yes/no): ")
		confirm = readLine()
		if strings.ToLower(confirm) != "yes" {
			fmt.Println("Order cancelled.")
			return
		}
	}

	// Place the actual order
	placeCtx, cancel := context.WithTimeout(ctx, 15*time.Second)
	defer cancel()

	fmt.Println("Placing order...")
	resp, err := client.PlaceOrder(placeCtx, accountNumber, order)
	if err != nil {
		fmt.Printf("Failed to place order: %v\n", err)
		return
	}

	fmt.Println("\n=== Order Placed ===")
	fmt.Printf("Order ID: %s\n", resp.Order.ID)
	fmt.Printf("Status: %s\n", resp.Order.Status)
	fmt.Printf("Received At: %s\n", resp.Order.ReceivedAt.Format(time.RFC3339))
}

// placeEquityLimitOrder places a limit order for an equity
func placeEquityLimitOrder() {
	if accountNumber == "" {
		fmt.Println("No account selected.")
		return
	}

	fmt.Print("Enter symbol: ")
	symbol := readLine()

	fmt.Print("Enter quantity: ")
	quantityStr := readLine()
	quantity, err := strconv.ParseFloat(quantityStr, 64)
	if err != nil || quantity <= 0 {
		fmt.Println("Invalid quantity.")
		return
	}

	fmt.Print("Enter limit price: ")
	priceStr := readLine()
	price, err := strconv.ParseFloat(priceStr, 64)
	if err != nil || price <= 0 {
		fmt.Println("Invalid price.")
		return
	}

	fmt.Print("Buy or Sell? (buy/sell): ")
	action := readLine()
	var orderDirection tastytrade.OrderDirection
	var priceEffect tastytrade.PriceEffect

	if strings.ToLower(action) == "buy" {
		orderDirection = tastytrade.OrderDirectionBuyToOpen
		priceEffect = tastytrade.PriceEffectDebit
	} else if strings.ToLower(action) == "sell" {
		orderDirection = tastytrade.OrderDirectionSellToOpen
		priceEffect = tastytrade.PriceEffectCredit
	} else {
		fmt.Println("Invalid action.")
		return
	}

	fmt.Print("Time in force (day/gtc): ")
	tifStr := readLine()
	var timeInForce tastytrade.TimeInForce
	if strings.ToLower(tifStr) == "gtc" {
		timeInForce = tastytrade.TimeInForceGTC
	} else {
		timeInForce = tastytrade.TimeInForceDay
	}

	// Confirm the order
	fmt.Printf("\nYou are about to place a limit order to %s %.2f shares of %s at $%.2f\n",
		strings.ToLower(action), quantity, symbol, price)
	fmt.Printf("Time in force: %s\n", timeInForce)
	fmt.Print("Confirm? (yes/no): ")
	confirm := readLine()
	if strings.ToLower(confirm) != "yes" {
		fmt.Println("Order cancelled.")
		return
	}

	// Create order request
	qty := quantity
	order := tastytrade.OrderRequest{
		OrderType:   tastytrade.OrderTypeLimit,
		TimeInForce: timeInForce,
		Price:       &price,
		PriceEffect: &priceEffect,
		Legs: []tastytrade.OrderLeg{
			{
				Symbol:         symbol,
				Quantity:       &qty,
				Action:         orderDirection,
				InstrumentType: tastytrade.InstrumentTypeEquity,
			},
		},
	}

	// Dry run the order
	fmt.Println("Validating order...")
	dryRunResp, err := client.DryRunOrder(ctx, accountNumber, order)
	if err != nil {
		fmt.Printf("Order validation failed: %v\n", err)
		return
	}

	// Check for warnings
	if len(dryRunResp.Warnings) > 0 {
		fmt.Println("\nOrder has warnings:")
		for _, warning := range dryRunResp.Warnings {
			fmt.Printf("- %s\n", warning)
		}
		fmt.Print("Continue anyway? (yes/no): ")
		confirm = readLine()
		if strings.ToLower(confirm) != "yes" {
			fmt.Println("Order cancelled.")
			return
		}
	}

	// Place the actual order
	fmt.Println("Placing order...")
	resp, err := client.PlaceOrder(ctx, accountNumber, order)
	if err != nil {
		fmt.Printf("Failed to place order: %v\n", err)
		return
	}

	fmt.Println("\n=== Order Placed ===")
	fmt.Printf("Order ID: %s\n", resp.Order.ID)
	fmt.Printf("Status: %s\n", resp.Order.Status)
	fmt.Printf("Received At: %s\n", resp.Order.ReceivedAt.Format(time.RFC3339))
}

// placeNotionalMarketOrder places a notional market order (fractional shares)
func placeNotionalMarketOrder() {
	if accountNumber == "" {
		fmt.Println("No account selected.")
		return
	}

	fmt.Print("Enter symbol: ")
	symbol := readLine()

	fmt.Print("Enter dollar amount: ")
	valueStr := readLine()
	value, err := strconv.ParseFloat(valueStr, 64)
	if err != nil || value <= 0 {
		fmt.Println("Invalid dollar amount.")
		return
	}

	fmt.Print("Buy or Sell? (buy/sell): ")
	action := readLine()
	var orderDirection tastytrade.OrderDirection
	var valueEffect tastytrade.PriceEffect

	if strings.ToLower(action) == "buy" {
		orderDirection = tastytrade.OrderDirectionBuyToOpen
		valueEffect = tastytrade.PriceEffectDebit
	} else if strings.ToLower(action) == "sell" {
		orderDirection = tastytrade.OrderDirectionSellToOpen
		valueEffect = tastytrade.PriceEffectCredit
	} else {
		fmt.Println("Invalid action.")
		return
	}

	// Confirm the order
	fmt.Printf("\nYou are about to place a notional market order to %s $%.2f worth of %s\n",
		strings.ToLower(action), value, symbol)
	fmt.Print("Confirm? (yes/no): ")
	confirm := readLine()
	if strings.ToLower(confirm) != "yes" {
		fmt.Println("Order cancelled.")
		return
	}

	// Create the order request
	order := tastytrade.OrderRequest{
		OrderType:   tastytrade.OrderTypeNotionalMarket,
		TimeInForce: tastytrade.TimeInForceDay,
		Value:       &value,
		ValueEffect: &valueEffect,
		Legs: []tastytrade.OrderLeg{
			{
				Symbol:         symbol,
				Action:         orderDirection,
				InstrumentType: tastytrade.InstrumentTypeEquity,
			},
		},
	}

	// Dry run the order
	fmt.Println("Validating order...")
	dryRunResp, err := client.DryRunOrder(ctx, accountNumber, order)
	if err != nil {
		fmt.Printf("Order validation failed: %v\n", err)
		return
	}

	// Check for warnings
	if len(dryRunResp.Warnings) > 0 {
		fmt.Println("\nOrder has warnings:")
		for _, warning := range dryRunResp.Warnings {
			fmt.Printf("- %s\n", warning)
		}
		fmt.Print("Continue anyway? (yes/no): ")
		confirm = readLine()
		if strings.ToLower(confirm) != "yes" {
			fmt.Println("Order cancelled.")
			return
		}
	}

	// Place the actual order
	fmt.Println("Placing order...")
	resp, err := client.PlaceOrder(ctx, accountNumber, order)
	if err != nil {
		fmt.Printf("Failed to place order: %v\n", err)
		return
	}

	fmt.Println("\n=== Order Placed ===")
	fmt.Printf("Order ID: %s\n", resp.Order.ID)
	fmt.Printf("Status: %s\n", resp.Order.Status)
	fmt.Printf("Received At: %s\n", resp.Order.ReceivedAt.Format(time.RFC3339))
}

// placeStopLimitOrder places a stop limit order
func placeStopLimitOrder() {
	if accountNumber == "" {
		fmt.Println("No account selected.")
		return
	}

	fmt.Print("Enter symbol: ")
	symbol := readLine()

	fmt.Print("Enter quantity: ")
	quantityStr := readLine()
	quantity, err := strconv.ParseFloat(quantityStr, 64)
	if err != nil || quantity <= 0 {
		fmt.Println("Invalid quantity.")
		return
	}

	fmt.Print("Enter stop trigger price: ")
	stopTriggerStr := readLine()
	stopTrigger, err := strconv.ParseFloat(stopTriggerStr, 64)
	if err != nil || stopTrigger <= 0 {
		fmt.Println("Invalid stop trigger price.")
		return
	}

	fmt.Print("Enter limit price: ")
	priceStr := readLine()
	price, err := strconv.ParseFloat(priceStr, 64)
	if err != nil || price <= 0 {
		fmt.Println("Invalid limit price.")
		return
	}

	fmt.Print("Buy or Sell? (buy/sell): ")
	action := readLine()
	var orderDirection tastytrade.OrderDirection
	var priceEffect tastytrade.PriceEffect

	if strings.ToLower(action) == "buy" {
		orderDirection = tastytrade.OrderDirectionBuyToOpen
		priceEffect = tastytrade.PriceEffectDebit
	} else if strings.ToLower(action) == "sell" {
		orderDirection = tastytrade.OrderDirectionSellToOpen
		priceEffect = tastytrade.PriceEffectCredit
	} else {
		fmt.Println("Invalid action.")
		return
	}

	// Confirm the order
	fmt.Printf("\nYou are about to place a stop limit order to %s %.2f shares of %s\n",
		strings.ToLower(action), quantity, symbol)
	fmt.Printf("Stop trigger: $%.2f, Limit price: $%.2f\n", stopTrigger, price)
	fmt.Print("Confirm? (yes/no): ")
	confirm := readLine()
	if strings.ToLower(confirm) != "yes" {
		fmt.Println("Order cancelled.")
		return
	}

	// Create the order
	qty := quantity
	order := tastytrade.OrderRequest{
		OrderType:   tastytrade.OrderTypeStopLimit,
		TimeInForce: tastytrade.TimeInForceDay,
		Price:       &price,
		PriceEffect: &priceEffect,
		StopTrigger: &stopTrigger,
		Legs: []tastytrade.OrderLeg{
			{
				Symbol:         symbol,
				Quantity:       &qty,
				Action:         orderDirection,
				InstrumentType: tastytrade.InstrumentTypeEquity,
			},
		},
	}

	// Dry run the order
	fmt.Println("Validating order...")
	dryRunResp, err := client.DryRunOrder(ctx, accountNumber, order)
	if err != nil {
		fmt.Printf("Order validation failed: %v\n", err)
		return
	}

	// Check for warnings
	if len(dryRunResp.Warnings) > 0 {
		fmt.Println("\nOrder has warnings:")
		for _, warning := range dryRunResp.Warnings {
			fmt.Printf("- %s\n", warning)
		}
		fmt.Print("Continue anyway? (yes/no): ")
		confirm = readLine()
		if strings.ToLower(confirm) != "yes" {
			fmt.Println("Order cancelled.")
			return
		}
	}

	// Place the actual order
	fmt.Println("Placing order...")
	resp, err := client.PlaceOrder(ctx, accountNumber, order)
	if err != nil {
		fmt.Printf("Failed to place order: %v\n", err)
		return
	}

	fmt.Println("\n=== Order Placed ===")
	fmt.Printf("Order ID: %s\n", resp.Order.ID)
	fmt.Printf("Status: %s\n", resp.Order.Status)
	fmt.Printf("Received At: %s\n", resp.Order.ReceivedAt.Format(time.RFC3339))
}

// placeOptionOrder places an option order (simplified for the CLI demo)
func placeOptionOrder() {
	if accountNumber == "" {
		fmt.Println("No account selected.")
		return
	}

	fmt.Println("\nNOTE: This is a simplified option order entry.")
	fmt.Println("For real applications, you should look up option symbols via option chain endpoints.")

	fmt.Print("Enter option symbol (e.g., AAPL  230721C00190000): ")
	symbol := readLine()

	fmt.Print("Enter quantity (in contracts): ")
	quantityStr := readLine()
	quantity, err := strconv.ParseFloat(quantityStr, 64)
	if err != nil || quantity <= 0 {
		fmt.Println("Invalid quantity.")
		return
	}

	fmt.Print("Enter limit price (per contract): ")
	priceStr := readLine()
	price, err := strconv.ParseFloat(priceStr, 64)
	if err != nil || price <= 0 {
		fmt.Println("Invalid price.")
		return
	}

	fmt.Print("Buy or Sell? (buy/sell): ")
	action := readLine()
	var orderDirection tastytrade.OrderDirection
	var priceEffect tastytrade.PriceEffect

	if strings.ToLower(action) == "buy" {
		orderDirection = tastytrade.OrderDirectionBuyToOpen
		priceEffect = tastytrade.PriceEffectDebit
	} else if strings.ToLower(action) == "sell" {
		orderDirection = tastytrade.OrderDirectionSellToOpen
		priceEffect = tastytrade.PriceEffectCredit
	} else {
		fmt.Println("Invalid action.")
		return
	}

	// Confirm the order
	fmt.Printf("\nYou are about to place a limit order to %s %.0f contracts of %s at $%.2f per contract\n",
		strings.ToLower(action), quantity, symbol, price)
	fmt.Print("Confirm? (yes/no): ")
	confirm := readLine()
	if strings.ToLower(confirm) != "yes" {
		fmt.Println("Order cancelled.")
		return
	}

	// Create the order
	qty := quantity
	order := tastytrade.OrderRequest{
		OrderType:   tastytrade.OrderTypeLimit,
		TimeInForce: tastytrade.TimeInForceDay,
		Price:       &price,
		PriceEffect: &priceEffect,
		Legs: []tastytrade.OrderLeg{
			{
				Symbol:         symbol,
				Quantity:       &qty,
				Action:         orderDirection,
				InstrumentType: tastytrade.InstrumentTypeEquityOption,
			},
		},
	}

	// Dry run the order
	fmt.Println("Validating order...")
	dryRunResp, err := client.DryRunOrder(ctx, accountNumber, order)
	if err != nil {
		fmt.Printf("Order validation failed: %v\n", err)
		return
	}

	// Check for warnings
	if len(dryRunResp.Warnings) > 0 {
		fmt.Println("\nOrder has warnings:")
		for _, warning := range dryRunResp.Warnings {
			fmt.Printf("- %s\n", warning)
		}
		fmt.Print("Continue anyway? (yes/no): ")
		confirm = readLine()
		if strings.ToLower(confirm) != "yes" {
			fmt.Println("Order cancelled.")
			return
		}
	}

	// Place the actual order
	fmt.Println("Placing order...")
	resp, err := client.PlaceOrder(ctx, accountNumber, order)
	if err != nil {
		fmt.Printf("Failed to place order: %v\n", err)
		return
	}

	fmt.Println("\n=== Order Placed ===")
	fmt.Printf("Order ID: %s\n", resp.Order.ID)
	fmt.Printf("Status: %s\n", resp.Order.Status)
	fmt.Printf("Received At: %s\n", resp.Order.ReceivedAt.Format(time.RFC3339))
}

// orderManagementMenu displays order management options
func orderManagementMenu() {
	for {
		fmt.Println("\n=== Order Management Menu ===")
		fmt.Println("1. List Open Orders")
		fmt.Println("2. Get Order Details")
		fmt.Println("3. Cancel Order")
		fmt.Println("0. Back to Main Menu")
		fmt.Print("Select an option: ")

		choice := readLine()
		switch choice {
		case "1":
			listOpenOrders()
		case "2":
			getOrderDetails()
		case "3":
			cancelOrder()
		case "0":
			return
		default:
			fmt.Println("Invalid option. Please try again.")
		}
	}
}

// listOpenOrders lists open orders for the account
func listOpenOrders() {
	if accountNumber == "" {
		fmt.Println("No account selected.")
		return
	}

	fmt.Println("Fetching orders...")
	orders, err := client.GetOrders(ctx, accountNumber)
	if err != nil {
		fmt.Printf("Failed to get orders: %v\n", err)
		return
	}

	fmt.Printf("\n=== Open Orders for Account %s ===\n", accountNumber)
	fmt.Printf("Total Orders: %d\n\n", len(orders))

	// Display open orders
	count := 0
	for _, order := range orders {
		// Display details
		fmt.Printf("Order ID: %s\n", order.Order.ID)
		fmt.Printf("Status: %s\n", order.Order.Status)
		fmt.Printf("Received: %s\n", order.Order.ReceivedAt.Format(time.RFC3339))

		// Display legs
		for i, leg := range order.Order.Legs {
			var quantity string
			if leg.Quantity != nil {
				quantity = fmt.Sprintf("%.2f", *leg.Quantity)
			} else {
				quantity = "N/A"
			}

			fmt.Printf("Leg %d: %s %s %s (Qty: %s)\n",
				i+1, leg.Action, leg.InstrumentType, leg.Symbol, quantity)
		}

		fmt.Println("---")
		count++

		// Only show first 5 orders to avoid cluttering the screen
		if count >= 5 {
			fmt.Println("(Showing first 5 orders only)")
			break
		}
	}

	if count == 0 {
		fmt.Println("No orders found.")
	}
}

// getOrderDetails gets and displays details for a specific order
func getOrderDetails() {
	if accountNumber == "" {
		fmt.Println("No account selected.")
		return
	}

	fmt.Print("Enter Order ID: ")
	orderID := readLine()
	if orderID == "" {
		fmt.Println("No Order ID entered.")
		return
	}

	fmt.Printf("Fetching details for Order %s...\n", orderID)
	resp, err := client.GetOrder(ctx, accountNumber, orderID)
	if err != nil {
		fmt.Printf("Failed to get order details: %v\n", err)
		return
	}

	fmt.Println("\n=== Order Details ===")
	fmt.Printf("Order ID: %s\n", resp.Order.ID)
	fmt.Printf("Status: %s\n", resp.Order.Status)
	fmt.Printf("Received: %s\n", resp.Order.ReceivedAt.Format(time.RFC3339))

	// Display legs
	fmt.Println("\nLegs:")
	for i, leg := range resp.Order.Legs {
		var quantity string
		if leg.Quantity != nil {
			quantity = fmt.Sprintf("%.2f", *leg.Quantity)
		} else {
			quantity = "N/A"
		}

		fmt.Printf("Leg %d: %s %s %s (Qty: %s)\n",
			i+1, leg.Action, leg.InstrumentType, leg.Symbol, quantity)

		// Display fills if any
		if len(leg.Fills) > 0 {
			fmt.Printf("  Fills:\n")
			for j, fill := range leg.Fills {
				fmt.Printf("    Fill %d: %.2f shares @ $%.2f (Filled at: %s)\n",
					j+1, fill.Quantity, fill.FillPrice, fill.FilledAt.Format(time.RFC3339))
			}
		}
	}
}

// cancelOrder cancels an open order
func cancelOrder() {
	if accountNumber == "" {
		fmt.Println("No account selected.")
		return
	}

	fmt.Print("Enter Order ID to cancel: ")
	orderID := readLine()
	if orderID == "" {
		fmt.Println("No Order ID entered.")
		return
	}

	// Confirm cancellation
	fmt.Printf("\nYou are about to cancel Order ID: %s\n", orderID)
	fmt.Print("Confirm? (yes/no): ")
	confirm := readLine()
	if strings.ToLower(confirm) != "yes" {
		fmt.Println("Cancellation aborted.")
		return
	}

	fmt.Printf("Cancelling Order %s...\n", orderID)
	err := client.CancelOrder(ctx, accountNumber, orderID)
	if err != nil {
		fmt.Printf("Failed to cancel order: %v\n", err)
		return
	}

	fmt.Println("Order cancelled successfully!")
}

// positionManagementMenu displays position management options
func positionManagementMenu() {
	for {
		fmt.Println("\n=== Position Management Menu ===")
		fmt.Println("1. List Positions")
		fmt.Println("2. List Equity Positions")
		fmt.Println("3. List Option Positions")
		fmt.Println("0. Back to Main Menu")
		fmt.Print("Select an option: ")

		choice := readLine()
		switch choice {
		case "1":
			listPositions()
		case "2":
			listEquityPositions()
		case "3":
			listOptionPositions()
		case "0":
			return
		default:
			fmt.Println("Invalid option. Please try again.")
		}
	}
}

// listPositions lists all positions for the account
func listPositions() {
	if accountNumber == "" {
		fmt.Println("No account selected.")
		return
	}

	fmt.Println("Fetching positions...")
	positions, err := client.GetPositions(ctx, accountNumber)
	if err != nil {
		fmt.Printf("Failed to get positions: %v\n", err)
		return
	}

	fmt.Printf("\n=== Positions for Account %s ===\n", accountNumber)
	fmt.Printf("Total Positions: %d\n\n", len(positions))

	if len(positions) == 0 {
		fmt.Println("No positions found.")
		return
	}

	// Group positions by instrument type
	equityPositions := make([]tastytrade.Position, 0)
	optionPositions := make([]tastytrade.Position, 0)
	otherPositions := make([]tastytrade.Position, 0)

	for _, position := range positions {
		switch position.InstrumentType {
		case "Equity":
			equityPositions = append(equityPositions, position)
		case "Equity Option":
			optionPositions = append(optionPositions, position)
		default:
			otherPositions = append(otherPositions, position)
		}
	}

	// Display equity positions
	if len(equityPositions) > 0 {
		fmt.Println("=== Equity Positions ===")
		for _, pos := range equityPositions {
			fmt.Printf("%s: %.2f shares @ $%.2f (Market Value: $%.2f)\n",
				pos.Symbol, pos.Quantity, pos.CostBasis, pos.MarketValue)
		}
		fmt.Println()
	}

	// Display option positions
	if len(optionPositions) > 0 {
		fmt.Println("=== Option Positions ===")
		for _, pos := range optionPositions {
			fmt.Printf("%s: %.2f contracts @ $%.2f (Market Value: $%.2f)\n",
				pos.Symbol, pos.Quantity, pos.CostBasis, pos.MarketValue)
			if pos.ExpirationDate != "" {
				fmt.Printf("  Expires: %s, Strike: $%.2f, Type: %s\n",
					pos.ExpirationDate, pos.StrikePrice, pos.OptionType)
			}
		}
		fmt.Println()
	}

	// Display other positions
	if len(otherPositions) > 0 {
		fmt.Println("=== Other Positions ===")
		for _, pos := range otherPositions {
			fmt.Printf("%s (%s): %.2f @ $%.2f (Market Value: $%.2f)\n",
				pos.Symbol, pos.InstrumentType, pos.Quantity, pos.CostBasis, pos.MarketValue)
		}
	}
}

// listEquityPositions lists equity positions for the account
func listEquityPositions() {
	if accountNumber == "" {
		fmt.Println("No account selected.")
		return
	}

	fmt.Println("Fetching equity positions...")
	positions, err := client.GetEquityPositions(ctx, accountNumber)
	if err != nil {
		fmt.Printf("Failed to get equity positions: %v\n", err)
		return
	}

	fmt.Printf("\n=== Equity Positions for Account %s ===\n", accountNumber)
	fmt.Printf("Total Equity Positions: %d\n\n", len(positions))

	if len(positions) == 0 {
		fmt.Println("No equity positions found.")
		return
	}

	// Display positions
	for _, pos := range positions {
		fmt.Printf("%s: %.2f shares @ $%.2f (Market Value: $%.2f)\n",
			pos.Symbol, pos.Quantity, pos.CostBasis, pos.MarketValue)
	}
}

// listOptionPositions lists option positions for the account
func listOptionPositions() {
	if accountNumber == "" {
		fmt.Println("No account selected.")
		return
	}

	fmt.Println("Fetching option positions...")
	positions, err := client.GetOptionPositions(ctx, accountNumber)
	if err != nil {
		fmt.Printf("Failed to get option positions: %v\n", err)
		return
	}

	fmt.Printf("\n=== Option Positions for Account %s ===\n", accountNumber)
	fmt.Printf("Total Option Positions: %d\n\n", len(positions))

	if len(positions) == 0 {
		fmt.Println("No option positions found.")
		return
	}

	// Display positions
	for _, pos := range positions {
		fmt.Printf("%s: %.2f contracts @ $%.2f (Market Value: $%.2f)\n",
			pos.Symbol, pos.Quantity, pos.CostBasis, pos.MarketValue)
		if pos.ExpirationDate != "" {
			fmt.Printf("  Expires: %s, Strike: $%.2f, Type: %s\n",
				pos.ExpirationDate, pos.StrikePrice, pos.OptionType)
		}
		if pos.UnderlyingSymbol != "" {
			fmt.Printf("  Underlying: %s\n", pos.UnderlyingSymbol)
		}
	}
}
