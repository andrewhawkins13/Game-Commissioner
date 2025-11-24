require "rails_helper"

RSpec.describe Ollama::ClientService do
  let(:model) { "llama3.2" }
  let(:service) { described_class.new(model: model) }

  describe "#initialize" do
    it "initializes with default model from ENV" do
      expect { described_class.new }.not_to raise_error
    end

    it "initializes with custom model" do
      custom_service = described_class.new(model: "custom-model")
      expect(custom_service.instance_variable_get(:@model)).to eq("custom-model")
    end
  end

  describe "#generate" do
    let(:prompt) { "Test prompt" }
    let(:mock_response) do
      {
        "response" => '{"score": 85, "reasoning": "Good match"}',
        "prompt_eval_count" => 100,
        "eval_count" => 50
      }
    end

    before do
      # Stub the Faraday connection
      stub_request(:post, "#{Ollama::ClientService::OLLAMA_URL}/api/generate")
        .with(body: hash_including(model: model, prompt: prompt))
        .to_return(
          status: 200,
          body: mock_response.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    it "sends a request to Ollama API" do
      result = service.generate(prompt)

      expect(result["response"]).to eq('{"score": 85, "reasoning": "Good match"}')
      expect(result["prompt_eval_count"]).to eq(100)
      expect(result["eval_count"]).to eq(50)
    end

    it "sends with custom num_predict" do
      service.generate(prompt, num_predict: 1000)

      expect(WebMock).to have_requested(:post, "#{Ollama::ClientService::OLLAMA_URL}/api/generate")
        .with { |req| JSON.parse(req.body).dig("options", "num_predict") == 1000 }
    end

    it "sends with custom format" do
      service.generate(prompt, format: "text")

      expect(WebMock).to have_requested(:post, "#{Ollama::ClientService::OLLAMA_URL}/api/generate")
        .with { |req| JSON.parse(req.body)["format"] == "text" }
    end

    it "sends with schema when provided" do
      schema = { type: "object", properties: { score: { type: "integer" } } }
      service.generate(prompt, schema: schema)

      expect(WebMock).to have_requested(:post, "#{Ollama::ClientService::OLLAMA_URL}/api/generate")
        .with { |req| JSON.parse(req.body)["format"].is_a?(Hash) }
    end

    context "when API returns error" do
      before do
        stub_request(:post, "#{Ollama::ClientService::OLLAMA_URL}/api/generate")
          .to_return(status: 500, body: "Internal Server Error")
      end

      it "raises an error" do
        expect { service.generate(prompt) }.to raise_error(/Ollama API error: 500/)
      end
    end

    context "when network error occurs" do
      before do
        stub_request(:post, "#{Ollama::ClientService::OLLAMA_URL}/api/generate")
          .to_raise(Faraday::ConnectionFailed)
      end

      it "raises the connection error" do
        expect { service.generate(prompt) }.to raise_error(Faraday::ConnectionFailed)
      end
    end
  end

  describe ".available?" do
    context "when Ollama is available" do
      before do
        stub_request(:get, "#{Ollama::ClientService::OLLAMA_URL}/api/tags")
          .to_return(status: 200, body: { models: [] }.to_json)
      end

      it "returns true" do
        expect(described_class.available?).to be true
      end
    end

    context "when Ollama is not available" do
      before do
        stub_request(:get, "#{Ollama::ClientService::OLLAMA_URL}/api/tags")
          .to_raise(Faraday::ConnectionFailed)
      end

      it "returns false" do
        expect(described_class.available?).to be false
      end
    end
  end

  describe ".available_models" do
    context "when models are available" do
      before do
        stub_request(:get, "#{Ollama::ClientService::OLLAMA_URL}/api/tags")
          .to_return(
            status: 200,
            body: {
              models: [
                { "name" => "llama3.2" },
                { "name" => "mistral" },
                { "name" => "codellama" }
              ]
            }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns sorted list of model names" do
        models = described_class.available_models
        expect(models).to eq(["codellama", "llama3.2", "mistral"])
      end
    end

    context "when API returns empty models list" do
      before do
        stub_request(:get, "#{Ollama::ClientService::OLLAMA_URL}/api/tags")
          .to_return(
            status: 200,
            body: { models: [] }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns default model" do
        models = described_class.available_models
        expect(models).to eq([Ollama::ClientService::DEFAULT_MODEL])
      end
    end

    context "when API is unavailable" do
      before do
        stub_request(:get, "#{Ollama::ClientService::OLLAMA_URL}/api/tags")
          .to_raise(Faraday::ConnectionFailed)
      end

      it "returns default model" do
        models = described_class.available_models
        expect(models).to eq([Ollama::ClientService::DEFAULT_MODEL])
      end
    end

    context "when API returns error" do
      before do
        stub_request(:get, "#{Ollama::ClientService::OLLAMA_URL}/api/tags")
          .to_return(status: 500)
      end

      it "returns default model" do
        models = described_class.available_models
        expect(models).to eq([Ollama::ClientService::DEFAULT_MODEL])
      end
    end
  end
end
