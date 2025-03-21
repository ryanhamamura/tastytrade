package tastytrade_test

import (
	"context"
	"fmt"
	"log"
	"time"

	"github.com/ryanhamamura/tastytrade"
)

// Example shows basic usage of the tastytrade package
func Example() {
	// Create a new client (use certification environment)
	client := tastytrade.NewClient(false, tastytrade.WithDebug(true))

	// Use a context with timeout
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	// Login to Tastytrade
	err := client.Login(ctx, "your-username", "your-password")
	if err != nil {
		log.Fatalf("Failed to login: %v", err)
	}

	// Get accounts
	accounts, err := client.GetAccounts(ctx)
	if err != nil {
		log.Fatalf("Failed to get accounts: %v", err)
	}

	// Print account information
	for _, account := range accounts {
		fmt.Printf("Account: %s (%s)\n", account.Name, account.AccountNumber)

		// Get balances
		balances, err := client.GetBalances(ctx, account.AccountNumber)
		if err != nil {
			log.Printf("Failed to get balances: %v", err)
			continue
		}

		fmt.Printf("  Net Liquidation: $%.2f\n", balances.NetLiq)
		fmt.Printf("  Buying Power: $%.2f\n", balances.BuyingPower)

		// Get positions
		positions, err := client.GetPositions(ctx, account.AccountNumber)
		if err != nil {
			log.Printf("Failed to get positions: %v", err)
			continue
		}

		fmt.Printf("  Positions: %d\n", len(positions))
		for _, position := range positions {
			fmt.Printf("    %s: %.2f shares @ $%.2f (Market Value: $%.2f)\n",
				position.Symbol, position.Quantity, position.CostBasis, position.MarketValue)
		}
	}

	// Get quotes for a few symbols
	quotes, err := client.GetQuotes(ctx, []string{"AAPL", "MSFT", "GOOGL"})
	if err != nil {
		log.Fatalf("Failed to get quotes: %v", err)
	}

	// Print quote information
	for symbol, quote := range quotes {
		fmt.Printf("%s: Last: $%.2f, Bid: $%.2f, Ask: $%.2f\n",
			symbol, quote.LastPrice, quote.BidPrice, quote.AskPrice)
	}
}

// ExampleLimitOrder demonstrates placing a limit order
func ExampleLimitOrder() {
	client := tastytrade.NewClient(false)
	ctx := context.Background()

	// Login first (omitted for brevity)

	// Define order parameters
	accountNumber := "ACCOUNT_NUMBER"
	quantity := 1.0
	price := 150.0
	priceEffect := tastytrade.PriceEffectDebit

	// Create a limit order request
	limitOrder := tastytrade.OrderRequest{
		OrderType:   tastytrade.OrderTypeLimit,
		TimeInForce: tastytrade.TimeInForceDay,
		Price:       &price,
		PriceEffect: &priceEffect,
		Legs: []tastytrade.OrderLeg{
			{
				Symbol:         "AAPL",
				Quantity:       &quantity,
				Action:         tastytrade.OrderDirectionBuyToOpen,
				InstrumentType: tastytrade.InstrumentTypeEquity,
			},
		},
	}

	// Use Dry Run to validate the order first
	dryRunResp, err := client.DryRunOrder(ctx, accountNumber, limitOrder)
	if err != nil {
		log.Fatalf("Dry run failed: %v", err)
	}

	// Check for warnings
	if len(dryRunResp.Warnings) > 0 {
		fmt.Println("Order has warnings:")
		for _, warning := range dryRunResp.Warnings {
			fmt.Printf("- %s\n", warning)
		}
	} else {
		// No warnings, place the actual order
		resp, err := client.PlaceOrder(ctx, accountNumber, limitOrder)
		if err != nil {
			log.Fatalf("Failed to place order: %v", err)
		}

		fmt.Printf("Order placed! Order ID: %s, Status: %s\n",
			resp.Order.ID, resp.Order.Status)
	}
}

// ExampleMarketOrder demonstrates placing a market order
func ExampleMarketOrder() {
	client := tastytrade.NewClient(false)
	ctx := context.Background()

	// Login first (omitted for brevity)

	// Use the helper method for market orders (easier than constructing manually)
	accountNumber := "ACCOUNT_NUMBER"
	resp, err := client.PlaceEquityMarketOrder(
		ctx,
		accountNumber,
		"AAPL",
		5.0, // 5 shares
		tastytrade.OrderDirectionBuyToOpen,
	)

	if err != nil {
		log.Fatalf("Failed to place market order: %v", err)
	}

	fmt.Printf("Market order placed! Order ID: %s, Status: %s\n",
		resp.Order.ID, resp.Order.Status)
}

