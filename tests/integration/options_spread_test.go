package integration

import (
	"context"
	"os"
	"testing"
	"time"

	"github.com/ryanhamamura/tastytrade/pkg/tastytrade"
)

// TestOptionsSpreadOrder tests placing a multi-leg options spread order
func TestOptionsSpreadOrder(t *testing.T) {
	// Load environment variables
	loadEnvFile(t)
	
	// Skip test if not running integration tests
	if os.Getenv("RUN_INTEGRATION_TESTS") != "true" {
		t.Skip("Skipping integration test. Set RUN_INTEGRATION_TESTS=true to run")
	}

	// Load test credentials from env
	username := os.Getenv("TT_TEST_USERNAME")
	password := os.Getenv("TT_TEST_PASSWORD")
	accountNumber := os.Getenv("TT_TEST_ACCOUNT_NUMBER")

	if username == "" || password == "" || accountNumber == "" {
		t.Fatal("Missing required environment variables for integration tests")
	}

	// Create client (use sandbox environment)
	client := tastytrade.NewClient(false)
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	// Login
	err := client.Login(ctx, username, password)
	if err != nil {
		t.Fatalf("Failed to login: %v", err)
	}

	// Get active expirations for SPY
	t.Log("Getting active expirations for SPY...")
	expirations, err := client.GetActiveExpirations(ctx, "SPY")
	if err != nil {
		t.Fatalf("Failed to get expirations: %v", err)
	}
	
	if len(expirations) == 0 {
		t.Fatal("No expirations found for SPY")
	}
	
	// Find an expiration at least 30 days out
	var targetExpiration string
	for _, exp := range expirations {
		if exp.DaysToExpiration >= 30 {
			targetExpiration = exp.ExpirationDate
			t.Logf("Using expiration %s (%d days out)", targetExpiration, exp.DaysToExpiration)
			break
		}
	}
	
	if targetExpiration == "" {
		// Just use the furthest available expiration
		targetExpiration = expirations[len(expirations)-1].ExpirationDate
		t.Logf("Using furthest available expiration: %s", targetExpiration)
	}

	// Get option chain to find strikes
	t.Log("Getting option chain...")
	options, err := client.GetOptionChain(ctx, "SPY")
	if err != nil {
		t.Fatalf("Failed to get option chain: %v", err)
	}
	
	// Find options for the target expiration
	var expirationOptions []tastytrade.EquityOption
	for _, option := range options {
		if option.ExpirationDate == targetExpiration {
			expirationOptions = append(expirationOptions, option)
		}
	}
	
	if len(expirationOptions) == 0 {
		t.Fatalf("No options found for expiration %s", targetExpiration)
	}
	
	// Find a put option to use as the short leg
	// Looking for a strike around ATM
	var shortPutStrike float64
	var longPutStrike float64
	var shortPutSymbol string
	var longPutSymbol string
	
	for _, option := range expirationOptions {
		if option.OptionType == "P" {
			// Just use this as our short put
			shortPutStrike = option.StrikePrice
			shortPutSymbol = option.Symbol
			
			// Find a lower strike for our long put (for a put spread)
			for _, opt2 := range expirationOptions {
				if opt2.OptionType == "P" && opt2.StrikePrice < shortPutStrike {
					longPutStrike = opt2.StrikePrice
					longPutSymbol = opt2.Symbol
					break
				}
			}
			
			if longPutSymbol != "" {
				break
			}
		}
	}
	
	if shortPutSymbol == "" || longPutSymbol == "" {
		t.Fatal("Could not find suitable options for a put spread")
	}
	
	t.Logf("Using put vertical spread: Short %s (%.2f) / Long %s (%.2f)", 
		shortPutSymbol, shortPutStrike, longPutSymbol, longPutStrike)

	// Create a put vertical spread order
	orderReq := tastytrade.OrderSubmitRequest{
		TimeInForce: "Day",
		OrderType:   "Limit",
		Price:       "0.50", // Small credit to avoid fills
		PriceEffect: "Credit",
		UnderlyingSymbol: "SPY",
		Legs: []tastytrade.OrderLeg{
			{
				InstrumentType: "Equity Option",
				Symbol:         shortPutSymbol,
				Quantity:       1,
				Action:         "Sell to Open",
			},
			{
				InstrumentType: "Equity Option",
				Symbol:         longPutSymbol,
				Quantity:       1,
				Action:         "Buy to Open",
			},
		},
	}

	// Submit the spread order
	t.Log("Submitting put vertical spread order...")
	orderResp, err := client.SubmitOrder(ctx, accountNumber, orderReq)
	if err != nil {
		t.Fatalf("Failed to submit spread order: %v", err)
	}
	
	orderID := orderResp.Data.Order.ID
	t.Logf("Spread order submitted successfully with ID: %d", orderID)
	
	// Verify the order has two legs
	if len(orderResp.Data.Order.Legs) != 2 {
		t.Errorf("Expected 2 legs in the order, got %d", len(orderResp.Data.Order.Legs))
	}
	
	// Verify the order price effect is Credit
	if orderResp.Data.Order.PriceEffect != "Credit" {
		t.Errorf("Expected price effect to be 'Credit', got '%s'", orderResp.Data.Order.PriceEffect)
	}
	
	// Allow time for the order to be processed
	time.Sleep(2 * time.Second)
	
	// Get the order to verify details
	retrievedOrder, err := client.GetOrder(ctx, accountNumber, orderID)
	if err != nil {
		t.Logf("Could not retrieve order: %v", err)
	} else {
		// Verify this is a multi-leg order
		if len(retrievedOrder.Legs) != 2 {
			t.Errorf("Retrieved order has %d legs instead of 2", len(retrievedOrder.Legs))
		} else {
			// Print the details of each leg
			for i, leg := range retrievedOrder.Legs {
				t.Logf("Leg %d: %s %s %d x %s", 
					i+1, leg.Action, leg.InstrumentType, leg.Quantity, leg.Symbol)
			}
		}
	}
	
	// Do a dry run of order cancellation and replacement
	t.Log("Trying to cancel and replace the spread order...")
	
	// Modify the credit amount
	modifiedOrderReq := orderReq
	modifiedOrderReq.Price = "0.40" // Lower credit
	
	// Try the cancel-replace
	modifiedOrderResp, err := client.CancelReplaceOrder(ctx, accountNumber, orderID, modifiedOrderReq)
	if err != nil {
		t.Logf("Cancel-replace failed: %v", err)
		t.Log("This is expected for some environments")
	} else {
		t.Log("Cancel-replace successful")
		// Update orderID if needed for cancellation
		if modifiedOrderResp.Data.Order.ID != 0 && modifiedOrderResp.Data.Order.ID != orderID {
			orderID = modifiedOrderResp.Data.Order.ID
		}
	}
	
	// Clean up: Cancel the order
	t.Log("Cleaning up: Cancelling spread order...")
	_, err = client.CancelOrder(ctx, accountNumber, orderID)
	if err != nil {
		t.Logf("Failed to cancel spread order: %v", err)
		t.Log("This can happen if the order was already cancelled")
	} else {
		t.Log("Spread order cancelled successfully")
	}
	
	// Check for any other open orders from this test and cancel them
	liveOrders, err := client.GetLiveOrders(ctx, accountNumber)
	if err == nil {
		for _, order := range liveOrders {
			// Look for likely orders from this test (SPY options)
			for _, leg := range order.Legs {
				// If any leg has SPY options and order was created recently, cancel it
				if leg.InstrumentType == "Equity Option" && 
				   (leg.Symbol == shortPutSymbol || leg.Symbol == longPutSymbol) {
					t.Logf("Cancelling additional test order ID: %d", order.ID)
					client.CancelOrder(ctx, accountNumber, order.ID)
					break
				}
			}
		}
	}
}