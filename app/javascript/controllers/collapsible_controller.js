import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="collapsible"
export default class extends Controller {
  static targets = ["content", "icon"];
  static values = {
    open: { type: Boolean, default: false },
  };

  connect() {
    this.updateState();
  }

  toggle() {
    this.openValue = !this.openValue;
    this.updateState();
  }

  updateState() {
    if (this.hasContentTarget) {
      if (this.openValue) {
        this.contentTarget.classList.remove("hidden");
        this.contentTarget.classList.add("block");
      } else {
        this.contentTarget.classList.add("hidden");
        this.contentTarget.classList.remove("block");
      }
    }

    if (this.hasIconTarget) {
      if (this.openValue) {
        this.iconTarget.classList.add("rotate-180");
      } else {
        this.iconTarget.classList.remove("rotate-180");
      }
    }
  }
}