// ExampleNotionalMarketOrder demonstrates placing a notional market order (fractional shares)
func ExampleNotionalMarketOrder() {
	client := tastytrade.NewClient(false)
	ctx := context.Background()

	// Login first (omitted for brevity)

	// Use the helper method for notional market orders
	accountNumber := "ACCOUNT_NUMBER"
	resp, err := client.PlaceEquityNotionalMarketOrder(
		ctx,
		accountNumber,
		"AAPL",
		100.0, // $100 worth of shares
		tastytrade.OrderDirectionBuyToOpen,
	)

	if err != nil {
		log.Fatalf("Failed to place notional market order: %v", err)
	}

	fmt.Printf("Notional market order placed! Order ID: %s, Status: %s\n",
		resp.Order.ID, resp.Order.Status)
}

// ExampleStopLimitOrder demonstrates placing a stop limit order
func ExampleStopLimitOrder() {
	client := tastytrade.NewClient(false)
	ctx := context.Background()

	// Login first (omitted for brevity)

	// Define order parameters
	accountNumber := "ACCOUNT_NUMBER"
	quantity := 100.0
	price := 190.0
	stopTrigger := 195.0
	priceEffect := tastytrade.PriceEffectCredit

	// Create a stop limit order request
	stopLimitOrder := tastytrade.OrderRequest{
		OrderType:   tastytrade.OrderTypeStopLimit,
		TimeInForce: tastytrade.TimeInForceGTC,
		Price:       &price,
		PriceEffect: &priceEffect,
		StopTrigger: &stopTrigger,
		Legs: []tastytrade.OrderLeg{
			{
				Symbol:         "AAPL",
				Quantity:       &quantity,
				Action:         tastytrade.OrderDirectionSellToClose,
				InstrumentType: tastytrade.InstrumentTypeEquity,
			},
		},
	}

	resp, err := client.PlaceOrder(ctx, accountNumber, stopLimitOrder)
	if err != nil {
		log.Fatalf("Failed to place stop limit order: %v", err)
	}

	fmt.Printf("Stop limit order placed! Order ID: %s, Status: %s\n",
		resp.Order.ID, resp.Order.Status)
}

// ExampleOptionSpread demonstrates placing an option spread order
func ExampleOptionSpread() {
	client := tastytrade.NewClient(false)
	ctx := context.Background()

	// Login first (omitted for brevity)

	// Use the helper method for option spreads
	accountNumber := "ACCOUNT_NUMBER"
	resp, err := client.PlaceEquityOptionSpreadOrder(
		ctx,
		accountNumber,
		"AAPL  230721C00190000", // Sell the $190 call
		"AAPL  230721C00195000", // Buy the $195 call
		1.0,                     // 1 contract (represents 100 shares)
		1.25,                    // $1.25 credit ($125 total)
		tastytrade.TimeInForceDay,
	)

	if err != nil {
		log.Fatalf("Failed to place option spread: %v", err)
	}

	fmt.Printf("Option spread placed! Order ID: %s, Status: %s\n",
		resp.Order.ID, resp.Order.Status)
}

// ExampleOTOCOOrder demonstrates placing a One-Triggers-OCO order
func ExampleOTOCOOrder() {
	client := tastytrade.NewClient(false)
	ctx := context.Background()

	// Login first (omitted for brevity)

	accountNumber := "ACCOUNT_NUMBER"

	// Define quantities and prices
	entryQty := 100.0
	entryPrice := 160.0
	entryPriceEffect := tastytrade.PriceEffectDebit

	profitQty := 100.0
	profitPrice := 180.0
	profitPriceEffect := tastytrade.PriceEffectCredit

	stopQty := 100.0
	stopTriggerPrice := 150.0

	// Create the OTOCO order
	// First we create the entry order (trigger order)
	triggerOrder := tastytrade.OrderRequest{
		OrderType:   tastytrade.OrderTypeLimit,
		TimeInForce: tastytrade.TimeInForceDay,
		Price:       &entryPrice,
		PriceEffect: &entryPriceEffect,
		Legs: []tastytrade.OrderLeg{
			{
				Symbol:         "AAPL",
				Quantity:       &entryQty,
				Action:         tastytrade.OrderDirectionBuyToOpen,
				InstrumentType: tastytrade.InstrumentTypeEquity,
			},
		},
	}

	// Create the profit target (limit) order
	profitOrder := tastytrade.OrderRequest{
		OrderType:   tastytrade.OrderTypeLimit,
		TimeInForce: tastytrade.TimeInForceGTC,
		Price:       &profitPrice,
		PriceEffect: &profitPriceEffect,
		Legs: []tastytrade.OrderLeg{
			{
				Symbol:         "AAPL",
				Quantity:       &profitQty,
				Action:         tastytrade.OrderDirectionSellToClose,
				InstrumentType: tastytrade.InstrumentTypeEquity,
			},
		},
	}

	// Create the stop loss order
	stopOrder := tastytrade.OrderRequest{
		OrderType:   tastytrade.OrderTypeStop,
		TimeInForce: tastytrade.TimeInForceGTC,
		StopTrigger: &stopTriggerPrice,
		Legs: []tastytrade.OrderLeg{
			{
				Symbol:         "AAPL",
				Quantity:       &stopQty,
				Action:         tastytrade.OrderDirectionSellToClose,
				InstrumentType: tastytrade.InstrumentTypeEquity,
			},
		},
	}

	// Bundle them into a complex order
	complexOrder := tastytrade.ComplexOrderRequest{
		Type:         tastytrade.ComplexOrderTypeOTOCO,
		TriggerOrder: &triggerOrder,
		Orders:       []tastytrade.OrderRequest{profitOrder, stopOrder},
	}

	// Place the complex order
	resp, err := client.PlaceComplexOrder(ctx, accountNumber, complexOrder)
	if err != nil {
		log.Fatalf("Failed to place OTOCO order: %v", err)
	}

	fmt.Printf("OTOCO order placed! Order ID: %s, Status: %s\n",
		resp.Order.ID, resp.Order.Status)
}

