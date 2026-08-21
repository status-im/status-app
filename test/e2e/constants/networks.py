from enum import Enum


class WalletNetworkNaming(Enum):
    LAYER1_ETHEREUM_TESTNET = (11155111, 'Sepolia')
    LAYER1_ETHEREUM_HOODI = (560048, 'Hoodi')
    LAYER2_OPTIMISM_SEPOLIA = (11155420, 'Optimism Sepolia')
    LAYER2_ARBITRUM_SEPOLIA = (421614, 'Arbitrum Sepolia')

    def __new__(cls, chain_id: int, label: str):
        obj = object.__new__(cls)
        obj._value_ = label
        obj.chain_id = chain_id
        return obj

    @classmethod
    def from_chain_id(cls, chain_id: int) -> str:
        for network in cls:
            if network.chain_id == chain_id:
                return network.value
        return str(chain_id)


# L2 testnets used by NFT send e2e.
LAYER2_ETHEREUM_TESTNETS = (
    WalletNetworkNaming.LAYER2_ARBITRUM_SEPOLIA,
    WalletNetworkNaming.LAYER2_OPTIMISM_SEPOLIA,
)
