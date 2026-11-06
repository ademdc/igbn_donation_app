// The donation terminal: amount selection, starting the payment, then polling until the
// reader has an outcome. Worded through data-text-* attributes, so it speaks the page's language.

const POLL_INTERVAL_MS = 5000
const MAX_POLLS = 60 // 5 minutes
const RETURN_TO_START_MS = 30000

let pollTimer = null

function startTerminal(root) {
  clearInterval(pollTimer)

  const text = root.dataset
  const presetButtons = root.querySelectorAll(".preset-amount-btn")
  const customAmount = root.querySelector("#customAmount")
  const donateButton = root.querySelector("#donateBtn")
  const formError = root.querySelector("#formError")
  const states = {
    form: root.querySelector("#donationForm"),
    processing: root.querySelector("#processingState"),
    success: root.querySelector("#successState"),
    error: root.querySelector("#errorState")
  }

  if (!states.form) return

  let selectedAmount = null

  const show = (state) => {
    Object.entries(states).forEach(([name, element]) => { element.hidden = name !== state })
  }
  const showError = (message) => {
    root.querySelector("#errorMessage").textContent = message
    show("error")
    returnToStart()
  }
  const money = (amount) => `${text.currencySymbol}${new Intl.NumberFormat(text.locale, { minimumFractionDigits: 2 }).format(amount)}`
  // The next donor shouldn't find the previous donor's result on screen
  const returnToStart = () => setTimeout(() => location.reload(), RETURN_TO_START_MS)
  const value = (selector) => root.querySelector(selector)?.value ?? ""

  presetButtons.forEach((button) => {
    button.addEventListener("click", () => {
      presetButtons.forEach((other) => other.setAttribute("aria-pressed", "false"))
      button.setAttribute("aria-pressed", "true")
      selectedAmount = parseFloat(button.dataset.amount)
      if (customAmount) customAmount.value = ""
    })
  })

  customAmount?.addEventListener("input", () => {
    presetButtons.forEach((button) => button.setAttribute("aria-pressed", "false"))
    selectedAmount = parseFloat(customAmount.value)
  })

  donateButton.addEventListener("click", async () => {
    if (!selectedAmount || selectedAmount <= 0) {
      formError.textContent = text.textNoAmount
      formError.hidden = false
      return
    }

    formError.hidden = true
    const label = donateButton.textContent
    donateButton.disabled = true
    donateButton.textContent = text.textWorking

    try {
      const response = await fetch(`/donations?locale=${text.locale}`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector('[name="csrf-token"]').content
        },
        body: JSON.stringify({
          donation: { amount: selectedAmount, donor_name: value("#donorName"), donor_email: value("#donorEmail") }
        })
      })
      const data = await response.json()

      if (data.success) {
        show("processing")
        poll(data.donation_id)
      } else {
        showError(data.error)
      }
    } catch {
      donateButton.disabled = false
      donateButton.textContent = label
      formError.textContent = text.textNetwork
      formError.hidden = false
    }
  })

  function poll(donationId) {
    let polls = 0

    pollTimer = setInterval(async () => {
      polls += 1

      try {
        const response = await fetch(`/donations/${donationId}/status`)
        const data = await response.json()

        if (data.status === "successful") {
          clearInterval(pollTimer)
          root.querySelector("#successAmount").textContent = money(data.amount)
          show("success")
          returnToStart()
          return
        }
        if (data.status === "failed" || data.status === "cancelled") {
          clearInterval(pollTimer)
          showError(text.textDeclined)
          return
        }
      } catch (error) {
        console.error("Status check failed:", error)
      }

      if (polls >= MAX_POLLS) {
        clearInterval(pollTimer)
        showError(text.textTimeout)
      }
    }, POLL_INTERVAL_MS)
  }

  async function checkReader() {
    const status = root.querySelector("#readerStatus")
    const statusText = root.querySelector("#readerStatusText")

    try {
      const response = await fetch("/reader_status")
      if (!response.ok) return
      const data = await response.json()

      const state = !data.online ? "offline" : data.state === "IDLE" ? "ready" : "busy"
      status.dataset.state = state
      statusText.textContent = { ready: text.textReady, offline: text.textOffline, busy: text.textBusy }[state]
      status.hidden = false
    } catch (error) {
      console.error("Reader status check failed:", error)
    }
  }

  root.querySelectorAll("[data-restart]").forEach((button) => {
    button.addEventListener("click", () => location.reload())
  })

  checkReader()
}

document.addEventListener("turbo:load", () => {
  const root = document.querySelector("[data-terminal]")
  if (root) startTerminal(root)
})
