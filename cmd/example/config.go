package main

import (
	"bufio"
	"errors"
	"fmt"
	"os"
	"strings"
)

// Environment represents the application environment
type Environment string

const (
	Sandbox    Environment = "sandbox"
	Production Environment = "production"
)

// Config holds the environment configuration
type Config struct {
	Username      string
	Password      string
	AccountNumber string
	Environment   Environment
}

// LoadEnv loads environment variables from a .env file
func LoadEnv(filepath string) error {
	file, err := os.Open(filepath)
	if err != nil {
		return fmt.Errorf("error opening .env file: %w", err)
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := scanner.Text()

		// Skip empty lines and comments
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}

		parts := strings.SplitN(line, "=", 2)
		if len(parts) != 2 {
			continue // Skip malformed lines
		}

		key := strings.TrimSpace(parts[0])
		value := strings.TrimSpace(parts[1])

		// Remove quotes if present
		value = strings.Trim(value, `"'`)

		// Set environment variable
		os.Setenv(key, value)
	}

	if err := scanner.Err(); err != nil {
		return fmt.Errorf("error reading .env file: %w", err)
	}

	return nil
}

// New creates a new Config with values from the environment
func New() (*Config, error) {
	username := os.Getenv("USERNAME")
	password := os.Getenv("PASSWORD")
	accountNumber := os.Getenv("ACCOUNT_NUMBER")
	envStr := os.Getenv("ENVIRONMENT")

	if username == "" {
		return nil, errors.New("USERNAME environment variable not set")
	}
	if password == "" {
		return nil, errors.New("PASSWORD environment variable not set")
	}
	if accountNumber == "" {
		return nil, errors.New("ACCOUNT_NUMBER environment variable not set")
	}

	// Validate environment
	var env Environment
	switch strings.ToLower(envStr) {
	case string(Sandbox):
		env = Sandbox
	case string(Production):
		env = Production
	case "":
		return nil, errors.New("ENVIRONMENT environment variable not set")
	default:
		return nil, fmt.Errorf("invalid environment: %s (must be 'sandbox' or 'production')", envStr)
	}

	return &Config{
		Username:      username,
		Password:      password,
		AccountNumber: accountNumber,
		Environment:   env,
	}, nil
}

// Load is a convenience function that loads the .env file and returns a Config
func Load(filepath string) (*Config, error) {
	if err := LoadEnv(filepath); err != nil {
		return nil, err
	}

	return New()
}

// IsSandbox returns true if the environment is Sandbox
func (c *Config) IsSandbox() bool {
	return c.Environment == Sandbox
}

// IsProduction returns true if the environment is Production
func (c *Config) IsProduction() bool {
	return c.Environment == Production
}
