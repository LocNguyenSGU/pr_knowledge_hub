import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="sync"
export default class extends Controller {
  static targets = ["button", "status", "spinner", "buttonText"];

  async trigger(event) {
    event.preventDefault();

    const url = this.buttonTarget.dataset.url;
    const method = this.buttonTarget.dataset.method || "POST";

    // Show loading state
    this.showLoading();

    try {
      const response = await fetch(url, {
        method: method,
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken(),
        },
      });

      const data = await response.json();

      // Handle different response statuses
      if (response.status === 422) {
        // Empty state or validation error
        this.showError(data.message || "Cannot process request");
        this.hideLoading();
        return;
      }

      if (!response.ok) {
        throw new Error(data.message || "Request failed");
      }

      // Show success message with job info
      let message = data.message || "Job queued successfully";
      if (data.comments_count) {
        message += ` (${data.comments_count} comments to analyze)`;
      }
      this.showSuccess(message);

      // Start polling for job status if available
      if (data.status === "queued") {
        this.pollJobStatus();
      } else {
        // Fallback: refresh after delay
        setTimeout(() => {
          window.location.reload();
        }, 2000);
      }
    } catch (error) {
      this.showError("Failed to trigger sync. Please try again.");
      console.error("Sync error:", error);
      this.hideLoading();
    }
  }

  async pollJobStatus() {
    try {
      const response = await fetch("/sync/status");
      const data = await response.json();
      
      const queueSize = data.sidekiq?.stats?.enqueued || 0;
      
      if (queueSize > 0) {
        this.updateStatus(`Processing: ${queueSize} job(s) in queue...`);
        setTimeout(() => this.pollJobStatus(), 3000);
      } else {
        this.showSuccess("Complete! Reloading...");
        setTimeout(() => {
          window.location.reload();
        }, 1000);
      }
    } catch (error) {
      console.error("Polling error:", error);
      // Fallback to reload after timeout
      setTimeout(() => {
        window.location.reload();
      }, 3000);
    }
  }

  updateStatus(message) {
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = message;
      this.statusTarget.className = "text-sm text-blue-600 mt-2";
    }
  }

  showLoading() {
    if (this.hasButtonTarget) {
      this.buttonTarget.disabled = true;
      this.buttonTarget.classList.add("opacity-50", "cursor-not-allowed");
    }

    if (this.hasSpinnerTarget) {
      this.spinnerTarget.classList.remove("hidden");
    }

    if (this.hasStatusTarget) {
      this.statusTarget.textContent = "Syncing...";
      this.statusTarget.className = "text-sm text-blue-600 mt-2";
    }
  }

  hideLoading() {
    if (this.hasButtonTarget) {
      this.buttonTarget.disabled = false;
      this.buttonTarget.classList.remove("opacity-50", "cursor-not-allowed");
    }

    if (this.hasSpinnerTarget) {
      this.spinnerTarget.classList.add("hidden");
    }
  }

  showSuccess(message) {
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = message;
      this.statusTarget.className = "text-sm text-green-600 mt-2";
    }
  }

  showError(message) {
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = message;
      this.statusTarget.className = "text-sm text-red-600 mt-2";
    }
  }

  csrfToken() {
    const meta = document.querySelector('meta[name="csrf-token"]');
    return meta ? meta.content : "";
  }
}
