package tastytrade

import (
	"time"
)

// Warning represents a warning returned by the API
type Warning struct {
	Code    string `json:"code"`
	Message string `json:"message"`
}

// OrderLeg represents a single leg of an order
type OrderLeg struct {
	InstrumentType    string      `json:"instrument-type"`
	Symbol            string      `json:"symbol"`
	Quantity          int         `json:"quantity"`
	RemainingQuantity int         `json:"remaining-quantity,omitempty"`
	Action            string      `json:"action"`
	Fills             []OrderFill `json:"fills,omitempty"`
}

// OrderFill represents a fill for an order leg
type OrderFill struct {
	ExecID         string    `json:"exec-id,omitempty"`
	ExtGroupFillID string    `json:"ext-group-fill-id,omitempty"`
	ExtExecID      string    `json:"ext-exec-id,omitempty"`
	FillCost       string    `json:"fill-cost,omitempty"`
	FillCostEffect string    `json:"fill-cost-effect,omitempty"`
	FillPrice      string    `json:"fill-price,omitempty"`
	FillQuantity   int       `json:"fill-quantity,omitempty"`
	FilledAt       time.Time `json:"filled-at,omitempty"`
	LegID          int       `json:"leg-id,omitempty"`
	OrderLegID     int       `json:"order-leg-id,omitempty"`
}

// Order represents an order in the TastyTrade system
type Order struct {
	ID                       int64      `json:"id,omitempty"`
	AccountNumber            string     `json:"account-number"`
	TimeInForce              string     `json:"time-in-force"`
	OrderType                string     `json:"order-type"`
	Size                     int        `json:"size,omitempty"`
	UnderlyingSymbol         string     `json:"underlying-symbol,omitempty"`
	UnderlyingInstrumentType string     `json:"underlying-instrument-type,omitempty"`
	Price                    string     `json:"price,omitempty"`
	PriceEffect              string     `json:"price-effect,omitempty"`
	StopTrigger              string     `json:"stop-trigger,omitempty"`
	Status                   string     `json:"status,omitempty"`
	ContingentStatus         string     `json:"contingent-status,omitempty"`
	Cancellable              bool       `json:"cancellable"`
	Editable                 bool       `json:"editable"`
	Edited                   bool       `json:"edited"`
	ExtExchangeOrderNumber   string     `json:"ext-exchange-order-number,omitempty"`
	ExtClientOrderID         string     `json:"ext-client-order-id,omitempty"`
	ExtGlobalOrderNumber     int64      `json:"ext-global-order-number,omitempty"`
	ReceivedAt               time.Time  `json:"received-at,omitempty"`
	UpdatedAt                int64      `json:"updated-at,omitempty"`
	ComplexOrderID           int64      `json:"complex-order-id,omitempty"`
	ComplexOrderTag          string     `json:"complex-order-tag,omitempty"`
	GlobalRequestID          string     `json:"global-request-id,omitempty"`
	PreflightID              int        `json:"preflight-id,omitempty"`
	Legs                     []OrderLeg `json:"legs"`
}

// BuyingPowerEffect represents the buying power impact of an order
type BuyingPowerEffect struct {
	ChangeInMarginRequirement            string `json:"change-in-margin-requirement"`
	ChangeInMarginRequirementEffect      string `json:"change-in-margin-requirement-effect"`
	ChangeInBuyingPower                  string `json:"change-in-buying-power"`
	ChangeInBuyingPowerEffect            string `json:"change-in-buying-power-effect"`
	CurrentBuyingPower                   string `json:"current-buying-power"`
	CurrentBuyingPowerEffect             string `json:"current-buying-power-effect"`
	NewBuyingPower                       string `json:"new-buying-power"`
	NewBuyingPowerEffect                 string `json:"new-buying-power-effect"`
	IsolatedOrderMarginRequirement       string `json:"isolated-order-margin-requirement"`
	IsolatedOrderMarginRequirementEffect string `json:"isolated-order-margin-requirement-effect"`
	IsSpread                             bool   `json:"is-spread"`
	Impact                               string `json:"impact"`
	Effect                               string `json:"effect"`
}

