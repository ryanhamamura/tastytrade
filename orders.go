package tastytrade

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"time"
)

// OrderType represents the type of order
type OrderType string

const (
	OrderTypeLimit          OrderType = "Limit"
	OrderTypeMarket         OrderType = "Market"
	OrderTypeStop           OrderType = "Stop"
	OrderTypeStopLimit      OrderType = "Stop Limit"
	OrderTypeNotionalMarket OrderType = "Notional Market"
)

// TimeInForce represents in force for an order
type TimeInForce string

const (
	TimeInForceDay TimeInForce = "Day"
	TimeInForceGTC TimeInForce = "GTC" // Good Til Cancelled
	TimeInForceGTD TimeInForce = "GTD" // Good Til Date
)

// OrderDirection represents the direction of an order
type OrderDirection string

const (
	OrderDirectionBuyToOpen   OrderDirection = "Buy to Open"   // Updated to match API
	OrderDirectionSellToOpen  OrderDirection = "Sell to Open"  // Updated to match API
	OrderDirectionBuyToClose  OrderDirection = "Buy to Close"  // Updated to match API
	OrderDirectionSellToClose OrderDirection = "Sell to Close" // Updated to match API
)

// PriceEffect represents the price's direction in relation to the account
type PriceEffect string

const (
	PriceEffectCredit PriceEffect = "Credit"
	PriceEffectDebit  PriceEffect = "Debit"
)

// OrderStatus represents the status of an order
type OrderStatus string

const (
	OrderStatusReceived   OrderStatus = "Received"
	OrderStatusCanceled   OrderStatus = "Canceled"
	OrderStatusFilled     OrderStatus = "Filled"
	OrderStatusRejected   OrderStatus = "Rejected"
	OrderStatusWorking    OrderStatus = "Working"
	OrderStatusPending    OrderStatus = "Pending"
	OrderStatusContingent OrderStatus = "Contingent"
	OrderStatusRouted     OrderStatus = "Routed"
	OrderStatusExpired    OrderStatus = "Expired"
)

// InstrumentType represents the type of financial instrument
type InstrumentType string

const (
	InstrumentTypeEquity         InstrumentType = "Equity"
	InstrumentTypeEquityOption   InstrumentType = "Equity Option"
	InstrumentTypeFuture         InstrumentType = "Future"
	InstrumentTypeFutureOption   InstrumentType = "Future Option"
	InstrumentTypeCryptocurrency InstrumentType = "Cryptocurrency"
)

// AdvancedInstructions represents advanced instructions for order handling
type AdvancedInstructions struct {
	StrictPositionEffectValidation bool `json:"strict-position-effect-validation,omitempty"`
}

// OrderLeg represents a leg in an order
type OrderLeg struct {
	Symbol         string         `json:"symbol"`
	Quantity       *float64       `json:"quantity,omitempty"` // Pointer to omit for Notional Market orders
	Action         OrderDirection `json:"action"`
	InstrumentType InstrumentType `json:"instrument-type"`
}

// OrderRequest represents a new order request
type OrderRequest struct {
	AccountNumber        string                `json:"account-number,omitempty"`
	OrderType            OrderType             `json:"order-type"`
	TimeInForce          TimeInForce           `json:"time-in-force"`
	GtcDate              string                `json:"gtc-date,omitempty"`     // Required for GTD orders
	Price                *float64              `json:"price,omitempty"`        // Not used for Market, Notional Market, or Stop orders
	PriceEffect          *PriceEffect          `json:"price-effect,omitempty"` // Not used for Market, Stop orders
	StopTrigger          *float64              `json:"stop-trigger,omitempty"` // Required for Stop and Stop Limit orders
	Value                *float64              `json:"value,omitempty"`        // Required for Notional Market orders
	ValueEffect          *PriceEffect          `json:"value-effect,omitempty"` // Required for Notional Market orders
	Source               string                `json:"source,omitempty"`
	AdvancedInstructions *AdvancedInstructions `json:"advanced-instructions,omitempty"`
	Legs                 []OrderLeg            `json:"legs"`
}

// Fill represents a fill for an order leg
type Fill struct {
	ID            string    `json:"id"`
	Quantity      float64   `json:"quantity"`
	FillPrice     float64   `json:"fill-price"`
	FilledAt      time.Time `json:"filled-at"`
	CommissionFee float64   `json:"commission-fee,omitempty"`
}

// OrderLegDetail represents a leg with fills in an order response
type OrderLegDetail struct {
	OrderLeg
	Fills []Fill `json:"fills,omitempty"`
}

