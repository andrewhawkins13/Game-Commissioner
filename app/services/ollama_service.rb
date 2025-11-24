require "faraday"
require "json"

class OllamaService
  # Delegate constants to new service classes
  OLLAMA_URL = Ollama::ClientService::OLLAMA_URL
  DEFAULT_MODEL = Ollama::ClientService::DEFAULT_MODEL
  EVALUATION_SCHEMA = Ollama::SchemaDefinitions::EVALUATION_SCHEMA
  ASSIGNMENT_SCHEMA = Ollama::SchemaDefinitions::ASSIGNMENT_SCHEMA

  def initialize(model: DEFAULT_MODEL)
    @model = model
    @client = Ollama::ClientService.new(model: @model)
    @parser = Ollama::ResponseParserService.new(model: @model)
  end

  # Check if Ollama is available and running
  def self.available?
    Ollama::ClientService.available?
  end

  # Get list of available models from Ollama
  # Returns array of model names, or empty array if unavailable
  def self.available_models
    Ollama::ClientService.available_models
  end

end
