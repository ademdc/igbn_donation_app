console.log('Donation JS loaded');
document.addEventListener('DOMContentLoaded', () => {
  const presetBtns = document.querySelectorAll('.preset-amount-btn');
  const customAmountInput = document.getElementById('customAmount');
  const donateBtn = document.getElementById('donateBtn');
  const donorNameInput = document.getElementById('donorName');
  const donorEmailInput = document.getElementById('donorEmail');
  
  const donationForm = document.getElementById('donationForm');
  const processingState = document.getElementById('processingState');
  const successState = document.getElementById('successState');
  const errorState = document.getElementById('errorState');
  
  let selectedAmount = null;
  let currentDonationId = null;
  let statusCheckInterval = null;

  // Check reader status on load
  checkReaderStatus();

  // Preset amount selection
  presetBtns.forEach(btn => {
    btn.addEventListener('click', () => {
      presetBtns.forEach(b => b.classList.remove('border-indigo-500', 'bg-indigo-50'));
      btn.classList.add('border-indigo-500', 'bg-indigo-50');
      selectedAmount = parseFloat(btn.dataset.amount);
      customAmountInput.value = '';
    });
  });

  // Custom amount input
  customAmountInput.addEventListener('input', () => {
    presetBtns.forEach(b => b.classList.remove('border-indigo-500', 'bg-indigo-50'));
    selectedAmount = parseFloat(customAmountInput.value);
  });

  // Donate button
  donateBtn.addEventListener('click', async () => {
    const amount = selectedAmount || parseFloat(customAmountInput.value);
    
    if (!amount || amount <= 0) {
      alert('Please select or enter a donation amount');
      return;
    }

    donateBtn.disabled = true;
    donateBtn.textContent = 'Processing...';

    try {
      const response = await fetch('/donations', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: JSON.stringify({
          donation: {
            amount: amount,
            currency: 'EUR',
            donor_name: donorNameInput.value,
            donor_email: donorEmailInput.value
          }
        })
      });

      const data = await response.json();

      if (data.success) {
        currentDonationId = data.donation_id;
        showProcessingState();
        startStatusPolling();
      } else {
        showError(data.error || 'Payment failed');
      }
    } catch (error) {
      showError('Network error. Please try again.');
    }
  });

  function showProcessingState() {
    donationForm.classList.add('hidden');
    processingState.classList.remove('hidden');
  }

  function showSuccess(amount) {
    processingState.classList.add('hidden');
    successState.classList.remove('hidden');
    document.getElementById('successAmount').textContent = `€${amount.toFixed(2)}`;
  }

  function showError(message) {
    donationForm.classList.add('hidden');
    processingState.classList.add('hidden');
    errorState.classList.remove('hidden');
    document.getElementById('errorMessage').textContent = message;
  }

  function startStatusPolling() {
    let attempts = 0;
    const maxAttempts = 60; // 5 minutes

    statusCheckInterval = setInterval(async () => {
      attempts++;

      try {
        const response = await fetch(`/donations/${currentDonationId}/status`);
        const data = await response.json();

        document.getElementById('paymentStatus').textContent = 
          `Status: ${data.status}... (${attempts}s)`;

        if (data.status === 'paid') {
          clearInterval(statusCheckInterval);
          showSuccess(data.amount);
        } else if (data.status === 'failed' || data.status === 'cancelled') {
          clearInterval(statusCheckInterval);
          showError(`Payment ${data.status}`);
        }

        if (attempts >= maxAttempts) {
          clearInterval(statusCheckInterval);
          showError('Payment timeout. Please check with staff.');
        }
      } catch (error) {
        console.error('Status check failed:', error);
      }
    }, 5000); // Check every 5 seconds
  }

  async function checkReaderStatus() {
    try {
      const response = await fetch('/reader_status');
      const data = await response.json();
      
      const statusEl = document.getElementById('readerStatus');
      const statusTextEl = document.getElementById('readerStatusText');
      
      if (data.status === 'ready' || data.status === 'idle') {
        statusTextEl.textContent = 'Ready';
        statusTextEl.classList.add('text-green-600');
        statusEl.classList.remove('hidden');
      } else {
        statusTextEl.textContent = data.status || 'Unknown';
        statusTextEl.classList.add('text-yellow-600');
        statusEl.classList.remove('hidden');
      }
    } catch (error) {
      console.error('Failed to check reader status:', error);
    }
  }
});