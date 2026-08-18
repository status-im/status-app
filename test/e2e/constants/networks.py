from enum import Enum


class WalletNetworkNaming(Enum):
    LAYER1_ETHEREUM_TESTNET = 'Sepolia'
    LAYER1_ETHEREUM_HOODI = 'Hoodi'
    LAYER2_OPTIMISM_SEPOLIA = 'Optimism Sepolia'
    LAYER2_ARBITRUM_SEPOLIA = 'Arbitrum Sepolia'


# L2 testnets used by NFT send e2e.
LAYER2_ETHEREUM_TESTNETS = (
    WalletNetworkNaming.LAYER2_ARBITRUM_SEPOLIA,
    WalletNetworkNaming.LAYER2_OPTIMISM_SEPOLIA,
)
