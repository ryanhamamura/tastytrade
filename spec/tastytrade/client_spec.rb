# frozen_string_literal: true

require "spec_helper"

RSpec.describe Tastytrade::Client do
  let(:base_url) { "https://api.example.com" }
  let(:client) { described_class.new(base_url: base_url) }

  describe "#initialize" do
    it "sets the base URL" do
      expect(client.base_url).to eq(base_url)
    end
  end

  describe "HTTP methods" do
    let(:path) { "/test" }
    let(:response_body) { '{"key": "value"}' }
    let(:parsed_response) { { "key" => "value" } }

    describe "#get" do
      it "makes a GET request and returns parsed JSON" do
        stub_request(:get, "#{base_url}#{path}")
          .to_return(status: 200, body: response_body, headers: { "Content-Type" => "application/json" })

        result = client.get(path)
        expect(result).to eq(parsed_response)
      end

      it "includes query parameters" do
        params = { foo: "bar" }
        stub_request(:get, "#{base_url}#{path}")
          .with(query: params)
          .to_return(status: 200, body: response_body)

        client.get(path, params)
      end
    end

    describe "#post" do
      it "makes a POST request with JSON body" do
        body = { data: "test" }
        stub_request(:post, "#{base_url}#{path}")
          .with(body: body.to_json,
                headers: { "Content-Type" => "application/json" })
          .to_return(status: 201, body: response_body)

        result = client.post(path, body)
        expect(result).to eq(parsed_response)
      end
    end

    describe "#put" do
      it "makes a PUT request with JSON body" do
        body = { data: "updated" }
        stub_request(:put, "#{base_url}#{path}")
          .with(body: body.to_json,
                headers: { "Content-Type" => "application/json" })
          .to_return(status: 200, body: response_body)

        result = client.put(path, body)
        expect(result).to eq(parsed_response)
      end
    end

    describe "#delete" do
      it "makes a DELETE request" do
        stub_request(:delete, "#{base_url}#{path}")
          .to_return(status: 204, body: "")

        result = client.delete(path)
        expect(result).to be_nil
      end
    end
  end

  describe "error handling" do
    let(:path) { "/test" }

    it "raises error for 401 response" do
      stub_request(:get, "#{base_url}#{path}")
        .to_return(status: 401, body: '{"error": "Unauthorized"}')

      expect { client.get(path) }.to raise_error(Tastytrade::Error, /Authentication failed/)
    end

    it "raises error for 404 response" do
      stub_request(:get, "#{base_url}#{path}")
        .to_return(status: 404, body: '{"error": "Not found"}')

      expect { client.get(path) }.to raise_error(Tastytrade::Error, /Resource not found/)
    end

    it "raises error for 500 response" do
      stub_request(:get, "#{base_url}#{path}")
        .to_return(status: 500, body: '{"error": "Internal server error"}')

      expect { client.get(path) }.to raise_error(Tastytrade::Error, /Server error/)
    end

    it "handles invalid JSON response" do
      stub_request(:get, "#{base_url}#{path}")
        .to_return(status: 200, body: "invalid json")

      expect { client.get(path) }.to raise_error(Tastytrade::Error, /Invalid JSON response/)
    end

    it "handles empty response body" do
      stub_request(:get, "#{base_url}#{path}")
        .to_return(status: 200, body: "")

      result = client.get(path)
      expect(result).to be_nil
    end

    context "with different error message formats" do
      it "handles 'error' field" do
        stub_request(:get, "#{base_url}#{path}")
          .to_return(status: 400, body: '{"error": "Bad request"}')

        expect { client.get(path) }.to raise_error(Tastytrade::Error, /Bad request/)
      end

      it "handles 'message' field" do
        stub_request(:get, "#{base_url}#{path}")
          .to_return(status: 400, body: '{"message": "Invalid input"}')

        expect { client.get(path) }.to raise_error(Tastytrade::Error, /Invalid input/)
      end

      it "handles 'reason' field" do
        stub_request(:get, "#{base_url}#{path}")
          .to_return(status: 400, body: '{"reason": "Missing parameter"}')

        expect { client.get(path) }.to raise_error(Tastytrade::Error, /Missing parameter/)
      end
    end
  end

  describe "retry behavior" do
    let(:path) { "/test" }

    it "retries on 503 errors" do
      stub_request(:get, "#{base_url}#{path}")
        .to_return(status: 503, body: "")
        .then.to_return(status: 200, body: '{"success": true}')

      result = client.get(path)
      expect(result).to eq({ "success" => true })
    end

    it "does not retry on POST requests" do
      # POST is not in the retry methods list by default
      stub_request(:post, "#{base_url}#{path}")
        .to_return(status: 503, body: "")
        .times(1)

      expect { client.post(path) }.to raise_error(Tastytrade::Error, /Server error/)
    end
  end
end
