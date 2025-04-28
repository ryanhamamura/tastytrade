package tastytrade

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/url"
	"strconv"
	"strings"
	"time"
)

// SearchOrders searches for orders in an account based on various filters
func (c *Client) SearchOrders(ctx context.Context, accountNumber string, params map[string]interface{}) ([]Order, error) {
	if err := c.EnsureValidToken(ctx); err != nil {
		return nil, err
	}

	// Build query parameters
	query := url.Values{}
	for key, value := range params {
		switch v := value.(type) {
		case string:
			query.Add(key, v)
		case []string:
			for _, val := range v {
				query.Add(key+"[]", val)
			}
		case int:
			query.Add(key, strconv.Itoa(v))
		case time.Time:
			query.Add(key, v.Format(time.RFC3339))
		}
	}

	endpoint := fmt.Sprintf("/accounts/%s/orders", accountNumber)
	if len(query) > 0 {
		endpoint += "?" + query.Encode()
	}
	
	// Debug log the endpoint
	if c.Debug {
		fmt.Printf("DEBUG: SearchOrders URL: %s\n", endpoint)
	}

	var response OrdersResponse
	err := c.doRequest(ctx, "GET", endpoint, nil, true, &response)
	if err != nil {
		return nil, err
	}

	return response.Data.Items, nil
}

// GetLiveOrders gets all live orders for an account
func (c *Client) GetLiveOrders(ctx context.Context, accountNumber string) ([]Order, error) {
	if err := c.EnsureValidToken(ctx); err != nil {
		return nil, err
	}

	endpoint := fmt.Sprintf("/accounts/%s/orders/live", accountNumber)

	var response OrdersResponse
	err := c.doRequest(ctx, "GET", endpoint, nil, true, &response)
	if err != nil {
		return nil, err
	}

	return response.Data.Items, nil
}

// DryRunOrder performs a dry run of an order to validate it and get fee/buying power information
func (c *Client) DryRunOrder(ctx context.Context, accountNumber string, order OrderSubmitRequest) (*DryRunOrderResponse, error) {
	if err := c.EnsureValidToken(ctx); err != nil {
		return nil, err
	}

	endpoint := fmt.Sprintf("/accounts/%s/orders/dry-run", accountNumber)

	reqBody, err := json.Marshal(order)
	if err != nil {
		return nil, err
	}

	var response DryRunOrderResponse
	err = c.doRequest(ctx, "POST", endpoint, bytes.NewBuffer(reqBody), true, &response)
	if err != nil {
		return nil, err
	}

	return &response, nil
}

// SubmitOrder submits an order for execution
func (c *Client) SubmitOrder(ctx context.Context, accountNumber string, order OrderSubmitRequest) (*OrderResponse, error) {
	if err := c.EnsureValidToken(ctx); err != nil {
		return nil, err
	}

	endpoint := fmt.Sprintf("/accounts/%s/orders", accountNumber)

	reqBody, err := json.Marshal(order)
	if err != nil {
		return nil, err
	}

	var response OrderResponse
	err = c.doRequest(ctx, "POST", endpoint, bytes.NewBuffer(reqBody), true, &response)
	if err != nil {
		return nil, err
	}

	return &response, nil
}

// CancelOrder requests cancellation of an order
func (c *Client) CancelOrder(ctx context.Context, accountNumber string, orderID int64) (*Order, error) {
	if err := c.EnsureValidToken(ctx); err != nil {
		return nil, err
	}

	endpoint := fmt.Sprintf("/accounts/%s/orders/%d", accountNumber, orderID)

	var response struct {
		Data Order `json:"data"`
	}
	err := c.doRequest(ctx, "DELETE", endpoint, nil, true, &response)
	if err != nil {
		return nil, err
	}

	return &response.Data, nil
}

