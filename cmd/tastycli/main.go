package main

import (
	"bufio"
	"context"
	"fmt"
	"os"
	"strings"
	"time"

	"github.com/ryanhamamura/tastytrade/pkg/tastytrade"
)

// CLI command definitions
const (
	cmdHelp       = "help"
	cmdLogin      = "login"
	cmdLogout     = "logout"
	cmdAccounts   = "accounts"
	cmdAccount    = "account"
	cmdCustomer   = "customer"
	cmdQuoteToken = "quotetoken"
	cmdExit       = "exit"

	// New instrument-related commands
	cmdInstrument  = "instrument"
	cmdOptionChain = "optionchain"
	cmdExpirations = "expirations"
)

func main() {
	fmt.Println("TastyTrade API CLI Tester")
	fmt.Println("=========================")

	scanner := bufio.NewScanner(os.Stdin)
	ctx := context.Background()

	// Choose environment
	useProduction := chooseEnvironment(scanner)

	// Initialize client with chosen environment
	client := tastytrade.NewClient(useProduction, tastytrade.WithDebug(true)) // Use certify/sandbox env

	// Setup prompt based on environment
	envName := "SANDBOX"
	if useProduction {
		envName = "PRODUCTION"
	}

	// Authentication state
	var isAuthenticated bool

	for {
		if isAuthenticated {
			fmt.Printf("tasty [%s]> ", envName)
		} else {
			fmt.Printf("tasty [%s] (not authenticated)> ", envName)
		}

		if !scanner.Scan() {
			break
		}

		input := scanner.Text()
		args := strings.Fields(input)
		if len(args) == 0 {
			continue
		}

		command := args[0]

		switch command {
		case cmdHelp:
			printHelp(isAuthenticated)

		case cmdLogin:
			if isAuthenticated {
				fmt.Println("Already logged in. Please logout first.")
				continue
			}

			if len(args) != 3 {
				fmt.Println("Usage: login <username> <password>")
				continue
			}
			username := args[1]
			password := args[2]

			if err := client.Login(ctx, username, password); err != nil {
				fmt.Printf("Login failed: %v\n", err)
				continue
			}

			fmt.Println("Login successful!")
			isAuthenticated = true

		case cmdLogout:
			if !checkAuth(isAuthenticated) {
				continue
			}

			if err := client.Logout(ctx); err != nil {
				fmt.Printf("Logout failed: %v\n", err)
				continue
			}

			fmt.Println("Logged out successfully.")
			isAuthenticated = false

		case cmdAccounts:
			if !checkAuth(isAuthenticated) {
				continue
			}

			if len(args) != 2 {
				fmt.Println("Usage: accounts <customer_id>")
				continue
			}
			customerID := args[1]

			accounts, err := client.GetCustomerAccounts(ctx, customerID)
			if err != nil {
				fmt.Printf("Failed to get accounts: %v\n", err)
				continue
			}

			fmt.Printf("Found %d accounts:\n", len(accounts))
			for i, acc := range accounts {
				fmt.Printf("%d. Account #: %s, Type: %s, Authority: %s\n",
					i+1,
					acc.Account.AccountNumber,
					acc.Account.AccountTypeName,
					acc.AuthorityLevel)
			}

		case cmdAccount:
			if !checkAuth(isAuthenticated) {
				continue
			}

			if len(args) != 3 {
				fmt.Println("Usage: account <customer_id> <account_number>")
				continue
			}
			customerID := args[1]
			accountNumber := args[2]

			account, err := client.GetCustomerAccount(ctx, customerID, accountNumber)
			if err != nil {
				fmt.Printf("Failed to get account: %v\n", err)
				continue
			}

			printAccount(account)

		case cmdCustomer:
			if !checkAuth(isAuthenticated) {
				continue
			}

			if len(args) < 2 {
				fmt.Println("Usage: customer <customer_id> [allow-missing]")
				continue
			}
			customerID := args[1]
			allowMissing := false
			if len(args) >= 3 && args[2] == "allow-missing" {
				allowMissing = true
			}

			customer, err := client.GetCustomer(ctx, customerID, allowMissing)
			if err != nil {
				fmt.Printf("Failed to get customer: %v\n", err)
				continue
			}

			printCustomer(customer)

		case cmdQuoteToken:
			if !checkAuth(isAuthenticated) {
				continue
			}

			token, err := client.GetAPIQuoteTokens(ctx)
			if err != nil {
				fmt.Printf("Failed to get quote token: %v\n", err)
				continue
			}

			fmt.Println("Quote Token Details:")
			fmt.Printf("Token: %s\n", token.Token)
			fmt.Printf("Level: %s\n", token.Level)
			fmt.Printf("Issued At: %s\n", token.IssuedAt.Format(time.RFC3339))
			fmt.Printf("Expires At: %s\n", token.ExpiresAt.Format(time.RFC3339))
			fmt.Printf("Websocket URL: %s\n", token.WebsocketURL)
			fmt.Printf("DXLink URL: %s\n", token.DxlinkURL)

		case cmdInstrument:
			if !checkAuth(isAuthenticated) {
				continue
			}

			if len(args) < 2 {
				fmt.Println("Usage: instrument <type> <symbol>")
				fmt.Println("Types: equity, equity-option")
				continue
			}

			instrType := args[1]

			if len(args) != 3 {
				fmt.Printf("Usage: instrument %s <symbol>\n", instrType)
				continue
			}

			symbol := args[2]

			switch instrType {
			case "equity":
				equity, err := client.GetEquity(ctx, symbol)
				if err != nil {
					fmt.Printf("Failed to get equity: %v\n", err)
					continue
				}
				printEquity(equity)

			case "equity-option":
				option, err := client.GetEquityOption(ctx, symbol)
				if err != nil {
					fmt.Printf("Failed to get equity option: %v\n", err)
					continue
				}
				printEquityOption(option)

			default:
				fmt.Printf("Unsupported instrument type: %s\n", instrType)
				fmt.Println("Supported types: equity, equity-option")
			}

		case cmdOptionChain:
			if !checkAuth(isAuthenticated) {
				continue
			}

			if len(args) < 2 {
				fmt.Println("Usage: optionchain <symbol>")
				fmt.Println("Example: optionchain AAPL")
				continue
			}

			symbol := args[1]

			options, err := client.GetOptionChain(ctx, symbol)
			if err != nil {
				fmt.Printf("Failed to get option chain: %v\n", err)
				continue
			}

			fmt.Printf("Found %d options for %s:\n", len(options), symbol)
			printOptionChain(options)

		case cmdExpirations:
			if !checkAuth(isAuthenticated) {
				continue
			}

			if len(args) != 2 {
				fmt.Println("Usage: expirations <symbol>")
				continue
			}

			symbol := args[1]

			expirations, err := client.GetActiveExpirations(ctx, symbol)
			if err != nil {
				fmt.Printf("Failed to get expirations: %v\n", err)
				continue
			}

			fmt.Printf("Available expirations for %s:\n", symbol)
			fmt.Printf("%-12s %-10s %-12s %-10s\n", "Date", "Days Left", "Type", "Settlement")
			fmt.Println(strings.Repeat("-", 50))

			for _, exp := range expirations {
				fmt.Printf("%-12s %-10d %-12s %-10s\n",
					exp.ExpirationDate,
					exp.DaysToExpiration,
					exp.ExpirationType,
					exp.SettlementType)
			}

		case cmdExit:
			fmt.Println("Goodbye!")
			return

		default:
			fmt.Printf("Unknown command: %s\n", command)
			printHelp(isAuthenticated)
		}
	}
}

