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

  const donateLabel = donateButton?.textContent
  let sending = false

  const show = (state) => {
    Object.entries(states).forEach(([name, element]) => { element.hidden = name !== state })
  }
  const showError = (message) => {
    root.querySelector("#errorMessage").textContent = message
    show("error")
    returnToStart()
  }
  // The next donor shouldn't find the previous donor's result on screen
  const returnToStart = () => setTimeout(() => location.reload(), RETURN_TO_START_MS)
  const value = (selector) => root.querySelector(selector)?.value ?? ""

  // One tap sends a preset amount to the reader, so everything locks until the outcome is
  // known: a second tap mustn't start a second payment.
  presetButtons.forEach((button) => {
    button.addEventListener("click", () => {
      button.setAttribute("aria-pressed", "true")
      donate(parseFloat(button.dataset.amount), button)
    })
  })

  donateButton?.addEventListener("click", () => {
    const amount = parseFloat(customAmount.value)

    if (!amount || amount <= 0) {
      showFormError(text.textNoAmount)
      return
    }
    donateButton.textContent = text.textWorking
    donate(amount, donateButton)
  })

  const lock = (locked) => {
    presetButtons.forEach((button) => { button.disabled = locked })
    if (donateButton) donateButton.disabled = locked
    if (customAmount) customAmount.disabled = locked
  }

  function showFormError(message) {
    formError.textContent = message
    formError.hidden = false
  }

  async function donate(amount, trigger) {
    if (sending) return
    sending = true
    formError.hidden = true
    lock(true)

    try {
      const response = await fetch(`/donations?locale=${text.locale}`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector('[name="csrf-token"]').content
        },
        body: JSON.stringify({
          donation: { amount: amount, donor_name: value("#donorName"), donor_email: value("#donorEmail") }
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
      // Nothing reached the reader, so the donor can simply try again
      sending = false
      lock(false)
      trigger.setAttribute("aria-pressed", "false")
      if (donateButton) donateButton.textContent = donateLabel
      showFormError(text.textNetwork)
    }
  }

  function poll(donationId) {
    let polls = 0

    pollTimer = setInterval(async () => {
      polls += 1

      try {
        const response = await fetch(`/donations/${donationId}/status?locale=${text.locale}`)
        const data = await response.json()

        if (data.status === "successful") {
          clearInterval(pollTimer)
          root.querySelector("#successAmount").textContent = data.amount
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
