class AssignmentsController < ApplicationController
  def create
    @game = Game.find(params[:game_id])
    @assignment = @game.assignments.build(assignment_params)

    if @assignment.save
      respond_to do |format|
        format.html { redirect_to games_path, notice: "Official assigned successfully." }
        format.turbo_stream { render turbo_stream: turbo_stream.replace("game_#{@game.id}", partial: "games/game", locals: { game: @game }) }
      end
    else
      respond_to do |format|
        format.html { redirect_to games_path, alert: @assignment.errors.full_messages.join(", ") }
        format.turbo_stream { render turbo_stream: turbo_stream.replace("game_#{@game.id}_errors", @assignment.errors.full_messages.join(", ")) }
      end
    end
  end

  def destroy
    @assignment = Assignment.find(params[:id])
    @game = @assignment.game

    @assignment.destroy
    respond_to do |format|
      format.html { redirect_to games_path, notice: "Assignment removed successfully." }
      format.turbo_stream { render turbo_stream: turbo_stream.replace("game_#{@game.id}", partial: "games/game", locals: { game: @game }) }
    end
  end

  def assign_open_games
    # Reset all existing assignments first
    count = Assignment.count
    # Use delete_all to avoid callbacks that would reset historical validation stats
    RuleViolation.delete_all
    Assignment.delete_all

    model = params[:model].presence

    # Enqueue job with selected model
    AssignOpenGamesJob.perform_later(model: model)

    model_info = model ? " using #{model}" : ""

    redirect_to games_path, notice: "Removed #{count} existing assignments. AI assignment started#{model_info}. Check Assignment Attempts for results."
  end

  private

  def assignment_params
    params.require(:assignment).permit(:official_id, :role)
  end
end
