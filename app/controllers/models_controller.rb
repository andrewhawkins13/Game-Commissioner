class ModelsController < ApplicationController
  before_action :check_ollama_available, only: [:index]

  def index
    @ollama_available = OllamaService.available?
    @models = fetch_models_with_stats
    @leaderboard = ModelStatsService.leaderboard if @models.any?
  end

  private

  def check_ollama_available
    unless OllamaService.available?
      flash.now[:alert] = "Ollama is not running. Please start Ollama to view models."
    end
  end

  def fetch_models_with_stats
    available_models = OllamaService.available_models

    available_models.map do |model_name|
      {
        name: model_name,
        stats: ModelStatsService.stats_for_model(model_name),
        metadata: fetch_metadata_safe(model_name),
        used: ModelStatsService.model_used?(model_name)
      }
    end
  end

  def fetch_metadata_safe(model_name)
    Ollama::ClientService.show_model(model_name)
  rescue => e
    Rails.logger.error "Failed to fetch metadata for #{model_name}: #{e.message}"
    nil
  end
end
