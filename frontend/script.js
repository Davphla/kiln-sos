document.addEventListener('DOMContentLoaded', () => {
    // Tab switching
    const tabs = document.querySelectorAll('.tab');
    tabs.forEach(tab => {
        tab.addEventListener('click', () => {
            tabs.forEach(t => t.classList.remove('active'));
            tab.classList.add('active');
        });
    });

    // MAX button functionality
    const maxButton = document.querySelector('.max-button');
    const amountInput = document.querySelector('.amount-input');
    const availableAmount = 889.7400; // From the available USDC text

    maxButton.addEventListener('click', () => {
        amountInput.value = availableAmount;
        updateReceiveAmount();
    });

    // Amount input handling
    amountInput.addEventListener('input', updateReceiveAmount);

    function updateReceiveAmount() {
        const amount = parseFloat(amountInput.value) || 0;
        const vkUSDCRate = 0; // Rate from KILN VENUS RATE
        const vkUSDCAmount = amount * vkUSDCRate;
        
        // Update the receive amount display
        document.querySelector('.rewards-header span').textContent = 
            `You will receive ${vkUSDCAmount.toFixed(4)} vkUSDC`;
        
        // Update deposit and receive rows
        document.querySelector('.deposit-row span:last-child').textContent = 
            `${amount.toFixed(4)} USDC ($${amount.toFixed(2)})`;
        document.querySelector('.receive-row span:last-child').textContent = 
            `${vkUSDCAmount.toFixed(4)} VKUSDC ($${amount.toFixed(2)})`;
    }

    // Rewards info dropdown
    const rewardsHeader = document.querySelector('.rewards-header');
    const rewardsDetails = document.querySelector('.rewards-details');
    let rewardsExpanded = true; // Start expanded as shown in the image

    rewardsHeader.addEventListener('click', () => {
        rewardsExpanded = !rewardsExpanded;
        rewardsDetails.style.display = rewardsExpanded ? 'block' : 'none';
        rewardsHeader.querySelector('.dropdown-arrow').textContent = 
            rewardsExpanded ? '▼' : '▲';
    });

    // Earn button
    const earnButton = document.querySelector('.earn-button');
    earnButton.addEventListener('click', () => {
        const amount = parseFloat(amountInput.value) || 0;
        if (amount <= 0) {
            alert('Please enter an amount greater than 0');
            return;
        }
        if (amount > availableAmount) {
            alert('Amount exceeds available balance');
            return;
        }
        alert('Transaction initiated'); // In a real app, this would trigger the blockchain transaction
    });

    // Initialize the rewards details visibility
    rewardsDetails.style.display = 'block';
});
