// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {IInstitutionalVault} from "../src/interface/IInstitutionalVault.sol";

// forge script script/DepositETH.s.sol:DepositETH --rpc-url=$HOLESKY_RPC_URL --account institutional-deployer-testnet -vvvv --sig "run(address,address)" <institutionalVaultProxy> <receiver> --value <amountInWei>
// add --broadcast to broadcast the transaction
contract DepositETH is Script {
    function run(address payable institutionalVaultProxy, address receiver) public {
        vm.startBroadcast();

        uint256 amount = address(this).balance;
        console.log("Depositing ETH into vault:", institutionalVaultProxy);
        console.log("  receiver:", receiver);
        console.log("  amount (wei):", amount);

        uint256 shares = IInstitutionalVault(institutionalVaultProxy).depositETH{value: amount}(receiver);

        console.log("Deposit successful, shares minted:", shares);

        vm.stopBroadcast();
    }
}
