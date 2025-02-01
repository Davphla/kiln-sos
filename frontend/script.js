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
        id: 'kiln-morpho',
        name: 'Kiln Morpho',
        type: 'USDT Lending',
        apy: '12.24%',
        description: 'current NRR',
        icon: 'images/venus.svg'
    }
];

const assets = [
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
    }

    show(title, placeholder, items, renderItem, onSelect) {
        this.modal.querySelector('h2').textContent = title;
        this.searchInput.placeholder = placeholder;
        this.items = items;
        this.renderItem = renderItem;
        this.onSelect = onSelect;
        this.renderItems(items);
        this.modal.style.display = 'flex';
    }

    hide() {
        this.modal.style.display = 'none';
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
        body.innerHTML = items.map(item => this.renderItem(item)).join('');
        body.querySelectorAll('.item').forEach(el => {
            el.addEventListener('click', () => {
                this.onSelect(items[el.dataset.index]);
                this.hide();
            });
        });
    }
}

// Initialize when document is ready
document.addEventListener('DOMContentLoaded', () => {
    const modal = new Modal();

    // Add click handler for token dropdown
    document.querySelector('.token-dropdown').addEventListener('click', () => {
        modal.show(
            'Select network',
            'Search by network...',
            networks,
            (network, index) => `
                <div class="item" data-index="${index}">
                    <div class="item-left">
                        <img src="${network.icon}" alt="${network.name}">
                        <div class="item-info">
                            <div class="item-name">${network.name}</div>
                        </div>
                    </div>
                </div>
            `,
            (network) => {
                document.querySelector('.token-dropdown img').src = network.icon;
                document.querySelector('.token-dropdown span').textContent = network.name;
            }
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
            (protocol, index) => `
                <div class="item" data-index="${index}">
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
            `,
            (protocol) => {
                document.querySelector('.via-selector img').src = protocol.icon;
                document.querySelector('.via-selector span').textContent = `via ${protocol.name}`;
                document.querySelector('.apy-value').textContent = protocol.apy;
            }
        );
    });

    document.querySelector('.currency-selector').addEventListener('click', () => {
        modal.show(
            'Select asset',
            'Search by asset...',
            assets,
            (asset, index) => `
                <div class="item" data-index="${index}">
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
            `,
            (asset) => {
                document.querySelector('.currency-selector img').src = asset.icon;
                document.querySelector('.currency-selector span').textContent = asset.symbol;
                document.querySelector('.available').textContent = `${asset.balance} AVAILABLE`;
            }
        );
    });
});
