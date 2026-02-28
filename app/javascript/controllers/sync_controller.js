import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="sync"
export default class extends Controller {
  static targets = ["button", "status", "spinner"];

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

      // Show success message
      this.showSuccess(data.message || "Sync job queued successfully");

      // Refresh after a delay
      setTimeout(() => {
        window.location.reload();
      }, 2000);
    } catch (error) {
      this.showError("Failed to trigger sync. Please try again.");
      console.error("Sync error:", error);
    } finally {
      this.hideLoading();
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
