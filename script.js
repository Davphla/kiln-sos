// Data structures for available options
const networks = [
    {
        id: 'sepolia',
        name: 'Sepolia',
        icon: 'https://sepolia.etherscan.io/images/main/empty-token.png'
    },
    {
        id: 'bnb',
        name: 'BNB Smart Chain',
        icon: 'https://cryptologos.cc/logos/bnb-bnb-logo.png'
    },
    {
        id: 'ethereum',
        name: 'Ethereum',
        icon: 'https://cryptologos.cc/logos/ethereum-eth-logo.png'
    }
];

const protocols = [
    {
        id: 'dedicated-staking',
        name: 'Dedicated Staking',
        type: 'ETH Dedicated Staking',
        apy: '3.98%',
        description: 'current NRR',
        icon: 'https://cryptologos.cc/logos/ethereum-eth-logo.png'
    },
    {
        id: 'kiln-compound',
        name: 'Kiln Compound V3',
        type: 'USDC Lending',
        apy: '5.78%',
        description: 'current NRR',
        icon: 'https://cryptologos.cc/logos/compound-comp-logo.png'
    },
    { 
        id: 'kiln-morpho',
        name: 'Kiln Morpho',
        type: 'USDT Lending',
        apy: '12.24%',
        description: 'current NRR',
        icon: 'images/morpho.svg'
    },
    {
        id: 'kiln-aave',
        name: 'Kiln Aave V3',
        type: 'USDC Lending',
        apy: '5.08%',
        description: 'current NRR',
        icon: 'https://cryptologos.cc/logos/aave-aave-logo.png'
    },
    {
        id: 'kiln-venus',
        name: 'Kiln Venus',
        type: 'USDC Lending',
        apy: '6.90%',
        description: 'current NRR',
        icon: 'images/venus.svg'
    },
    {
        id: 'kiln-sdai',
        name: 'Kiln sDAI',
        type: 'DAI Lending',
        apy: '6.25%',
        description: 'current NRR',
        icon: 'https://cryptologos.cc/logos/multi-collateral-dai-dai-logo.png'
    }
];

const assets = [
    {
        id: 'eurc-eth',
        symbol: 'EURC',
        name: 'Circle',
        balance: '0.00 EURC',
        icon: 'images/eurc.png'
    },
    {
        id: 'eurcv-eth',
        symbol: 'EURCV',
        name: 'Coinvertible',
        balance: '0.00 EURCV',
        icon: 'https://www.sgforge.com/favicon.ico'
    },
    {
        id: 'eure-eth',
        symbol: 'EURe',
        name: 'Monerium',
        balance: '0.00 EURe',
        icon: 'images/monerium.png'
    },
    {
        id: 'usdc-bnb',
        symbol: 'USDC',
        name: 'BNB Smart Chain',
        balance: '889.74 USDC',
        icon: 'https://cryptologos.cc/logos/usd-coin-usdc-logo.png'
    },
    {
        id: 'usdc-op',
        symbol: 'USDC',
        name: 'OP Mainnet',
        balance: '426.62 USDC',
        icon: 'https://cryptologos.cc/logos/usd-coin-usdc-logo.png'
    },
    {
        id: 'dai-base',
        symbol: 'DAI',
        name: 'Base',
        balance: '0.00 DAI',
        icon: 'https://cryptologos.cc/logos/multi-collateral-dai-dai-logo.png'
    },
    {
        id: 'usdt-eth',
        symbol: 'USDT',
        name: 'Ethereum',
        balance: '471.91 USDT',
        icon: 'https://cryptologos.cc/logos/tether-usdt-logo.png'
    },
    {
        id: 'usdc-arb',
        symbol: 'USDC',
        name: 'Arbitrum One',
        balance: '0.00 USDC',
        icon: 'https://cryptologos.cc/logos/usd-coin-usdc-logo.png'
    },
    {
        id: 'eth-eth',
        symbol: 'ETH',
        name: 'Ethereum',
        balance: '10.19 ETH',
        icon: 'https://cryptologos.cc/logos/ethereum-eth-logo.png'
    },
    {
        id: 'sol-sol',
        symbol: 'SOL',
        name: 'Solana',
        balance: '0.00 SOL',
        icon: 'https://cryptologos.cc/logos/solana-sol-logo.png'
    }
];

