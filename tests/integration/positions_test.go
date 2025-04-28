package integration

import (
	"context"
	"os"
	"testing"
	"time"

	"github.com/ryanhamamura/tastytrade/pkg/tastytrade"
)

func TestGetPositions(t *testing.T) {
	// Load from .env file
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
		t.Fatal("Missing required environment variables for integration tests: TT_TEST_USERNAME, TT_TEST_PASSWORD, TT_TEST_ACCOUNT_NUMBER")
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

	t.Run("Get All Positions", func(t *testing.T) {
		positions, err := client.GetPositions(ctx, accountNumber)
		if err != nil {
			t.Fatalf("Failed to get positions: %v", err)
		}

		// Just check that we can successfully get positions, without checking specific values
		t.Logf("Retrieved %d positions", len(positions))
		
		// Print the first position if available
		if len(positions) > 0 {
			t.Logf("First position: %s %s (Quantity: %s %s)", 
				positions[0].InstrumentType, 
				positions[0].Symbol,
				positions[0].Quantity,
				positions[0].QuantityDirection)
		}
	})

	t.Run("Get Open Positions", func(t *testing.T) {
		positions, err := client.GetOpenPositions(ctx, accountNumber)
		if err != nil {
			t.Fatalf("Failed to get open positions: %v", err)
		}

		// Verify that all returned positions are open
		for _, position := range positions {
			if position.QuantityDirection == "Zero" {
				t.Errorf("Expected only open positions, but got a closed position: %s", position.Symbol)
			}
		}

		t.Logf("Retrieved %d open positions", len(positions))
	})

	t.Run("Filter Positions By Instrument Type", func(t *testing.T) {
		// First get all positions
		allPositions, err := client.GetPositions(ctx, accountNumber)
		if err != nil {
			t.Fatalf("Failed to get positions: %v", err)
		}
		
		if len(allPositions) == 0 {
			t.Skip("Skipping test, no positions found")
		}
		
		// Use the instrument type of the first position for the filter test
		instrumentType := allPositions[0].InstrumentType
		
		filteredPositions, err := client.GetPositionsByInstrumentType(ctx, accountNumber, instrumentType)
		if err != nil {
			t.Fatalf("Failed to filter positions by instrument type: %v", err)
		}

		// Verify that all returned positions match the instrument type
		for _, position := range filteredPositions {
			if position.InstrumentType != instrumentType {
				t.Errorf("Expected instrument type %s, but got %s", instrumentType, position.InstrumentType)
			}
		}

		t.Logf("Retrieved %d positions with instrument type %s", len(filteredPositions), instrumentType)
	})

	t.Run("Search Positions", func(t *testing.T) {
		// First get all positions
		allPositions, err := client.GetPositions(ctx, accountNumber)
		if err != nil {
			t.Fatalf("Failed to get positions: %v", err)
		}
		
		if len(allPositions) == 0 {
			t.Skip("Skipping test, no positions found")
		}
		
		// Use properties from the first position for search test
		searchParams := map[string]interface{}{
			"instrument-type": allPositions[0].InstrumentType,
		}
		
		searchResults, err := client.SearchPositions(ctx, accountNumber, searchParams)
		if err != nil {
			t.Fatalf("Failed to search positions: %v", err)
		}

		// Verify that we got at least one result
		if len(searchResults) == 0 {
			t.Errorf("Expected at least one position in search results")
		}

		t.Logf("Search returned %d positions", len(searchResults))
	})
}