// FeeCalculation represents the fee calculation for an order
type FeeCalculation struct {
	RegulatoryFees                   string         `json:"regulatory-fees"`
	RegulatoryFeesEffect             string         `json:"regulatory-fees-effect"`
	RegulatoryFeesBreakdown          []FeeBreakdown `json:"regulatory-fees-breakdown,omitempty"`
	ClearingFees                     string         `json:"clearing-fees"`
	ClearingFeesEffect               string         `json:"clearing-fees-effect"`
	ClearingFeesBreakdown            []FeeBreakdown `json:"clearing-fees-breakdown,omitempty"`
	Commission                       string         `json:"commission"`
	CommissionEffect                 string         `json:"commission-effect"`
	CommissionBreakdown              []FeeBreakdown `json:"commission-breakdown,omitempty"`
	ProprietaryIndexOptionFees       string         `json:"proprietary-index-option-fees"`
	ProprietaryIndexOptionFeesEffect string         `json:"proprietary-index-option-fees-effect"`
	ProprietaryFeesBreakdown         []FeeBreakdown `json:"proprietary-fees-breakdown,omitempty"`
	TotalFees                        string         `json:"total-fees"`
	TotalFeesEffect                  string         `json:"total-fees-effect"`
	Rebates                          string         `json:"rebates,omitempty"`
	RebatesEffect                    string         `json:"rebates-effect,omitempty"`
	RebatesBreakdown                 []FeeBreakdown `json:"rebates-breakdown,omitempty"`
	PerQuantity                      bool           `json:"per-quantity,omitempty"`
}

// FeeBreakdown represents individual fee component breakdown
type FeeBreakdown struct {
	Name   string `json:"name"`
	Value  string `json:"value"`
	Effect string `json:"effect"`
}

// OrderResponse represents a response for a single order
type OrderResponse struct {
	Data struct {
		Order             Order             `json:"order"`
		Warnings          []Warning         `json:"warnings,omitempty"`
		BuyingPowerEffect BuyingPowerEffect `json:"buying-power-effect,omitempty"`
		FeeCalculation    FeeCalculation    `json:"fee-calculation,omitempty"`
	} `json:"data"`
	APIVersion string `json:"api-version,omitempty"`
	Context    string `json:"context,omitempty"`
}

// OrdersResponse represents a response for multiple orders
type OrdersResponse struct {
	Data struct {
		Items []Order `json:"items"`
	} `json:"data"`
	APIVersion string `json:"api-version,omitempty"`
	Context    string `json:"context,omitempty"`
}

// DryRunOrderResponse represents a response for an order dry run
type DryRunOrderResponse struct {
	Data struct {
		Order             Order             `json:"order"`
		Warnings          []Warning         `json:"warnings,omitempty"`
		BuyingPowerEffect BuyingPowerEffect `json:"buying-power-effect,omitempty"`
		FeeCalculation    FeeCalculation    `json:"fee-calculation,omitempty"`
	} `json:"data"`
	APIVersion string `json:"api-version,omitempty"`
	Context    string `json:"context,omitempty"`
}

// OrderSubmitRequest represents the request to submit an order
type OrderSubmitRequest struct {
	TimeInForce      string     `json:"time-in-force"`
	OrderType        string     `json:"order-type"`
	Price            string     `json:"price,omitempty"`
	PriceEffect      string     `json:"price-effect,omitempty"`
	StopTrigger      string     `json:"stop-trigger,omitempty"`
	Legs             []OrderLeg `json:"legs"`
	UnderlyingSymbol string     `json:"underlying-symbol,omitempty"`
}

// ComplexOrderType represents the type of complex order
type ComplexOrderType string

const (
	ComplexOrderTypeOCO   ComplexOrderType = "OCO"
	ComplexOrderTypeOTO   ComplexOrderType = "OTO"
	ComplexOrderTypeOTOCO ComplexOrderType = "OTOCO"
)

// ComplexOrder represents a complex order (OTOCO, OCO, OTO)
type ComplexOrder struct {
	ID            int64            `json:"id,omitempty"`
	AccountNumber string           `json:"account-number,omitempty"`
	Type          ComplexOrderType `json:"type"`
	TriggerOrder  *Order           `json:"trigger-order,omitempty"` // Only for OTOCO and OTO
	Orders        []Order          `json:"orders"`
}

// ComplexOrderResponse represents a response for a complex order
type ComplexOrderResponse struct {
	Data struct {
		ComplexOrder      ComplexOrder      `json:"complex-order"`
		Warnings          []Warning         `json:"warnings,omitempty"`
		BuyingPowerEffect BuyingPowerEffect `json:"buying-power-effect,omitempty"`
		FeeCalculation    FeeCalculation    `json:"fee-calculation,omitempty"`
	} `json:"data"`
	Context string `json:"context,omitempty"`
}

// ComplexOrderRequest represents a request to submit a complex order
type ComplexOrderRequest struct {
	Type         ComplexOrderType     `json:"type"`
	TriggerOrder *OrderSubmitRequest  `json:"trigger-order,omitempty"` // Only for OTOCO and OTO
	Orders       []OrderSubmitRequest `json:"orders"`
}
