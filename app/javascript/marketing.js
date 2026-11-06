// Hero demo on the marketing site: the terminal mock takes on the colours visitors pick.
document.querySelectorAll("[data-color-demo]").forEach((root) => {
  const mock = root.querySelector("[data-color-target]")
  const buttons = root.querySelectorAll("[data-color]")

  buttons.forEach((button) => {
    button.addEventListener("click", () => {
      buttons.forEach((other) => other.setAttribute("aria-pressed", String(other === button)))
      mock.style.setProperty("--mock-primary", button.dataset.color)
      mock.style.setProperty("--mock-background", button.dataset.background)
    })
  })
})

// Signup: suggest the address from the name and check availability while typing.
function slugify(value) {
  return value
    .normalize("NFD").replace(/[̀-ͯ]/g, "")
    .replace(/đ/gi, "dj").replace(/ß/g, "ss").replace(/ı/g, "i")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 40)
    .replace(/-+$/, "")
}

function startSignup(form) {
  const nameInput = form.querySelector("[data-signup-name]")
  const subdomainInput = form.querySelector("[data-signup-subdomain]")
  const status = form.querySelector("[data-signup-status]")
  const defaultHint = status.textContent
  let edited = subdomainInput.value !== ""
  let timer = null
  let request = 0

  const check = () => {
    clearTimeout(timer)
    const value = subdomainInput.value.trim()
    if (value.length < 3) {
      status.textContent = defaultHint
      delete status.dataset.state
      return
    }
    timer = setTimeout(async () => {
      const current = ++request
      try {
        const response = await fetch(`${subdomainInput.dataset.checkUrl}?subdomain=${encodeURIComponent(value)}`)
        const result = await response.json()
        if (current !== request) return
        status.textContent = result.available ? `✓ ${result.host}` : result.message
        status.dataset.state = result.available ? "ok" : "error"
      } catch {
        status.textContent = defaultHint
        delete status.dataset.state
      }
    }, 300)
  }

  nameInput.addEventListener("input", () => {
    if (edited) return
    subdomainInput.value = slugify(nameInput.value)
    check()
  })

  subdomainInput.addEventListener("input", () => {
    edited = subdomainInput.value !== ""
    subdomainInput.value = subdomainInput.value.toLowerCase().replace(/[^a-z0-9-]/g, "")
    check()
  })

  if (subdomainInput.value) check()
}

document.querySelectorAll("[data-signup]").forEach(startSignup)
