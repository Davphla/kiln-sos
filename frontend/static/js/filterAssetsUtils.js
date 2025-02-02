export const isEurRelated = (asset) => {
    const eurSymbols = ['EURC', 'EURCV', 'EURe'];
    return eurSymbols.includes(asset.symbol);
};

export const isStablecoin = (asset) => {
    const stableSymbols = ['USDC', 'USDT', 'DAI', 'EURC', 'EURCV', 'EURe'];
    return stableSymbols.includes(asset.symbol);
};

export const sortAssetsForDeposit = (assets) => {
    return [...assets].sort((a, b) => {
        const aIsEur = isEurRelated(a);
        const bIsEur = isEurRelated(b);
        if (aIsEur && !bIsEur) return 1;
        if (!aIsEur && bIsEur) return -1;
        return 0;
    });
};

export const sortAssetsForWithdraw = (assets) => {
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
