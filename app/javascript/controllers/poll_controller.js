import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Connects to data-controller="poll"
export default class extends Controller {
  static values = {
    interval: { type: Number, default: 5000 }, // 5 seconds
    selector: String, // CSS selector to check if polling should continue
    url: String // URL to fetch for Turbo Stream updates
  }

  connect() {
    this.startPolling()
  }

  disconnect() {
    this.stopPolling()
  }

  startPolling() {
    this.poll()
  }

  stopPolling() {
    if (this.pollTimer) {
      clearInterval(this.pollTimer)
      this.pollTimer = null
    }
  }

  poll() {
    this.pollTimer = setInterval(() => {
      // Only refresh if the selector matches (e.g., if there's a processing status)
      if (this.selectorValue && document.querySelector(this.selectorValue)) {
        this.refresh()
      } else if (!this.selectorValue) {
        // If no selector is specified, always refresh
        this.refresh()
      } else {
        // Stop polling if condition is not met
        this.stopPolling()
      }
    }, this.intervalValue)
  }

  async refresh() {
    // Fetch Turbo Stream updates without full page reload
    if (this.urlValue) {
      try {
        const response = await fetch(this.urlValue, {
          headers: {
            'Accept': 'text/vnd.turbo-stream.html'
          }
        })

        if (response.ok) {
          const html = await response.text()
          // Turbo automatically processes the stream response
          if (Turbo.renderStreamMessage) {
            await Turbo.renderStreamMessage(html)
          } else {
            // Fallback for older Turbo versions or if method is missing
            document.body.insertAdjacentHTML('beforeend', html)
          }
        }
      } catch (error) {
        console.error('Polling refresh failed:', error)
      }
    } else {
      // Fallback to old behavior if no URL is specified
      Turbo.visit(window.location.href, { action: 'replace' })
    }
  }
}
