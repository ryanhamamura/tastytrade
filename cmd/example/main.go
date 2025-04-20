package main

import (
	"context"
	"fmt"
	"log"

	"github.com/ryanhamamura/tastytrade/pkg/tastytrade"
)

func main() {
	// Load config
	cfg, err := Load(".env")
	if err != nil {
		log.Fatalf("Failed to load config: %v", err)
	}

	// Create client
	client := tastytrade.NewClient(cfg.IsProduction(), tastytrade.WithDebug(true))
	ctx := context.Background()

	// Login
	if err := client.Login(ctx, cfg.Username, cfg.Password); err != nil {
		fmt.Printf("Login failed: %v\n", err)
	}

	fmt.Println("Login successful!")

	account, err := client.GetCustomerAccount(ctx, "me", cfg.AccountNumber)
	if err != nil {
		fmt.Printf("Failed to get account: %v\n", err)
	}

	tastytrade.PrintAccount(account)

	// Build an order
	var orders []tastytrade.Order
	orders, err = client.SearchOrders(ctx, cfg.AccountNumber, nil)
	for _, order := range orders {
		tastytrade.PrintOrder(&order)
	}

}
