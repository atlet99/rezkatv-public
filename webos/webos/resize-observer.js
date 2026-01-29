// Lightweight ResizeObserver polyfill for legacy WebOS browsers.
// This is intentionally minimal and only prevents runtime errors in layouts
// that rely on ResizeObserver. It does NOT implement full resize detection,
// but it's sufficient for cases where the app only expects the API to exist.

/* eslint-disable no-undef */

if (typeof window !== 'undefined' && typeof window.ResizeObserver === 'undefined') {
  class ResizeObserverPolyfill {
    /**
     * @param {(entries: ResizeObserverEntry[], observer: ResizeObserver) => void} callback
     */
    constructor(callback) {
      // Store callback but do not schedule real observations.
      this._callback = callback
    }

    /**
     * @param {Element | SVGElement} target
     */
    observe(target) {
      // Immediately invoke callback once with a dummy entry so layouts that
      // expect at least one call can proceed.
      try {
        const entry = {
          target,
          contentRect: target.getBoundingClientRect
            ? target.getBoundingClientRect()
            : { x: 0, y: 0, width: 0, height: 0, top: 0, left: 0, right: 0, bottom: 0 },
        }
        this._callback && this._callback([entry], this)
      } catch {
        // Silent fallback – polyfill is best-effort only.
      }
    }

    unobserve() {
      // No-op
    }

    disconnect() {
      // No-op
    }
  }

  // Attach to window to mimic native API.
  window.ResizeObserver = ResizeObserverPolyfill
}

export {}

