document.getElementById('submitBtn').addEventListener('click', async () => {
    const code = document.getElementById('enrollmentCode').value.trim();
    const email = document.getElementById('userEmail').value.trim();
    const statusDiv = document.getElementById('status');
    const submitBtn = document.getElementById('submitBtn');

    if (!code || !email) {
        statusDiv.className = 'error';
        statusDiv.textContent = 'Please enter both email and enrollment code.';
        return;
    }

    // Basic email format validation
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
        statusDiv.className = 'error';
        statusDiv.textContent = 'Please enter a valid email address.';
        return;
    }

    submitBtn.disabled = true;
    statusDiv.textContent = 'Verifying server connection...';

    // Verify connection first
    try {
        // SERVER_URL is defined in config.jsor globally
        const response = await fetch(`${SERVER_URL}/api/blocked-sites?deviceId=setup_check`);
        if (!response.ok) {
            throw new Error(`Server returned ${response.status}`);
        }
    } catch (error) {
        statusDiv.className = 'error';
        statusDiv.textContent = "Cannot connect to server at " + SERVER_URL + "\n\nError: " + error.message + "\n\nPlease check if the server is running and the URL is correct.";
        submitBtn.disabled = false;
        return;
    }

    statusDiv.textContent = 'Linking account...';

    try {
        // Save to browser storage
        await chrome.storage.local.set({
            deviceId: code,
            userEmail: email
        });

        statusDiv.className = 'success';
        statusDiv.textContent = 'Success! Linking chrome...';

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
