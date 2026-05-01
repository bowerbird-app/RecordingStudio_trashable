import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "frame", "skeleton"]

  static values = {
    delay: { type: Number, default: 250 }
  }

  connect() {
    this.submitTimer = null
    this.hideLoading()
  }

  disconnect() {
    this.clearPendingSubmit()
  }

  queueSubmit(event) {
    this.clearPendingSubmit()
    this.showLoading()

    if (this.queryBlank(event)) {
      this.submit()
      return
    }

    this.submitTimer = setTimeout(() => this.submit(), this.delayValue)
  }

  submit() {
    this.clearPendingSubmit()
    this.showLoading()
    this.formTarget.requestSubmit()
  }

  showLoading() {
    if (this.hasSkeletonTarget) {
      this.skeletonTarget.classList.remove("hidden")
    }

    if (this.hasFrameTarget) {
      this.frameTarget.style.visibility = "hidden"
    }
  }

  hideLoading() {
    if (this.hasSkeletonTarget) {
      this.skeletonTarget.classList.add("hidden")
    }

    if (this.hasFrameTarget) {
      this.frameTarget.style.visibility = ""
    }
  }

  clearPendingSubmit() {
    if (!this.submitTimer) return

    clearTimeout(this.submitTimer)
    this.submitTimer = null
  }

  queryBlank(event) {
    return event?.target?.name === "q" && event.target.value.trim() === ""
  }
}