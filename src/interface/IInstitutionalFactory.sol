// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

/**
 * @title IInstitutionalFactory
 * @author Puffer Finance
 * @custom:security-contact security@puffer.fi
 */
interface IInstitutionalFactory {
    /**
     * @notice Emitted when a vault is created
     * @param vault The address of the vault
     * @param accessManager The address of the access manager
     * @param salt The salt used to create the vault
     */
    event VaultCreated(address indexed vault, address indexed accessManager, bytes32 indexed salt);

    /**
     * @notice Emitted when a vault is removed
     * @param vault The address of the vault
     */
    event VaultRemoved(address indexed vault);

    /**
     * @notice Creates a new vault
     * @param admin The admin of the access manager and the system
     * @param implementation The implementation that the vault will use
     * @param salt The salt used to create the vault
     * @param shareTokenName The name of the share token
     * @param shareTokenSymbol The symbol of the share token
     * @return The address of the vault and the address of the access manager
     */
    function createVault(
        address admin,
        address implementation,
        bytes32 salt,
        string calldata shareTokenName,
        string calldata shareTokenSymbol
    ) external returns (address, address);

    /**
     * @notice Returns the addresses of all vaults created by this factory
     * @return The addresses of all vaults
     */
    function getVaults() external view returns (address[] memory);
}
