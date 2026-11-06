// Appearance page: the small terminal preview follows the form as the owner types.
const preview = document.querySelector("[data-preview]")

if (preview) {
  const form = preview.closest("[data-appearance]")

  const readableOn = (hex) => {
    const [r, g, b] = [1, 3, 5].map((start) => parseInt(hex.slice(start, start + 2), 16) / 255)
      .map((value) => (value <= 0.03928 ? value / 12.92 : ((value + 0.055) / 1.055) ** 2.4))
    return 0.2126 * r + 0.7152 * g + 0.0722 * b > 0.4 ? "#12302d" : "#ffffff"
  }

  const update = () => {
    form.querySelectorAll("[data-preview-color]").forEach((input) => {
      preview.style.setProperty(`--${input.dataset.previewColor}`, input.value)
      preview.style.setProperty(`--on-${input.dataset.previewColor}`, readableOn(input.value))
    })
    form.querySelectorAll("[data-preview-text]").forEach((input) => {
      const target = preview.querySelector(`[data-preview-slot="${input.dataset.previewText}"]`)
      target.textContent = input.value || input.placeholder
    })
    const amounts = form.querySelector("[data-preview-amounts]")
    const list = preview.querySelector("[data-preview-slot='amounts']")
    const symbol = list.dataset.symbol
    list.replaceChildren(...amounts.value.split(/[,;\s]+/).filter(Boolean).slice(0, 6).map((amount) => {
      const item = document.createElement("span")
      item.textContent = `${symbol}${amount}`
      return item
    }))
  }

  form.addEventListener("input", update)
  update()
}