// ExampleAdvancedInstructions demonstrates using advanced instructions
func ExampleAdvancedInstructions() {
	client := tastytrade.NewClient(false)
	ctx := context.Background()

	// Login first (omitted for brevity)

	// Define order parameters
	accountNumber := "ACCOUNT_NUMBER"
	quantity := 100.0
	price := 175.25
	priceEffect := tastytrade.PriceEffectCredit

	// Create a limit order with strict position effect validation
	advancedInstructions := tastytrade.AdvancedInstructions{
		StrictPositionEffectValidation: true,
	}

	order := tastytrade.OrderRequest{
		OrderType:            tastytrade.OrderTypeLimit,
		TimeInForce:          tastytrade.TimeInForceDay,
		Price:                &price,
		PriceEffect:          &priceEffect,
		AdvancedInstructions: &advancedInstructions,
		Legs: []tastytrade.OrderLeg{
			{
				Symbol:         "AAPL",
				Quantity:       &quantity,
				Action:         tastytrade.OrderDirectionSellToClose,
				InstrumentType: tastytrade.InstrumentTypeEquity,
			},
		},
	}

	resp, err := client.PlaceOrder(ctx, accountNumber, order)
	if err != nil {
		// This might fail if you don't have a position to close
		log.Fatalf("Failed to place order: %v", err)
	}

	fmt.Printf("Order with advanced instructions placed! Order ID: %s, Status: %s\n",
		resp.Order.ID, resp.Order.Status)
}

// ExampleValidateOrder demonstrates how to validate an order
func ExampleValidateOrder() {
	// Create a potentially invalid order
	invalidQuantity := -10.0 // Negative quantity is invalid
	price := 150.0
	priceEffect := tastytrade.PriceEffectDebit

	order := tastytrade.OrderRequest{
		OrderType:   tastytrade.OrderTypeLimit,
		TimeInForce: tastytrade.TimeInForceDay,
		Price:       &price,
		PriceEffect: &priceEffect,
		Legs: []tastytrade.OrderLeg{
			{
				Symbol:         "AAPL",
				Quantity:       &invalidQuantity,
				Action:         tastytrade.OrderDirectionBuyToOpen,
				InstrumentType: tastytrade.InstrumentTypeEquity,
			},
		},
	}

	// Validate the order before submitting
	err := order.Validate()
	if err != nil {
		fmt.Printf("Order validation failed: %v\n", err)
		// Now fix the issues before submitting
	} else {
		fmt.Println("Order validation passed")
	}
}

// ExampleCancelOrder demonstrates how to cancel an existing order
func ExampleCancelOrder() {
	client := tastytrade.NewClient(false)
	ctx := context.Background()

	// Login first (omitted for brevity)

	accountNumber := "ACCOUNT_NUMBER"
	orderID := "ORDER_ID_TO_CANCEL"

	err := client.CancelOrder(ctx, accountNumber, orderID)
	if err != nil {
		log.Fatalf("Failed to cancel order: %v", err)
	}

	fmt.Println("Order cancelled successfully")
}

// ExampleGetOrders demonstrates how to retrieve existing orders
func ExampleGetOrders() {
	client := tastytrade.NewClient(false)
	ctx := context.Background()

	// Login first (omitted for brevity)

	accountNumber := "ACCOUNT_NUMBER"

	orders, err := client.GetOrders(ctx, accountNumber)
	if err != nil {
		log.Fatalf("Failed to get orders: %v", err)
	}

	fmt.Printf("Found %d orders\n", len(orders))

	// Print details for the first few orders
	for i, order := range orders {
		if i >= 3 {
			break // Just show first 3 orders
		}

		fmt.Printf("Order %d - ID: %s, Status: %s\n",
			i+1, order.Order.ID, order.Order.Status)

		// Print legs
		for j, leg := range order.Order.Legs {
			var quantity string
			if leg.Quantity != nil {
				quantity = fmt.Sprintf("%.2f", *leg.Quantity)
			} else {
				quantity = "N/A"
			}

			fmt.Printf("  Leg %d: %s %s %s (Qty: %s)\n",
				j+1, leg.Action, leg.InstrumentType, leg.Symbol, quantity)
		}
	}
}
