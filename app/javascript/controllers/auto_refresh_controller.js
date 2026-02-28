import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="auto-refresh"
export default class extends Controller {
  static values = {
    interval: { type: Number, default: 30000 }, // 30 seconds default
    url: String,
  };

  connect() {
    this.startRefreshing();
  }

  disconnect() {
    this.stopRefreshing();
  }

  startRefreshing() {
    this.refreshTimer = setInterval(() => {
      this.refresh();
    }, this.intervalValue);
  }

  stopRefreshing() {
    if (this.refreshTimer) {
      clearInterval(this.refreshTimer);
    }
  }

  async refresh() {
    if (!this.hasUrlValue) {
      // If no URL specified, reload the current page
      window.location.reload();
      return;
    }

    try {
      const response = await fetch(this.urlValue, {
        headers: {
          Accept: "text/vnd.turbo-stream.html",
        },
      });

      if (response.ok) {
        const html = await response.text();
        Turbo.renderStreamMessage(html);
      }
    } catch (error) {
      console.error("Auto-refresh error:", error);
    }
  }
}
