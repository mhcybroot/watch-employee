document.getElementById('submitBtn').addEventListener('click', async () => {
    const code = document.getElementById('enrollmentCode').value.trim();
    const statusDiv = document.getElementById('status');
    const submitBtn = document.getElementById('submitBtn');

    if (!code) {
        statusDiv.className = 'error';
        statusDiv.textContent = 'Please enter a valid code.';
        return;
    }

    submitBtn.disabled = true;
    statusDiv.textContent = 'Linking account...';

    try {
        // Save to browser storage
        await browser.storage.local.set({ deviceId: code });

        statusDiv.className = 'success';
        statusDiv.textContent = 'Success! Linking browser...';

        // Brief delay for visual feedback, then close
        setTimeout(() => {
            window.close();
            // Fallback for some browsers where window.close() might fail from script
            alert('Setup complete! You can close this tab now.');
        }, 1000);

    } catch (error) {
        console.error('Setup error:', error);
        statusDiv.className = 'error';
        statusDiv.textContent = 'An error occurred. Please try again.';
        submitBtn.disabled = false;
    }
});

// Enable 'Enter' key to submit
document.getElementById('enrollmentCode').addEventListener('keypress', (e) => {
    if (e.key === 'Enter') {
        document.getElementById('submitBtn').click();
    }
});