// CancelReplaceOrder cancels and replaces an existing order
// This function handles the TastyTrade API behavior where cancel-replace:
// 1. Cancels the original order
// 2. Creates a new order with the updated parameters
// 3. Returns a response that doesn't directly include the new order ID
func (c *Client) CancelReplaceOrder(ctx context.Context, accountNumber string, orderID int64, order OrderSubmitRequest) (*OrderResponse, error) {
	if err := c.EnsureValidToken(ctx); err != nil {
		return nil, err
	}

	// Get original order to check its properties (for later comparison)
	originalOrder, err := c.GetOrder(ctx, accountNumber, orderID)
	if err != nil {
		return nil, fmt.Errorf("failed to get original order: %w", err)
	}

	// Store original legs symbols and quantities for matching
	originalSymbols := make(map[string]int)
	for _, leg := range originalOrder.Legs {
		originalSymbols[leg.Symbol] = leg.Quantity
	}

	// Send cancel-replace request
	endpoint := fmt.Sprintf("/accounts/%s/orders/%d", accountNumber, orderID)
	reqBody, err := json.Marshal(order)
	if err != nil {
		return nil, err
	}

	var response OrderResponse
	err = c.doRequest(ctx, "PUT", endpoint, bytes.NewBuffer(reqBody), true, &response)
	if err != nil {
		return nil, err
	}

	// The API doesn't return the new order ID in the response
	// We need to find the newly created order by checking live orders
	// Try a few times with increasing delays
	var liveOrders []Order
	var listErr error
	
	// Try up to 3 times with increasing delays
	for attempt := 0; attempt < 3; attempt++ {
		sleepDuration := time.Duration(500*(attempt+1)) * time.Millisecond
		time.Sleep(sleepDuration)
		
		liveOrders, listErr = c.GetLiveOrders(ctx, accountNumber)
		if listErr == nil && len(liveOrders) > 0 {
			break
		}
	}
	
	if listErr != nil {
		// Don't fail the whole operation, just return the original response
		return &response, nil
	}

	// Look for the newly created order with matching characteristics
	for _, liveOrder := range liveOrders {
		// Skip the original order or any order that's not in a Received/Working state
		if liveOrder.ID == orderID || (liveOrder.Status != "Received" && liveOrder.Status != "Working") {
			continue
		}

		// Check if it's likely our replacement order:
		// 1. Should have the new price
		// 2. Should have the same legs (symbols & quantities)
		// 3. Should be recently created
		
		// Check if price matches our requested price
		if order.Price != "" && liveOrder.Price != order.Price {
			continue
		}

		// Check if the legs match
		if len(liveOrder.Legs) != len(order.Legs) {
			continue
		}

		legMatch := true
		for _, leg := range liveOrder.Legs {
			// Check if this leg matches one of our original order legs
			if requestedQty, exists := originalSymbols[leg.Symbol]; !exists || requestedQty != leg.Quantity {
				legMatch = false
				break
			}
		}

		if legMatch {
			// Found our replacement order - update the response
			response.Data.Order = liveOrder
			break
		}
	}

	return &response, nil
}

// GetOrder retrieves information about a specific order
func (c *Client) GetOrder(ctx context.Context, accountNumber string, orderID int64) (*Order, error) {
	if err := c.EnsureValidToken(ctx); err != nil {
		return nil, err
	}

	endpoint := fmt.Sprintf("/accounts/%s/orders/%d", accountNumber, orderID)

	var response struct {
		Data Order `json:"data"`
	}
	err := c.doRequest(ctx, "GET", endpoint, nil, true, &response)
	if err != nil {
		return nil, err
	}

	return &response.Data, nil
}

// TODO: Implement complex order functionality (OTOCO, OCO, OTO)
// - SubmitComplexOrder
// - CancelComplexOrder
// - GetComplexOrder

// GetOrderTypes returns a list of valid order types
func GetOrderTypes() []string {
	return []string{"Limit", "Market", "Stop", "Stop Limit"}
}

