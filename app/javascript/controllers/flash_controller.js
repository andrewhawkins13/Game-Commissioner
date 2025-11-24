import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    autoDismiss: { type: Number, default: 5000 }
  }

  connect() {
    this.setupAutoDismiss()
    this.setupTurboListener()
  }

  disconnect() {
    this.clearTimer()
  }

  setupAutoDismiss() {
    if (this.autoDismissValue > 0) {
      this.timer = setTimeout(() => {
        this.close()
      }, this.autoDismissValue)
    }
  }

  setupTurboListener() {
    document.addEventListener('turbo:before-render', this.handleTurboRender)
  }

  handleTurboRender = (event) => {
    const newBody = event.detail.newBody
    const hasNewFlash = newBody.querySelector('[data-controller="flash"]')

    if (hasNewFlash) {
      this.close()
    }
  }

  close() {
    this.clearTimer()

    this.element.style.transition = 'opacity 0.3s ease-out, transform 0.3s ease-out'
    this.element.style.opacity = '0'
    this.element.style.transform = 'translateY(-10px)'

    setTimeout(() => {
      this.element.remove()
    }, 300)
  }

  clearTimer() {
    if (this.timer) {
      clearTimeout(this.timer)
      this.timer = null
    }
  }
}
