module AssignmentAttemptsHelper
  def assignment_attempt_status_badge(attempt)
    case attempt.status
    when "completed"
      content_tag(:span, "Completed", class: "bg-green-100 text-green-800 px-3 py-1 rounded-lg font-medium")
    when "processing"
      content_tag(:span, "Processing", class: "bg-blue-100 text-blue-800 px-3 py-1 rounded-lg font-medium")
    when "failed"
      content_tag(:span, "Failed", class: "bg-red-100 text-red-800 px-3 py-1 rounded-lg font-medium")
    else
      content_tag(:span, "Pending", class: "bg-gray-100 text-gray-800 px-3 py-1 rounded-lg font-medium")
    end
  end

  def assignment_attempt_evaluation_badge(attempt)
    return unless attempt.evaluated?

    content_tag(:span, "⚖️ Evaluated", class: "bg-purple-100 text-purple-800 px-3 py-1 rounded-lg font-medium")
  end
end