// GetTimeInForceOptions returns a list of valid time-in-force options
func GetTimeInForceOptions() []string {
	return []string{"Day", "GTC", "GTD", "IOC", "FOK"}
}

// GetPriceEffects returns a list of valid price effects
func GetPriceEffects() []string {
	return []string{"Debit", "Credit"}
}

// GetInstrumentTypes returns a list of valid instrument types
func GetInstrumentTypes() []string {
	return []string{"Equity", "Equity Option", "Future", "Future Option", "Cryptocurrency"}
}

// GetActionTypes returns a list of valid action types
func GetActionTypes() []string {
	return []string{"Buy to Open", "Buy to Close", "Sell to Open", "Sell to Close"}
}

// BuildOrderFromUserInput helps create an order from user input in CLI
func BuildOrderFromUserInput(scanner *bufio.Scanner, accountNumber string) (*OrderSubmitRequest, error) {
	order := &OrderSubmitRequest{}

	// 1. Time in force
	fmt.Println("Select Time in Force:")
	for i, tif := range GetTimeInForceOptions() {
		fmt.Printf("%d. %s\n", i+1, tif)
	}

	fmt.Print("Enter selection (1-5): ")
	if !scanner.Scan() {
		return nil, fmt.Errorf("failed to read input")
	}

	tifIndex, err := strconv.Atoi(strings.TrimSpace(scanner.Text()))
	if err != nil || tifIndex < 1 || tifIndex > len(GetTimeInForceOptions()) {
		return nil, fmt.Errorf("invalid selection")
	}
	order.TimeInForce = GetTimeInForceOptions()[tifIndex-1]

	// 2. Order type
	fmt.Println("\nSelect Order Type:")
	for i, ot := range GetOrderTypes() {
		fmt.Printf("%d. %s\n", i+1, ot)
	}

	fmt.Print("Enter selection (1-4): ")
	if !scanner.Scan() {
		return nil, fmt.Errorf("failed to read input")
	}

	otIndex, err := strconv.Atoi(strings.TrimSpace(scanner.Text()))
	if err != nil || otIndex < 1 || otIndex > len(GetOrderTypes()) {
		return nil, fmt.Errorf("invalid selection")
	}
	order.OrderType = GetOrderTypes()[otIndex-1]

	// 3. Price and effect (for limit orders)
	if order.OrderType == "Limit" || order.OrderType == "Stop Limit" {
		fmt.Print("\nEnter Price: ")
		if !scanner.Scan() {
			return nil, fmt.Errorf("failed to read input")
		}
		order.Price = strings.TrimSpace(scanner.Text())

		fmt.Println("\nSelect Price Effect:")
		for i, pe := range GetPriceEffects() {
			fmt.Printf("%d. %s\n", i+1, pe)
		}

		fmt.Print("Enter selection (1-2): ")
		if !scanner.Scan() {
			return nil, fmt.Errorf("failed to read input")
		}

		peIndex, err := strconv.Atoi(strings.TrimSpace(scanner.Text()))
		if err != nil || peIndex < 1 || peIndex > len(GetPriceEffects()) {
			return nil, fmt.Errorf("invalid selection")
		}
		order.PriceEffect = GetPriceEffects()[peIndex-1]
	}

	// 4. Stop trigger (for stop orders)
	if order.OrderType == "Stop" || order.OrderType == "Stop Limit" {
		fmt.Print("\nEnter Stop Trigger Price: ")
		if !scanner.Scan() {
			return nil, fmt.Errorf("failed to read input")
		}
		order.StopTrigger = strings.TrimSpace(scanner.Text())
	}

	// 5. Order legs
	fmt.Print("\nHow many legs in this order? ")
	if !scanner.Scan() {
		return nil, fmt.Errorf("failed to read input")
	}

	numLegs, err := strconv.Atoi(strings.TrimSpace(scanner.Text()))
	if err != nil || numLegs < 1 {
		return nil, fmt.Errorf("invalid number of legs")
	}

	order.Legs = make([]OrderLeg, numLegs)

	for i := 0; i < numLegs; i++ {
		fmt.Printf("\n--- Leg %d ---\n", i+1)

		// Instrument type
		fmt.Println("Select Instrument Type:")
		for j, it := range GetInstrumentTypes() {
			fmt.Printf("%d. %s\n", j+1, it)
		}

		fmt.Print("Enter selection (1-5): ")
		if !scanner.Scan() {
			return nil, fmt.Errorf("failed to read input")
		}

		itIndex, err := strconv.Atoi(strings.TrimSpace(scanner.Text()))
		if err != nil || itIndex < 1 || itIndex > len(GetInstrumentTypes()) {
			return nil, fmt.Errorf("invalid selection")
		}
		order.Legs[i].InstrumentType = GetInstrumentTypes()[itIndex-1]

		// Symbol
		fmt.Print("\nEnter Symbol: ")
		if !scanner.Scan() {
			return nil, fmt.Errorf("failed to read input")
		}
		order.Legs[i].Symbol = strings.TrimSpace(scanner.Text())

		// Quantity
		fmt.Print("\nEnter Quantity: ")
		if !scanner.Scan() {
			return nil, fmt.Errorf("failed to read input")
		}

		qty, err := strconv.Atoi(strings.TrimSpace(scanner.Text()))
		if err != nil || qty < 1 {
			return nil, fmt.Errorf("invalid quantity")
		}
		order.Legs[i].Quantity = qty

		// Action
		fmt.Println("\nSelect Action:")
		for j, act := range GetActionTypes() {
			fmt.Printf("%d. %s\n", j+1, act)
		}

		fmt.Print("Enter selection (1-4): ")
		if !scanner.Scan() {
			return nil, fmt.Errorf("failed to read input")
		}

		actIndex, err := strconv.Atoi(strings.TrimSpace(scanner.Text()))
		if err != nil || actIndex < 1 || actIndex > len(GetActionTypes()) {
			return nil, fmt.Errorf("invalid selection")
		}
		order.Legs[i].Action = GetActionTypes()[actIndex-1]
	}

	return order, nil
}

