module ApplicationHelper
  # Get available Ollama models with caching (5 minutes)
  def available_ollama_models
    Rails.cache.fetch("ollama_models", expires_in: 5.minutes) do
      OllamaService.available_models
    end
  end

  # Get current default model from ENV
  def default_ollama_model
    OllamaService::DEFAULT_MODEL
  end
end
