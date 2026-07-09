// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {IInstitutionalVault} from "../src/interface/IInstitutionalVault.sol";

// forge script script/SetValidatorsETH.s.sol:SetValidatorsETH --rpc-url=$HOLESKY_RPC_URL --account institutional-deployer-testnet -vvvv --sig "run(address,uint128,uint128)" <institutionalVaultProxy> <restakedETH> <nonRestakedETH>
// add --broadcast to broadcast the transaction
contract SetValidatorsETH is Script {
    function run(address payable institutionalVaultProxy, uint128 restakedETH, uint128 nonRestakedETH) public {
        vm.startBroadcast();

        console.log("Setting validators ETH for vault:", institutionalVaultProxy);
        console.log("  restakedValidatorsETH:", uint256(restakedETH));
        console.log("  nonRestakedValidatorsETH:", uint256(nonRestakedETH));

        IInstitutionalVault(institutionalVaultProxy).setValidatorsETH(restakedETH, nonRestakedETH);

        console.log("Validators ETH updated successfully");

        vm.stopBroadcast();
    }
}