func checkAuth(isAuthenticated bool) bool {
	if !isAuthenticated {
		fmt.Println("Not authenticated. Please login first.")
		return false
	}
	return true
}

func printHelp(isAuthenticated bool) {
	fmt.Println("Available commands:")
	fmt.Println("  help                           - Show this help message")
	fmt.Println("  login <username> <password>    - Login to TastyTrade")
	if isAuthenticated {
		fmt.Println("  logout                         - Logout from TastyTrade")
		fmt.Println("  accounts <customer_id>         - List accounts (use 'me' for current user)")
		fmt.Println("  account <customer_id> <acct#>  - Get specific account details")
		fmt.Println("  customer <customer_id> [allow-missing] - Get customer details")
		fmt.Println("  quotetoken                     - Get API quote token")

		// Instrument commands help
		fmt.Println("\nInstrument Commands:")
		fmt.Println("  instrument equity <symbol>     - Get details for a specific equity")
		fmt.Println("  instrument equity-option <symbol> - Get details for a specific equity option")
		fmt.Println("  optionchain <symbol>           - Get option chain for a symbol")
		fmt.Println("  expirations <symbol>           - Get available expiration dates for options")
	}
	fmt.Println("  exit                           - Exit the program")
}

func printAccount(account *tastytrade.Account) {
	fmt.Println("Account Details:")
	fmt.Printf("Account Number: %s\n", account.AccountNumber)
	fmt.Printf("Type: %s\n", account.AccountTypeName)
	fmt.Printf("Nickname: %s\n", account.Nickname)
	fmt.Printf("Margin or Cash: %s\n", account.MarginOrCash)
	fmt.Printf("Created At: %s\n", account.CreatedAt.Format(time.RFC3339))
	fmt.Printf("Day Trader Status: %v\n", account.DayTraderStatus)
	fmt.Printf("Is Closed: %v\n", account.IsClosed)
	fmt.Printf("Is Futures Approved: %v\n", account.IsFuturesApproved)
	fmt.Printf("Suitable Options Level: %s\n", account.SuitableOptionsLevel)
}

