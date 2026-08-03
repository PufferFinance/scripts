// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

/**
 * @notice One entry in the vault's fee-recipient list.
 * @dev Mirrors the struct in the InstitutionalVault repo. The field order is part of the ABI, so it must
 *      not be changed here independently.
 * @param recipient The address that receives the minted fee shares.
 * @param bps The recipient's share of the fee, in basis points.
 * @param name A human-readable label.
 */
struct FeeRecipient {
    address recipient;
    uint16 bps;
    string name;
}