// OrderResponse represents the response after placing an order
type OrderResponse struct {
	BuyingPowerEffect     json.RawMessage `json:"buying-power-effect,omitempty"`
	ClosingFeeCalculation json.RawMessage `json:"closing-fee-calculation,omitempty"`
	FeeCalculation        json.RawMessage `json:"fee-calculation,omitempty"`
	Order                 struct {
		ID         string           `json:"id"`
		Status     OrderStatus      `json:"status"`
		ReceivedAt time.Time        `json:"received-at"`
		Legs       []OrderLegDetail `json:"legs"`
	} `json:"order"`
	Warnings []string `json:"warnings,omitempty"`
}

// ComplexOrderType represents the type of complex order
type ComplexOrderType string

const (
	ComplexOrderTypeOTOCO ComplexOrderType = "OTOCO" // One-Triggers-OCO
	ComplexOrderTypeOCO   ComplexOrderType = "OCO"   // One-Cancels-Other
	ComplexOrderTypeOTO   ComplexOrderType = "OTO"   // One-Triggers-Other
	ComplexOrderTypePAIRS ComplexOrderType = "PAIRS" // Pairs
)

// ComplexOrderRequest represents a complex order request
type ComplexOrderRequest struct {
	Type         ComplexOrderType `json:"type"`
	TriggerOrder *OrderRequest    `json:"trigger-order,omitempty"` // Required for OTOCO and OTO
	Orders       []OrderRequest   `json:"orders"`
}

// Validate performs basic validation on an order request based on order type rules
func (o *OrderRequest) Validate() error {
	// Common validation
	if len(o.Legs) == 0 {
		return fmt.Errorf("order must have at least one leg")
	}

	// Validate order type specific rules
	switch o.OrderType {
	case OrderTypeMarket:
		if len(o.Legs) != 1 {
			return fmt.Errorf("market orders must have only one leg")
		}
		if o.Price != nil || o.PriceEffect != nil {
			return fmt.Errorf("market orders must not include price or price-effect")
		}
		if o.TimeInForce == TimeInForceGTC {
			return fmt.Errorf("market orders time-in-force must not be GTC")
		}

	case OrderTypeLimit:
		if o.Price == nil {
			return fmt.Errorf("limit orders must include price")
		}
		if o.PriceEffect == nil {
			return fmt.Errorf("limit orders must include price-effect")
		}

	case OrderTypeStop:
		if o.Price != nil || o.PriceEffect != nil {
			return fmt.Errorf("stop orders must not include price or price-effect")
		}
		if o.StopTrigger == nil {
			return fmt.Errorf("stop orders must include stop-trigger")
		}

	case OrderTypeStopLimit:
		if o.Price == nil {
			return fmt.Errorf("stop limit orders must include price")
		}
		if o.PriceEffect == nil {
			return fmt.Errorf("stop limit orders must include price-effect")
		}
		if o.StopTrigger == nil {
			return fmt.Errorf("stop limit orders must include stop-trigger")
		}

	case OrderTypeNotionalMarket:
		if len(o.Legs) != 1 {
			return fmt.Errorf("notional market orders must have only one leg")
		}
		if o.Value == nil {
			return fmt.Errorf("notional market orders must include value")
		}
		if o.ValueEffect == nil {
			return fmt.Errorf("notional market orders must include value-effect")
		}
		// Check if any leg has quantity
		for _, leg := range o.Legs {
			if leg.Quantity != nil {
				return fmt.Errorf("notional market order legs must not include quantity")
			}
		}
	}

	// Validate time in force
	if o.TimeInForce == TimeInForceGTD && o.GtcDate == "" {
		return fmt.Errorf("GTD orders must include gtc-date")
	}

	// Validate instrument type limits on number of legs
	maxLegs := map[InstrumentType]int{
		InstrumentTypeEquity:         1,
		InstrumentTypeFuture:         1,
		InstrumentTypeCryptocurrency: 1,
		InstrumentTypeEquityOption:   4,
		InstrumentTypeFutureOption:   4,
	}

	legsByInstrumentType := make(map[InstrumentType]int)
	for _, leg := range o.Legs {
		legsByInstrumentType[leg.InstrumentType]++

		// Check if a required quantity is missing for non-notional orders
		if o.OrderType != OrderTypeNotionalMarket && leg.Quantity == nil {
			return fmt.Errorf("quantity is required for %s leg", leg.InstrumentType)
		}
	}

	for instrumentType, count := range legsByInstrumentType {
		if max, exists := maxLegs[instrumentType]; exists && count > max {
			return fmt.Errorf("%s orders are limited to %d legs", instrumentType, max)
		}
	}

	// Check for duplicate symbols
	symbols := make(map[string]bool)
	for _, leg := range o.Legs {
		if symbols[leg.Symbol] {
			return fmt.Errorf("duplicate symbol %s in order legs", leg.Symbol)
		}
		symbols[leg.Symbol] = true
	}

	return nil
}

