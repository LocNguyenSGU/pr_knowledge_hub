import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="search"
export default class extends Controller {
  static targets = ["input", "results"];
  static values = {
    url: String,
    delay: { type: Number, default: 300 },
  };

  connect() {
    this.timeout = null;
  }

  disconnect() {
    if (this.timeout) {
      clearTimeout(this.timeout);
    }
  }

  search() {
    clearTimeout(this.timeout);

    this.timeout = setTimeout(() => {
      const query = this.inputTarget.value.trim();

      if (query.length === 0) {
        return;
      }

      // Submit the form using Turbo
      this.element.requestSubmit();
    }, this.delayValue);
  }

  clear() {
    this.inputTarget.value = "";
    if (this.hasResultsTarget) {
      this.resultsTarget.innerHTML = "";
    }
  }
}
