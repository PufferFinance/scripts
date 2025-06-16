// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import {IDelegationManagerTypes} from "./Eigenlayer-Slashing/IDelegationManager.sol";

interface IInstitutionalVault {
    /**
     * @notice Event emitted when a validator is started to be restaked
     * @param pubKey The public key of the validator
     * @param depositDataRoot The deposit data root of the validator
     */
    event StartedRestakingValidator(bytes pubKey, bytes32 depositDataRoot);

    /**
     * @notice Event emitted when a validator is started to be non restaked
     * @param pubKey The public key of the validator
     * @param depositDataRoot The deposit data root of the validator
     */
    event StartedNonRestakingValidator(bytes pubKey, bytes32 depositDataRoot);

    /**
     * @notice Event emitted when a custom external call is made
     * @param target The address of the target contract
     * @param data The data to call the target contract with
     * @param value The amount of ETH to send with the call
     */
    event CustomExternalCall(address indexed target, bytes data, uint256 value);

    /**
     * @notice Event emitted when the ETH in the restaked validators is updated
     * @param ethAmount The amount of ETH in the restaked validators
     */
    event RestakedValidatorsETHUpdated(uint256 ethAmount);

    /**
     * @notice Event emitted when the ETH in the non restaked validators is updated
     * @param ethAmount The amount of ETH in the non restaked validators
     */
    event NonRestakedValidatorsETHUpdated(uint256 ethAmount);

    /**
     * @notice Deposit ETH into the vault
     * Depositor receives institutionalETH shares in return
     * @param receiver The address to receive the shares
     * @return shares The amount of shares (institutionalETH) minted
     */
    function depositETH(address receiver) external payable returns (uint256);

    /**
     * @notice Override the mint function to allow for the minting of shares (institutionalETH)
     * @param shares The amount of shares (institutionalETH) to mint
     * @param receiver The address to receive the shares
     * @return assets The amount of assets (WETH) minted
     */
    function mint(uint256 shares, address receiver) external returns (uint256 assets);

    /**
     * @notice Override the deposit function to allow for the deposit of shares (institutionalETH)
     * Restricted modifier is used to pause/unpause the deposit function
     * @param assets The amount of assets (WETH) to deposit
     * @param receiver The address to receive the shares
     * @return shares The amount of shares (institutionalETH) minted
     */
    function deposit(uint256 assets, address receiver) external returns (uint256);

    /**
     * @notice Redeems (institutionalETH) `shares` to receive (WETH) assets from the vault, burning the `owner`'s (institutionalETH) `shares`.
     * The caller of this function does not have to be the `owner` if the `owner` has approved the caller to spend their institutionalETH.
     * @param shares The amount of shares (institutionalETH) to withdraw
     * @param receiver The address to receive the assets (WETH)
     * @param owner The address of the owner for which the shares (institutionalETH) are burned.
     * @return assets The amount of assets (WETH) redeemed
     */
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256);

    /**
     * @notice Withdrawals WETH assets from the vault, burning the `owner`'s (institutionalETH) shares.
     * The caller of this function does not have to be the `owner` if the `owner` has approved the caller to spend their institutionalETH.
     * @param assets The amount of assets (WETH) to withdraw
     * @param receiver The address to receive the assets (WETH)
     * @param owner The address of the owner for which the shares (institutionalETH) are burned.
     * @return shares The amount of shares (institutionalETH) burned
     */
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256);

    /**
     * @notice Queue withdrawals for the restaking validators on EigenLayer
     * @param shareAmount The amount of shares to withdraw (wei)
     */
    function queueWithdrawals(uint256 shareAmount) external;

    /**
     * @notice Completes the queued withdrawals on the EigenLayer
     * @param withdrawals The withdrawals to complete
     * @param receiveAsTokens Whether to receive the tokens as tokens
     */
    function completeQueuedWithdrawals(
        IDelegationManagerTypes.Withdrawal[] calldata withdrawals,
        bool[] calldata receiveAsTokens
    ) external;

    /**
     * @notice Custom call to the target contract
     * @dev Payable is just in case that the owner wants to send ETH instead of using ETH/WETH from the Vault
     * @param target The address of the target contract
     * @param data The data to call the target contract with
     */
    function customExternalCall(address target, bytes calldata data, uint256 value) external payable;

    /**
     * @dev See {IERC4626-totalAssets}.
     * institutionalETH, the shares of the vault, will be backed primarily by the WETH asset.
     * However, at any point in time, the full backings may be a combination of stETH, WETH, and ETH.
     * `totalAssets()` is calculated by summing the following:
     * - WETH held in the vault contract
     * - ETH  held in the vault contract
     * - ETH locked in the Beacon Deposit Contract
     *
     * IMPORTANT:
     * The exchange rate of share token : asset token will not be 100% accurate.
     * Right now, that is not a problem because share token is not transferable.
     * In a future version, where the share token is transferable, we need to make sure that the exchange rate is accurate, by using some kind of Oracle.
     * That oracle will need to report the ETH amount of the validators that are locked in the Beacon Deposit Contract & ETH amount of the validators that are not slashed by the EigenLayer.
     *
     * NOTE on the native ETH deposits:
     * When dealing with NATIVE ETH deposits, we need to deduct callvalue from the balance.
     * The contract calculates the amount of shares(pufETH) to mint based on the total assets.
     * When a user sends ETH, the msg.value is immediately added to address(this).balance.
     * Since `address(this.balance)` is used in calculating `totalAssets()`, we must deduct the `callvalue()` from the balance to prevent the user from minting excess shares.
     * `msg.value` cannot be accessed from a view function, so we use assembly to get the callvalue.
     */
    function totalAssets() external view returns (uint256);

    /**
     * @notice Get the withdrawal credentials for the non restaking validators (this contract address)
     * @return The withdrawal credentials
     */
    function getWithdrawalCredentials() external view returns (bytes memory);

    /**
     * @notice Get the address of the EigenPod
     * @return The address of the EigenPod
     */
    function getEigenPod() external view returns (address);

    /**
     * @notice Get the number of restaked validators
     * @return The number of restaked validators
     */
    function getRestakedValidatorETH() external view returns (uint256);

    /**
     * @notice Get the number of non restaked validators
     * @return The number of non restaked validators
     */
    function getNonRestakedValidatorETH() external view returns (uint256);
}