// Modal component
class Modal {
    constructor() {
        this.modal = document.createElement('div');
        this.modal.className = 'modal';
        this.modal.innerHTML = `
            <div class="modal-content">
                <div class="modal-header">
                    <button class="back-button">←</button>
                    <h2></h2>
                    <input type="text" class="search-input" placeholder="">
                </div>
                <div class="modal-body"></div>
            </div>
        `;
        document.body.appendChild(this.modal);

        this.modal.querySelector('.back-button').addEventListener('click', () => this.hide());
        this.searchInput = this.modal.querySelector('.search-input');
        this.searchInput.addEventListener('input', (e) => this.handleSearch(e.target.value));
        
        this.selectedId = null;
    }

    show(title, placeholder, items, renderItem, onSelect, currentId = null) {
        this.modal.querySelector('h2').textContent = title;
        this.searchInput.placeholder = placeholder;
        this.items = items;
        this.renderItem = renderItem;
        this.onSelect = onSelect;
        this.selectedId = currentId;
        this.renderItems(items);
        this.modal.style.display = 'flex';
        this.searchInput.value = '';
        this.searchInput.focus();
    }

    hide() {
        this.modal.style.display = 'none';
        this.searchInput.value = '';
    }

    handleSearch(query) {
        const filtered = this.items.filter(item => 
            item.name.toLowerCase().includes(query.toLowerCase()) ||
            item.symbol?.toLowerCase().includes(query.toLowerCase())
        );
        this.renderItems(filtered);
    }

    renderItems(items) {
        const body = this.modal.querySelector('.modal-body');
        body.innerHTML = items.map((item, index) => {
            const isSelected = item.id === this.selectedId;
            return this.renderItem(item, index);
        }).join('');
        
        body.querySelectorAll('.item').forEach(el => {
            el.addEventListener('click', () => {
                const item = items[el.dataset.index];
                this.selectedId = item.id;
                this.onSelect(item);
                this.hide();
            });
        });
    }
}

// Helper functions
const isEurRelated = (asset) => {
    const eurSymbols = ['EURC', 'EURCV', 'EURe'];
    return eurSymbols.includes(asset.symbol);
};

const isStablecoin = (asset) => {
    const stableSymbols = ['USDC', 'USDT', 'DAI', 'EURC', 'EURCV', 'EURe'];
    return stableSymbols.includes(asset.symbol);
};

const sortAssetsForDeposit = (assets) => {
    return [...assets].sort((a, b) => {
        const aIsEur = isEurRelated(a);
        const bIsEur = isEurRelated(b);
        if (aIsEur && !bIsEur) return 1;
        if (!aIsEur && bIsEur) return -1;
        return 0;
    });
};

const sortAssetsForWithdraw = (assets) => {
    // Filter stablecoins only and sort with EUR-related first
    return assets
        .filter(isStablecoin)
        .sort((a, b) => {
            const aIsEur = isEurRelated(a);
            const bIsEur = isEurRelated(b);
            if (aIsEur && !bIsEur) return -1;
            if (!aIsEur && bIsEur) return 1;
            return 0;
        });
};

// Initialize when document is ready
document.addEventListener('DOMContentLoaded', () => {
    const modal = new Modal();

    // Track current selections
    let currentNetwork = networks[0];
    let currentAsset = assets[0];
    let currentProtocol = protocols[0];

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

    // Handle hedge checkbox changes
    document.querySelector('#option1').addEventListener('change', function() {
        const rewardValue = document.querySelector('.reward-value');
        const costText = document.querySelector('.cost-text');
        const apyValue = document.querySelector('.apy-value');
        
        if (this.checked) {
            // When checked, show lower reward but with cost
            rewardValue.textContent = '8.45%';
            costText.textContent = 'Cost: 1.79%';
            apyValue.style.textDecoration = 'line-through';
            apyValue.style.color = '#666';
        } else {
            // When unchecked, show higher reward with no cost
            rewardValue.textContent = '--%';
            costText.textContent = 'Cost: --';
            apyValue.style.textDecoration = 'none';
            apyValue.style.color = '#ff5d00';
        }
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
});
