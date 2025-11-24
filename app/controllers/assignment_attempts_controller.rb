class AssignmentAttemptsController < ApplicationController
  before_action :set_attempt, only: [:show, :evaluate]

  def index
    @attempts = AssignmentAttempt.includes(:assignment_evaluation, :assignments)
                                  .recent
                                  .limit(100)
  end

  def refresh_list
    @attempts = AssignmentAttempt.includes(:assignment_evaluation, :assignments)
                                  .recent
                                  .limit(100)
    respond_to do |format|
      format.turbo_stream
    end
  end

  def show
    @assignments = @attempt.assignments.includes(:game, :official, :rule_violations).order('games.game_date')
    @attempt.assignment_evaluation # Eager load evaluation if it exists
  end

  def evaluate
    # Run evaluation service
    begin
      evaluation_service = AiAssignment::EvaluationService.new(@attempt)
      evaluation = evaluation_service.evaluate!

      redirect_to @attempt, notice: "Evaluation completed! Score: #{evaluation.overall_score}/100 (Grade: #{evaluation.grade})"
    rescue => e
      Rails.logger.error "Manual evaluation failed: #{e.message}"
      redirect_to @attempt, alert: "Evaluation failed: #{e.message}"
    end
  end

  private

  def set_attempt
    @attempt = AssignmentAttempt.find(params[:id])
  end
end
