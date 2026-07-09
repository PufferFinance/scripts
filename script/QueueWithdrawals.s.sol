// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {IInstitutionalVault} from "../src/interface/IInstitutionalVault.sol";

// forge script script/QueueWithdrawals.s.sol:QueueWithdrawals --rpc-url=$HOLESKY_RPC_URL --account institutional-deployer-testnet -vvvv --sig "run(address,uint256)" <institutionalVaultProxy> <shareAmountInWei>
// add --broadcast to broadcast the transaction
contract QueueWithdrawals is Script {
    function run(address payable institutionalVaultProxy, uint256 shareAmount) public {
        vm.startBroadcast();

        console.log("Queueing withdrawal for share amount (wei):", shareAmount);

        IInstitutionalVault(institutionalVaultProxy).queueWithdrawals(shareAmount);

        console.log("Withdrawal queued successfully");

        vm.stopBroadcast();
    }
}
