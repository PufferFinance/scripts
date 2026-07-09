// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {IInstitutionalVault} from "../src/interface/IInstitutionalVault.sol";

// forge script script/WithdrawNonRestakedETH.s.sol:WithdrawNonRestakedETH --rpc-url=$HOLESKY_RPC_URL --account institutional-deployer-testnet -vvvv --sig "run(address)" <institutionalVaultProxy>
// add --broadcast to broadcast the transaction
contract WithdrawNonRestakedETH is Script {
    function run(address payable institutionalVaultProxy) public {
        vm.startBroadcast();

        console.log("Withdrawing non-restaked ETH from vault:", institutionalVaultProxy);

        IInstitutionalVault(institutionalVaultProxy).withdrawNonRestakedETH();

        console.log("Non-restaked ETH withdrawn successfully");

        vm.stopBroadcast();
    }
}
