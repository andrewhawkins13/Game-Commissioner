class OfficialsController < ApplicationController
  before_action :set_official, only: [:show, :edit, :update, :destroy]

  def index
    @officials = Official.includes(:assignments, :games, :rules, :official_roles).all
  end

  def show
    @rules = @official.rules
    @official_roles = @official.official_roles
  end

  def new
    @official = Official.new
  end

  def create
    @official = Official.new(official_params)

    if @official.save
      respond_to do |format|
        format.html { redirect_to officials_path, notice: "Official created successfully." }
        format.turbo_stream
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @official.update(official_params)
      # Handle roles
      if params[:roles].present?
        @official.official_roles.destroy_all
        params[:roles].each do |role|
          @official.official_roles.create(role: role) unless role.blank?
        end
      end

      # Handle rules
      if params[:rules].present?
        params[:rules].each do |rule_params|
          if rule_params[:id].present?
            rule = @official.rules.find(rule_params[:id])
            rule.update(rule_text: rule_params[:rule_text], active: rule_params[:active].present?)
          elsif rule_params[:rule_text].present?
            @official.rules.create(rule_text: rule_params[:rule_text], active: rule_params[:active].present?)
          end
        end
      end

      respond_to do |format|
        format.html { redirect_to officials_path, notice: "Official updated successfully." }
        format.turbo_stream
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @official.destroy
    respond_to do |format|
      format.html { redirect_to officials_path, notice: "Official deleted successfully." }
      format.turbo_stream
    end
  end

  private

  def set_official
    @official = Official.find(params[:id])
  end

  def official_params
    params.require(:official).permit(:name, :email, :phone, :max_distance, :home_address, :latitude, :longitude)
  end
end
