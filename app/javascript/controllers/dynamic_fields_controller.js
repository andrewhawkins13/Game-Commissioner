import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="dynamic-fields"
export default class extends Controller {
  static targets = ["container", "template"]

  add(event) {
    event.preventDefault()

    // Clone the template content
    const content = this.templateTarget.innerHTML

    // Create a temporary container to parse the HTML
    const temp = document.createElement('div')
    temp.innerHTML = content

    // Append the new field to the container
    this.containerTarget.appendChild(temp.firstElementChild)
  }

  remove(event) {
    event.preventDefault()

    // Find the closest field wrapper and remove it
    const field = event.target.closest('[data-dynamic-fields-target="field"]')
    if (field) {
      field.remove()
    }
  }
}
