class GamesController < ApplicationController
  before_action :set_game, only: [:show, :edit, :update, :destroy]

  def index
    @games = Game.includes(:assignments, :officials).upcoming
    @officials = Official.all
  end

  def refresh_list
    @games = Game.includes(:assignments, :officials).upcoming
    respond_to do |format|
      format.turbo_stream
    end
  end

  def show
    @available_officials = Official.all
    @open_roles = @game.open_positions
  end

  def new
    @game = Game.new
  end

  def create
    @game = Game.new(game_params)

    if @game.save
      respond_to do |format|
        format.html { redirect_to games_path, notice: "Game created successfully." }
        format.turbo_stream
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @game.update(game_params)
      respond_to do |format|
        format.html { redirect_to games_path, notice: "Game updated successfully." }
        format.turbo_stream
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @game.destroy
    respond_to do |format|
      format.html { redirect_to games_path, notice: "Game deleted successfully." }
      format.turbo_stream
    end
  end

  private

  def set_game
    @game = Game.find(params[:id])
  end

  def game_params
    params.require(:game).permit(:name, :game_date, :location, :address, :latitude, :longitude, :status)
  end
end
