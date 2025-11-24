import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="assignment-persistence"
export default class extends Controller {
  static targets = ["model"]

  connect() {
    // Restore saved values from localStorage
    this.restoreModel()
  }

  saveModel() {
    const modelValue = this.modelTarget.value
    localStorage.setItem("assignment_model", modelValue)
  }

  restoreModel() {
    const savedModel = localStorage.getItem("assignment_model")
    if (savedModel && this.modelTarget) {
      // Check if the saved model exists in the options
      const option = Array.from(this.modelTarget.options).find(opt => opt.value === savedModel)
      if (option) {
        this.modelTarget.value = savedModel
      }
    }
  }
}
