require "faraday"
require "json"

module Ollama
  class ClientService
    OLLAMA_URL = ENV.fetch("OLLAMA_URL", "http://localhost:11434")
    DEFAULT_MODEL = ENV.fetch("OLLAMA_MODEL", "llama3.2")

    def initialize(model: DEFAULT_MODEL)
      @model = model
      @client = build_client
    end

    # Generate a response from the Ollama API
    # @param prompt [String] The prompt to send
    # @param num_predict [Integer] Maximum tokens to generate
    # @param format [String] Response format (default: "json")
    # @param schema [Hash] JSON schema for structured output (optional)
    # @return [Hash] Response data including 'response', 'prompt_eval_count', 'eval_count'
    def generate(prompt, num_predict: 500, format: "json", schema: nil)
      body = {
        model: @model,
        prompt: prompt,
        stream: false,
        format: format,
        options: {
          temperature: 0.3, # Lower temperature for more consistent scoring
          num_predict: num_predict
        }
      }

      # Add JSON schema if provided and format is json
      # Note: Schema support requires Ollama 0.1.14+ and compatible models
      body[:format] = schema if schema && format == "json"

      response = @client.post("/api/generate") do |req|
        req.body = body
      end

      if response.success?
        response.body
      else
        raise "Ollama API error: #{response.status} - #{response.body}"
      end
    end

    # Check if Ollama is available and running
    # @return [Boolean]
    def self.available?
      conn = Faraday.new(url: OLLAMA_URL)
      response = conn.get("/api/tags")
      response.success?
    rescue
      false
    end

    # Get list of available models from Ollama
    # @return [Array<String>] Array of model names, or [DEFAULT_MODEL] if unavailable
    def self.available_models
      conn = Faraday.new(url: OLLAMA_URL) do |faraday|
        faraday.response :json
        faraday.adapter Faraday.default_adapter
        faraday.options.timeout = 10      # Short timeout for listing models
        faraday.options.open_timeout = 5
      end

      response = conn.get("/api/tags")

      if response.success? && response.body["models"]
        # Extract model names from response
        models = response.body["models"].map { |m| m["name"] }.compact.sort
        models.presence || [DEFAULT_MODEL]
      else
        [DEFAULT_MODEL]
      end
    rescue => e
      Rails.logger.error "Failed to fetch Ollama models: #{e.message}"
      [DEFAULT_MODEL]
    end

    # Get detailed information about a specific model
    # @param name [String] Model name
    # @return [Hash] Model metadata including size, format, family, parameters, etc.
    def self.show_model(name)
      conn = Faraday.new(url: OLLAMA_URL) do |faraday|
        faraday.request :json
        faraday.response :json
        faraday.adapter Faraday.default_adapter
        faraday.options.timeout = 10
        faraday.options.open_timeout = 5
      end

      response = conn.post("/api/show") do |req|
        req.body = { name: name }
      end

      if response.success?
        response.body
      else
        Rails.logger.error "Failed to fetch model info for #{name}: #{response.status}"
        nil
      end
    rescue => e
      Rails.logger.error "Failed to fetch model info for #{name}: #{e.message}"
      nil
    end

    private

    def build_client
      Faraday.new(url: OLLAMA_URL) do |faraday|
        faraday.request :json
        faraday.response :json
        faraday.adapter Faraday.default_adapter
        # Increased timeouts for larger models that take longer to respond
        faraday.options.timeout = 300      # 5 minutes read timeout
        faraday.options.open_timeout = 10  # 10 seconds to establish connection
      end
    end
  end
end
