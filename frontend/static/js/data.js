
const daysMapping = [7, 30, 60, 90, 180, 270, 365];

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
        icon: '../static/images/morpho.svg'
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
        icon: '../static/images/venus.svg'
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
        icon: '../static/images/eurc.png'
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
        icon: '../static/images/monerium.png'
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

export { daysMapping, networks, protocols, assets };