// PlaceOrder places a new order
func (c *Client) PlaceOrder(ctx context.Context, accountNumber string, order OrderRequest) (*OrderResponse, error) {
	if err := c.EnsureValidToken(ctx); err != nil {
		return nil, err
	}

	// Add the account number to the order
	order.AccountNumber = accountNumber

	// Validate the order
	if err := order.Validate(); err != nil {
		return nil, err
	}

	reqBody, err := json.Marshal(order)
	if err != nil {
		return nil, err
	}

	endpoint := fmt.Sprintf("/accounts/%s/orders", accountNumber)
	var resp OrderResponse
	err = c.doRequest(ctx, "POST", endpoint, bytes.NewBuffer(reqBody), true, &resp)
	if err != nil {
		return nil, err
	}

	return &resp, nil
}

// DryRunOrder validates an order without submitting it
func (c *Client) DryRunOrder(ctx context.Context, accountNumber string, order OrderRequest) (*OrderResponse, error) {
	if err := c.EnsureValidToken(ctx); err != nil {
		return nil, err
	}

	// Add the account number to the order
	order.AccountNumber = accountNumber

	reqBody, err := json.Marshal(order)
	if err != nil {
		return nil, err
	}

	endpoint := fmt.Sprintf("/accounts/%s/orders/dry-run", accountNumber)
	var resp OrderResponse
	err = c.doRequest(ctx, "POST", endpoint, bytes.NewBuffer(reqBody), true, &resp)
	if err != nil {
		return nil, err
	}

	return &resp, nil
}

// GetOrder retrieves the status of an order
func (c *Client) GetOrder(ctx context.Context, accountNumber, orderID string) (*OrderResponse, error) {
	if err := c.EnsureValidToken(ctx); err != nil {
		return nil, err
	}

	endpoint := fmt.Sprintf("/accounts/%s/orders/%s", accountNumber, orderID)
	var resp OrderResponse
	err := c.doRequest(ctx, "GET", endpoint, nil, true, &resp)
	if err != nil {
		return nil, err
	}

	return &resp, nil
}

// CancelOrder cancels an order
func (c *Client) CancelOrder(ctx context.Context, accountNumber, orderID string) error {
	if err := c.EnsureValidToken(ctx); err != nil {
		return err
	}

	endpoint := fmt.Sprintf("/accounts/%s/orders/%s", accountNumber, orderID)
	return c.doRequest(ctx, "DELETE", endpoint, nil, true, nil)
}

// GetOrders retrieves orders for an account
func (c *Client) GetOrders(ctx context.Context, accountNumber string) ([]OrderResponse, error) {
	if err := c.EnsureValidToken(ctx); err != nil {
		return nil, err
	}

	endpoint := fmt.Sprintf("/accounts/%s/orders", accountNumber)
	var resp []OrderResponse
	err := c.doRequest(ctx, "GET", endpoint, nil, true, &resp)
	if err != nil {
		return nil, err
	}

	return resp, nil
}

// PlaceComplexOrder places a complex order (OTOCO, OCO, OTO, PAIRS)
func (c *Client) PlaceComplexOrder(ctx context.Context, accountNumber string, order ComplexOrderRequest) (*OrderResponse, error) {
	if err := c.EnsureValidToken(ctx); err != nil {
		return nil, err
	}

	// For OTOCO and OTO orders, the trigger-order is required
	if (order.Type == ComplexOrderTypeOTOCO || order.Type == ComplexOrderTypeOTO) && order.TriggerOrder == nil {
		return nil, fmt.Errorf("%s orders must include a trigger-order", order.Type)
	}

	// For OCO orders, there must be at least 2 orders
	if order.Type == ComplexOrderTypeOCO && len(order.Orders) < 2 {
		return nil, fmt.Errorf("OCO orders must include at least 2 orders")
	}

	reqBody, err := json.Marshal(order)
	if err != nil {
		return nil, err
	}

	endpoint := fmt.Sprintf("/accounts/%s/complex-orders", accountNumber)
	var resp OrderResponse
	err = c.doRequest(ctx, "POST", endpoint, bytes.NewBuffer(reqBody), true, &resp)
	if err != nil {
		return nil, err
	}

	return &resp, nil
}

