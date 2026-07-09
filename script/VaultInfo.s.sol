// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {IInstitutionalVault} from "../src/interface/IInstitutionalVault.sol";

// forge script script/VaultInfo.s.sol:VaultInfo --rpc-url=$HOLESKY_RPC_URL -vvvv --sig "run(address)" <institutionalVaultProxy>
// No broadcast needed (view-only)
contract VaultInfo is Script {
    function run(address payable institutionalVaultProxy) public view {
        IInstitutionalVault vault = IInstitutionalVault(institutionalVaultProxy);

        console.log("=== Vault Info ===");
        console.log("Vault address:", institutionalVaultProxy);
        console.log("");

        console.log("Total assets (wei):", vault.totalAssets());
        console.log("Restaked validator ETH (wei):", vault.getRestakedValidatorETH());
        console.log("Non-restaked validator ETH (wei):", vault.getNonRestakedValidatorETH());
        console.log("");

        console.log("EigenPod:", vault.getEigenPod());
        console.log("No-restaking withdrawal credentials:", vault.getNoRestakingWithdrawalCredentials());
        console.log("");

        console.log("EigenPod withdrawal credentials:");
        console.logBytes(vault.getEigenPodWithdrawalCredentials());

        console.log("Non-restaking withdrawal credentials:");
        console.logBytes(vault.getWithdrawalCredentials());
    }
}