func PrintOrder(order *Order) {
	fmt.Printf("ID: %d\n", order.ID)
	fmt.Printf("Account: %s\n", order.AccountNumber)
	fmt.Printf("Status: %s\n", order.Status)
	if order.ContingentStatus != "" {
		fmt.Printf("Contingent Status: %s\n", order.ContingentStatus)
	}
	fmt.Printf("Type: %s\n", order.OrderType)
	fmt.Printf("Time in Force: %s\n", order.TimeInForce)
	if order.UnderlyingSymbol != "" {
		fmt.Printf("Underlying Symbol: %s\n", order.UnderlyingSymbol)
	}
	if order.Price != "" {
		fmt.Printf("Price: %s (%s)\n", order.Price, order.PriceEffect)
	}
	if order.StopTrigger != "" {
		fmt.Printf("Stop Trigger: %s\n", order.StopTrigger)
	}
	fmt.Printf("Cancellable: %v\n", order.Cancellable)
	fmt.Printf("Editable: %v\n", order.Editable)

	fmt.Println("\nLegs:")
	for i, leg := range order.Legs {
		fmt.Printf("  Leg %d: %s %s %d x %s\n",
			i+1,
			leg.Action,
			leg.InstrumentType,
			leg.Quantity,
			leg.Symbol)

		if len(leg.Fills) > 0 {
			fmt.Println("  Fills:")
			for j, fill := range leg.Fills {
				fmt.Printf("    Fill %d: %d @ %s (%s)\n",
					j+1,
					fill.FillQuantity,
					fill.FillPrice,
					fill.FilledAt.Format(time.RFC3339))
			}
		}
	}

	if !order.ReceivedAt.IsZero() {
		fmt.Printf("\nReceived At: %s\n", order.ReceivedAt.Format(time.RFC3339))
	}
}