func printCustomer(customer *tastytrade.Customer) {
	fmt.Println("Customer Details:")
	fmt.Printf("ID: %s\n", customer.ID)
	fmt.Printf("Name: %s %s %s\n",
		customer.FirstName,
		valueOrEmpty(customer.MiddleName),
		customer.LastName)
	fmt.Printf("Email: %s\n", customer.Email)

	if customer.HomePhoneNumber != "" {
		fmt.Printf("Home Phone: %s\n", customer.HomePhoneNumber)
	}
	if customer.MobilePhoneNumber != "" {
		fmt.Printf("Mobile Phone: %s\n", customer.MobilePhoneNumber)
	}
	if customer.WorkPhoneNumber != "" {
		fmt.Printf("Work Phone: %s\n", customer.WorkPhoneNumber)
	}

	fmt.Println("Address:")
	if customer.Address.StreetOne != "" {
		fmt.Printf("  %s\n", customer.Address.StreetOne)
		if customer.Address.StreetTwo != "" {
			fmt.Printf("  %s\n", customer.Address.StreetTwo)
		}
		fmt.Printf("  %s, %s %s\n",
			customer.Address.City,
			customer.Address.StateRegion,
			customer.Address.PostalCode)
		fmt.Printf("  %s\n", customer.Address.Country)
	} else {
		fmt.Println("  No address information available")
	}

	fmt.Printf("\nAccount Eligibility:\n")
	fmt.Printf("  Is Professional: %t\n", customer.IsProfessional)
	fmt.Printf("  Regulatory Domain: %s\n", customer.RegulatoryDomain)
	fmt.Printf("  Citizenship: %s (%s)\n", customer.CitizenshipCountry, customer.USACitizenshipType)
	fmt.Printf("\nPermitted Account Types: %d total\n", len(customer.PermittedAccountTypes))
	for i, acctType := range customer.PermittedAccountTypes {
		if i < 5 { // Limit to first 5 to avoid flooding the console
			fmt.Printf("  - %s (Tax Advantaged: %t)\n", acctType.Name, acctType.IsTaxAdvantaged)
		} else if i == 5 {
			fmt.Printf("  ... and %d more\n", len(customer.PermittedAccountTypes)-5)
			break
		}
	}

	fmt.Printf("\nCreated: %s\n", customer.CreatedAt.Format("Jan 2, 2006"))
}

// Helper functions for printing different instrument types
func printInstrumentDetails(symbol, instrumentType string, active bool, description string) {
	fmt.Println("Instrument Details:")
	fmt.Printf("Symbol: %s\n", symbol)
	fmt.Printf("Type: %s\n", instrumentType)
	fmt.Printf("Description: %s\n", description)
	fmt.Printf("Active: %v\n", active)
}

func printEquity(equity *tastytrade.Equity) {
	printInstrumentDetails(equity.Symbol, equity.InstrumentType, equity.Active, equity.Description)

	if equity.ShortDescription != "" {
		fmt.Printf("Short Description: %s\n", equity.ShortDescription)
	}
	fmt.Printf("Listed Market: %s\n", equity.ListedMarket)
	fmt.Printf("Is ETF: %v\n", equity.IsETF)
	fmt.Printf("Is Index: %v\n", equity.IsIndex)
	fmt.Printf("Lendability: %s\n", equity.Lendability)
	fmt.Printf("Borrow Rate: %s\n", equity.BorrowRate)
	fmt.Printf("Fractional Quantity Eligible: %v\n", equity.IsFractionalQuantityEligible)
	fmt.Printf("Is Illiquid: %v\n", equity.IsIlliquid)

	if len(equity.TickSizes) > 0 {
		fmt.Println("\nTick Sizes:")
		for _, tick := range equity.TickSizes {
			if tick.Threshold != nil {
				fmt.Printf("  %s (threshold: %s)\n", tick.Value, *tick.Threshold)
			} else {
				fmt.Printf("  %s\n", tick.Value)
			}
		}
	}
}

func printEquityOption(option *tastytrade.EquityOption) {
	printInstrumentDetails(option.Symbol, option.InstrumentType, option.Active, option.Description)

	fmt.Printf("Underlying: %s\n", option.UnderlyingSymbol)
	fmt.Printf("Root Symbol: %s\n", option.RootSymbol)
	fmt.Printf("Option Type: %s\n", option.OptionType)
	fmt.Printf("Strike Price: $%.2f\n", option.StrikePrice)
	fmt.Printf("Expiration Date: %s\n", option.ExpirationDate)
	fmt.Printf("Days to Expiration: %d\n", option.DaysToExpiration)
	fmt.Printf("Exercise Style: %s\n", option.ExerciseStyle)
	fmt.Printf("Shares Per Contract: %d\n", option.SharesPerContract)
	fmt.Printf("Settlement Type: %s\n", option.SettlementType)

	if !option.StopsTradingAt.IsZero() {
		fmt.Printf("Stops Trading At: %s\n", option.StopsTradingAt.Format(time.RFC3339))
	}

	if !option.ExpiresAt.IsZero() {
		fmt.Printf("Expires At: %s\n", option.ExpiresAt.Format(time.RFC3339))
	}
}

