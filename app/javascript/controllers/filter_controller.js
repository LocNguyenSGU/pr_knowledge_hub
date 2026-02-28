import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="filter"
export default class extends Controller {
  static values = {
    autoSubmit: { type: Boolean, default: true },
  };

  change() {
    if (this.autoSubmitValue) {
      // Small delay to allow multiple selections
      clearTimeout(this.timeout);
      this.timeout = setTimeout(() => {
        this.element.requestSubmit();
      }, 100);
    }
  }

  submit(event) {
    // Add loading indicator
    const submitButton = this.element.querySelector('[type="submit"]');
    if (submitButton) {
      submitButton.disabled = true;
      submitButton.classList.add("opacity-50", "cursor-not-allowed");

      // Re-enable after navigation
      setTimeout(() => {
        submitButton.disabled = false;
        submitButton.classList.remove("opacity-50", "cursor-not-allowed");
      }, 2000);
    }
  }

  reset() {
    this.element.reset();
    if (this.autoSubmitValue) {
      this.element.requestSubmit();
    }
  }
}
