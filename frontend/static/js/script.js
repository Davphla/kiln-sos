import Modal from './modal.js';
import { sortAssetsForDeposit, sortAssetsForWithdraw } from './filterAssetsUtils.js';
import { daysMapping, networks, protocols, assets } from './data.js';
import ForwardRateCalculator from './ForwardRateCalculator.js';
import { addDays } from './dateUtils.js';

document.addEventListener('DOMContentLoaded', async () => {
    let forwardRatesData;
    async function loadJSON(filePath) {
        try {
            const response = await fetch(filePath);
            if (!response.ok) {
                throw new Error(`Erreur HTTP : ${response.status}`);
            }
            return await response.json();
        } catch (error) {
            console.error("Erreur lors de la lecture du JSON :", error);
            return null;
        }
    }

    try {
        forwardRatesData = await loadJSON("../../../backend/forward_rates.json");
        console.log(forwardRatesData);
        const modal = new Modal();
        const forwardRateCalculator = new ForwardRateCalculator();

        // Track current selections
        let currentNetwork = networks[0];
        let currentAsset = assets[0];
        let currentProtocol = protocols[0];

        // Function to get slider position and value
        function getSliderInfo() {
            const slider = $("#serrated-slider");
            const value = slider.slider("value");
            const step = 16.66;
            const position = Math.round(value / step);
            const periods = ["1 week", "1 month", "2 months", "3 months", "6 months", "9 months", "1 year"];
            return {
                number: position,
                text: periods[position]
            };
        }

        // Function to update values based on slider and checkbox state
        function updateValues(isChecked) {
            const apyValue = document.querySelector('.apy-value');
            const rewardValue = document.querySelector('.reward-value');
            const costText = document.querySelector('.cost-text');

            if (!apyValue || !rewardValue || !costText)
                return;

            if (!isChecked) {
                rewardValue.textContent = '--%';
                costText.textContent = 'Cost: --';
                rewardValue.style.color = '#ff5d00'; // Orange
                apyValue.style.textDecoration = 'none';
                return;
            }

            const selectedCurrency = apyValue.textContent.replace('%', '').trim();
            const sliderInfo = getSliderInfo();
            const targetDate = addDays(new Date(), daysMapping[sliderInfo.number]);
            const originalApy = parseFloat(selectedCurrency);
            const hedgeCost = forwardRateCalculator.calculateCost(
                forwardRatesData,
                "EURUSD",
                targetDate
            );
            // Convert to percentage and adjust precision
            const hedgeCostPercent = hedgeCost * 100;
            const netApy = originalApy - hedgeCostPercent;
            rewardValue.textContent = `${netApy.toFixed(2)}%`;
            rewardValue.style.color = '#00FF00'; // Green
            costText.textContent = `Cost: ${hedgeCostPercent.toFixed(2)}% / ${sliderInfo.text}`;
            apyValue.style.textDecoration = 'line-through';
        }

        // Handle hedge checkbox changes
        document.querySelector('#option1').addEventListener('change', function() {
            updateValues(this.checked);
        });

        // Add click handler for token dropdown
        document.querySelector('.token-dropdown').addEventListener('click', () => {
            modal.show(
                'Select network',
                'Search by network...',
                networks,
                (network, index) => {
                    const isSelected = network.id === currentNetwork.id;
                    return `
                        <div class="item network-item ${isSelected ? 'selected' : ''}" data-index="${index}">
                            <div class="item-left">
                                <img src="${network.icon}" alt="${network.name}">
                                <div class="item-info">
                                    <div class="item-name">${network.name}</div>
                                </div>
                            </div>
                        </div>
                    `;
                },
                (network) => {
                    currentNetwork = network;
                    document.querySelector('.token-dropdown img').src = network.icon;
                    document.querySelector('.token-dropdown span').textContent = network.name;
                },
                currentNetwork.id
            );
        });

        // Add click handler for MAX button
        document.querySelector('.max-button').addEventListener('click', () => {
            const availableText = document.querySelector('.available').textContent;
            const amount = availableText.split(' ')[0];
            document.querySelector('.amount-input').value = amount;
        });

        // Add click handlers for selectors
        document.querySelector('.via-selector').addEventListener('click', () => {
            modal.show(
                'Select protocol',
                'Search by protocol...',
                protocols,
                (protocol, index) => {
                    const isSelected = protocol.id === currentProtocol.id;
                    return `
                        <div class="item ${isSelected ? 'selected' : ''}" data-index="${index}">
                            <div class="item-left">
                                <img src="${protocol.icon}" alt="${protocol.name}">
                                <div class="item-info">
                                    <div class="item-name">${protocol.name}</div>
                                    <div class="item-type">${protocol.type}</div>
                                </div>
                            </div>
                            <div class="item-right">
                                <div class="item-apy">${protocol.apy}</div>
                                <div class="item-desc">${protocol.description}</div>
                            </div>
                        </div>
                    `;
                },
                (protocol) => {
                    currentProtocol = protocol;
                    document.querySelector('.via-selector img').src = protocol.icon;
                    document.querySelector('.via-selector span').textContent = `via ${protocol.name}`;
                    document.querySelector('.apy-value').textContent = protocol.apy;
                },
                currentProtocol.id
            );
        });

        // Add toggle functionality for rewards details
        document.querySelector('.rewards-header').addEventListener('click', () => {
            const details = document.querySelector('.rewards-details');
            const arrow = document.querySelector('.rewards-header .dropdown-arrow');
            details.classList.toggle('visible');
            arrow.classList.toggle('rotated');
        });

        // Currency selector in deposit section
        document.querySelector('.deposit-section .currency-selector').addEventListener('click', () => {
            modal.show(
                'Select asset',
                'Search by asset...',
                sortAssetsForDeposit(assets),
                (asset, index) => {
                    const isSelected = asset.id === currentAsset.id;
                    return `
                        <div class="item ${isSelected ? 'selected' : ''}" data-index="${index}">
                            <div class="item-left">
                                <img src="${asset.icon}" alt="${asset.symbol}">
                                <div class="item-info">
                                    <div class="item-name">${asset.symbol}</div>
                                    <div class="item-type">${asset.name}</div>
                                </div>
                            </div>
                            <div class="item-right">
                                <div class="item-balance">${asset.balance}</div>
                            </div>
                        </div>
                    `;
                },
                (asset) => {
                    currentAsset = asset;
                    document.querySelector('.currency-selector img').src = asset.icon;
                    document.querySelector('.currency-selector span').textContent = asset.symbol;
                    document.querySelector('.available').textContent = `${asset.balance} AVAILABLE`;
                },
                currentAsset.id
            );
        });

        // Update slider event to recalculate hedge when changed
        $("#serrated-slider").on("slidechange", function(event, ui) {
            const index = Math.round(ui.value / 16.66);
            const periods = ["1 week", "1 month", "2 months", "3 months", "6 months", "9 months", "1 year"];
            $("#slider-value").text(periods[index]);
            // Update values based on current checkbox state
            const isChecked = document.querySelector('#option1').checked;
            updateValues(isChecked);
        });

        // Currency selector in withdraw section
        document.querySelector('.withdraw-section .currency-selector').addEventListener('click', () => {
            modal.show(
                'Select asset',
                'Search by asset...',
                sortAssetsForWithdraw(assets),
                (asset, index) => {
                    const isSelected = asset.id === currentAsset.id;
                    return `
                        <div class="item ${isSelected ? 'selected' : ''}" data-index="${index}">
                            <div class="item-left">
                                <img src="${asset.icon}" alt="${asset.symbol}">
                                <div class="item-info">
                                    <div class="item-name">${asset.symbol}</div>
                                    <div class="item-type">${asset.name}</div>
                                </div>
                            </div>
                            <div class="item-right">
                                <div class="item-balance">${asset.balance}</div>
                            </div>
                        </div>
                    `;
                },
                (asset) => {
                    currentAsset = asset;
                    const currencySelector = document.querySelector('.withdraw-section .currency-selector');
                    currencySelector.querySelector('img').src = asset.icon;
                    currencySelector.querySelector('span').textContent = asset.symbol;
                },
                currentAsset.id
            );
        });
    } catch (error) {
        console.error('Initialization error:', error);
    }
});