func printOptionChain(options []tastytrade.EquityOption) {
	if len(options) == 0 {
		fmt.Println("No options found.")
		return
	}

	// Group options by expiration date and strike price
	expirations := make(map[string]map[float64]map[string]tastytrade.EquityOption)

	for _, opt := range options {
		// Initialize map structure if needed
		if _, exists := expirations[opt.ExpirationDate]; !exists {
			expirations[opt.ExpirationDate] = make(map[float64]map[string]tastytrade.EquityOption)
		}

		if _, exists := expirations[opt.ExpirationDate][opt.StrikePrice]; !exists {
			expirations[opt.ExpirationDate][opt.StrikePrice] = make(map[string]tastytrade.EquityOption)
		}

		// Store option by type (call/put)
		expirations[opt.ExpirationDate][opt.StrikePrice][opt.OptionType] = opt
	}

	// Print a limited number of expirations
	maxExpirations := 2
	expCount := 0

	for exp, strikes := range expirations {
		if expCount >= maxExpirations {
			remaining := len(expirations) - maxExpirations
			if remaining > 0 {
				fmt.Printf("... and %d more expiration dates\n", remaining)
			}
			break
		}

		fmt.Printf("\nExpiration: %s\n", exp)
		fmt.Println("-----------------------------------------------------------")
		fmt.Printf("%-10s %-10s %-25s %-25s\n", "Strike", "", "Call", "Put")
		fmt.Println("-----------------------------------------------------------")

		// Convert strikes to sorted slice
		strikeList := make([]float64, 0, len(strikes))
		for strike := range strikes {
			strikeList = append(strikeList, strike)
		}

		// Sort strikes (simple bubble sort for brevity)
		for i := 0; i < len(strikeList); i++ {
			for j := i + 1; j < len(strikeList); j++ {
				if strikeList[i] > strikeList[j] {
					strikeList[i], strikeList[j] = strikeList[j], strikeList[i]
				}
			}
		}

		// Print options in strike order
		maxStrikes := 10
		strikeCount := 0

		for _, strike := range strikeList {
			if strikeCount >= maxStrikes {
				remaining := len(strikeList) - maxStrikes
				if remaining > 0 {
					fmt.Printf("... and %d more strikes\n", remaining)
				}
				break
			}

			callSymbol := "-"
			putSymbol := "-"

			if call, exists := strikes[strike]["C"]; exists {
				callSymbol = call.Symbol
			}

			if put, exists := strikes[strike]["P"]; exists {
				putSymbol = put.Symbol
			}

			fmt.Printf("$%-9.2f %-10s %-25s %-25s\n",
				strike, "", callSymbol, putSymbol)

			strikeCount++
		}

		expCount++
	}
}

func valueOrEmpty(s string) string {
	if s == "" {
		return ""
	}
	return s
}

// chooseEnvironment prompts the user to choose between sandbox and production
func chooseEnvironment(scanner *bufio.Scanner) bool {
	for {
		fmt.Println("\nChoose environment:")
		fmt.Println("1. Sandbox/Certification (for testing)")
		fmt.Println("2. Production (live trading)")
		fmt.Print("Enter choice (1/2): ")

		if !scanner.Scan() {
			fmt.Println("Error reading input. Defaulting to Sandbox.")
			return false
		}

		input := strings.TrimSpace(scanner.Text())

		switch input {
		case "1":
			fmt.Println("Using SANDBOX environment")
			return false
		case "2":
			fmt.Println("Using PRODUCTION environment")
			fmt.Println("\n⚠️  WARNING: You are connecting to the PRODUCTION API ⚠️")
			fmt.Println("    Any trades or actions will affect real accounts!")

			// Ask for confirmation
			fmt.Print("\nAre you sure? (yes/no): ")
			if !scanner.Scan() {
				fmt.Println("No confirmation received. Defaulting to Sandbox.")
				return false
			}

			confirm := strings.ToLower(strings.TrimSpace(scanner.Text()))
			if confirm == "yes" || confirm == "y" {
				return true
			}

			fmt.Println("Defaulting to Sandbox environment.")
			return false
		default:
			fmt.Println("Invalid choice. Please enter 1 or 2.")
		}
	}
}
