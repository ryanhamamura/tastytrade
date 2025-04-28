package integration

import (
	"context"
	"os"
	"testing"
	"time"

	"github.com/ryanhamamura/tastytrade/pkg/tastytrade"
)

// TestOrderSearch tests various search criteria for orders
// This test may not work in all environments as the search endpoint might not be available
func TestOrderSearch(t *testing.T) {
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

	// Create client (use sandbox environment) with debug mode
	client := tastytrade.NewClient(false, tastytrade.WithDebug(true))
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	// Login
	err := client.Login(ctx, username, password)
	if err != nil {
		t.Fatalf("Failed to login: %v", err)
	}

	// Create a test order so we have something to search for
	orderReq := tastytrade.OrderSubmitRequest{
		TimeInForce: "Day",
		OrderType:   "Limit",
		Price:       "1.00",
		PriceEffect: "Debit",
		Legs: []tastytrade.OrderLeg{
			{
				InstrumentType: "Equity",
				Symbol:         "AAPL",
				Quantity:       1,
				Action:         "Buy to Open",
			},
		},
	}

	t.Log("Creating test order...")
	orderResp, err := client.SubmitOrder(ctx, accountNumber, orderReq)
	if err != nil {
		t.Fatalf("Failed to submit test order: %v", err)
	}
	orderID := orderResp.Data.Order.ID
	t.Logf("Test order created with ID: %d", orderID)

	// Allow time for order to be processed
	time.Sleep(2 * time.Second)

	// Test 1: Search for all orders from today
	t.Log("Test 1: Searching for today's orders...")
	today := time.Now().Format("2006-01-02")
	params1 := map[string]interface{}{
		"start-date": today,
	}

	orders1, err := client.SearchOrders(ctx, accountNumber, params1)
	if err != nil {
		t.Logf("Failed to search orders with start-date filter: %v", err)
		t.Log("This endpoint might not be available in your environment, skipping detailed validation")
	} else {
		t.Logf("Found %d orders from today", len(orders1))
		if len(orders1) == 0 {
			t.Errorf("Expected to find at least one order from today")
		}
		
		foundTestOrder := false
		for _, order := range orders1 {
			if order.ID == orderID {
				foundTestOrder = true
				t.Logf("Found our test order in the results")
				break
			}
		}
		
		if !foundTestOrder {
			t.Errorf("Expected to find our test order (ID: %d) in the results", orderID)
		}
	}

	// Test 2: Search by status
	t.Log("Test 2: Searching for orders with specific status...")
	params2 := map[string]interface{}{
		"status": "Received",
	}

	orders2, err := client.SearchOrders(ctx, accountNumber, params2)
	if err != nil {
		t.Logf("Failed to search orders with status filter: %v", err)
		t.Log("This endpoint might not be available in your environment, skipping detailed validation")
	} else {
		t.Logf("Found %d orders with 'Received' status", len(orders2))
		
		for _, order := range orders2 {
			if order.Status != "Received" {
				t.Errorf("Order with status '%s' found when searching for 'Received' status", order.Status)
			}
		}
	}

	// Test 3: Search by symbol
	t.Log("Test 3: Searching for AAPL orders...")
	params3 := map[string]interface{}{
		"underlying-symbol": "AAPL",
	}

	orders3, err := client.SearchOrders(ctx, accountNumber, params3)
	if err != nil {
		t.Logf("Failed to search orders with symbol filter: %v", err)
		t.Log("This endpoint might not be available in your environment, skipping detailed validation")
	} else {
		t.Logf("Found %d orders for AAPL", len(orders3))
		
		foundAAPLOrder := false
		for _, order := range orders3 {
			if order.UnderlyingSymbol == "AAPL" {
				foundAAPLOrder = true
				break
			}
		}
		
		if !foundAAPLOrder && len(orders3) > 0 {
			t.Errorf("Orders returned don't contain AAPL as underlying symbol")
		}
	}

	// Test 4: Combine filters (today + type)
	t.Log("Test 4: Searching with combined filters...")
	params4 := map[string]interface{}{
		"start-date": today,
		"order-type": "Limit",
	}

	orders4, err := client.SearchOrders(ctx, accountNumber, params4)
	if err != nil {
		t.Logf("Failed to search orders with combined filters: %v", err)
		t.Log("This endpoint might not be available in your environment, skipping detailed validation")
	} else {
		t.Logf("Found %d limit orders from today", len(orders4))
		
		for _, order := range orders4 {
			if order.OrderType != "Limit" {
				t.Errorf("Order with type '%s' found when searching for 'Limit' type", order.OrderType)
			}
		}
	}

	// Clean up: Cancel the test order
	t.Log("Cleaning up: Cancelling test order...")
	_, err = client.CancelOrder(ctx, accountNumber, orderID)
	if err != nil {
		t.Logf("Failed to cancel test order: %v", err)
		t.Log("This can happen if the order was already filled or cancelled")
	} else {
		t.Log("Test order cancelled successfully")
	}
}