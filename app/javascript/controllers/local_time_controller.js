import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="local-time"
export default class extends Controller {
  connect() {
    this.convertToLocalTime()
  }

  convertToLocalTime() {
    // Get the datetime attribute (should be in ISO 8601 format)
    const datetimeAttr = this.element.getAttribute('datetime')

    if (!datetimeAttr) {
      console.warn('local-time controller: no datetime attribute found')
      return
    }

    try {
      // Parse the UTC datetime
      const utcDate = new Date(datetimeAttr)

      if (isNaN(utcDate.getTime())) {
        console.warn('local-time controller: invalid datetime', datetimeAttr)
        return
      }

      // Format the date in user's local timezone
      // This will automatically use the browser's timezone
      const localTimeString = this.formatLocalTime(utcDate)

      // Update the element's text content
      this.element.textContent = localTimeString

    } catch (error) {
      console.error('local-time controller error:', error)
    }
  }

  formatLocalTime(date) {
    // Format: "Friday, November 22, 2025 at 11:35 AM"
    const options = {
      weekday: 'long',
      year: 'numeric',
      month: 'long',
      day: 'numeric',
      hour: 'numeric',
      minute: '2-digit',
      hour12: true
    }

    return new Intl.DateTimeFormat('en-US', options).format(date)
  }
}