// Helper functions for common order types

// PlaceEquityMarketOrder is a helper for placing a simple equity market order
func (c *Client) PlaceEquityMarketOrder(
	ctx context.Context,
	accountNumber string,
	symbol string,
	quantity float64,
	action OrderDirection,
) (*OrderResponse, error) {
	qty := quantity // Create a copy to use address of
	order := OrderRequest{
		OrderType:   OrderTypeMarket,
		TimeInForce: TimeInForceDay,
		Legs: []OrderLeg{
			{
				InstrumentType: InstrumentTypeEquity,
				Symbol:         symbol,
				Quantity:       &qty,
				Action:         action,
			},
		},
	}

	return c.PlaceOrder(ctx, accountNumber, order)
}

// PlaceEquityLimitOrder is a helper for placing a simple equity limit order
func (c *Client) PlaceEquityLimitOrder(
	ctx context.Context,
	accountNumber string,
	symbol string,
	quantity float64,
	price float64,
	action OrderDirection,
	timeInForce TimeInForce,
) (*OrderResponse, error) {
	qty := quantity   // Create a copy to use address of
	priceVal := price // Create a copy to use address of

	// Determine price effect based on action
	var priceEffect PriceEffect
	if action == OrderDirectionBuyToOpen || action == OrderDirectionBuyToClose {
		priceEffect = PriceEffectDebit
	} else {
		priceEffect = PriceEffectCredit
	}

	order := OrderRequest{
		OrderType:   OrderTypeLimit,
		TimeInForce: timeInForce,
		Price:       &priceVal,
		PriceEffect: &priceEffect,
		Legs: []OrderLeg{
			{
				InstrumentType: InstrumentTypeEquity,
				Symbol:         symbol,
				Quantity:       &qty,
				Action:         action,
			},
		},
	}

	return c.PlaceOrder(ctx, accountNumber, order)
}

// PlaceEquityNotionalMarketOrder is a helper for placing a notional market order for equities
func (c *Client) PlaceEquityNotionalMarketOrder(
	ctx context.Context,
	accountNumber string,
	symbol string,
	dollarAmount float64,
	action OrderDirection,
) (*OrderResponse, error) {
	value := dollarAmount // Create a copy to use address of

	// Determine value effect based on action
	var valueEffect PriceEffect
	if action == OrderDirectionBuyToOpen || action == OrderDirectionBuyToClose {
		valueEffect = PriceEffectDebit
	} else {
		valueEffect = PriceEffectCredit
	}

	order := OrderRequest{
		OrderType:   OrderTypeNotionalMarket,
		TimeInForce: TimeInForceDay,
		Value:       &value,
		ValueEffect: &valueEffect,
		Legs: []OrderLeg{
			{
				InstrumentType: InstrumentTypeEquity,
				Symbol:         symbol,
				Action:         action,
				// No quantity for notional orders
			},
		},
	}

	return c.PlaceOrder(ctx, accountNumber, order)
}

// PlaceEquityOptionSpreadOrder is a helper for placing an equity option spread
// The first leg is considered the sold option, and the second leg is the purchased option
func (c *Client) PlaceEquityOptionSpreadOrder(
	ctx context.Context,
	accountNumber string,
	soldOptionSymbol string,
	boughtOptionSymbol string,
	quantity float64,
	creditAmount float64, // Credit amount desired
	timeInForce TimeInForce,
) (*OrderResponse, error) {
	qty := quantity       // Create a copy to use address of
	price := creditAmount // Create a copy to use address of
	priceEffect := PriceEffectCredit

	order := OrderRequest{
		OrderType:   OrderTypeLimit,
		TimeInForce: timeInForce,
		Price:       &price,
		PriceEffect: &priceEffect,
		Legs: []OrderLeg{
			{
				InstrumentType: InstrumentTypeEquityOption,
				Symbol:         soldOptionSymbol,
				Quantity:       &qty,
				Action:         OrderDirectionSellToOpen,
			},
			{
				InstrumentType: InstrumentTypeEquityOption,
				Symbol:         boughtOptionSymbol,
				Quantity:       &qty,
				Action:         OrderDirectionBuyToOpen,
			},
		},
	}

	return c.PlaceOrder(ctx, accountNumber, order)
}
