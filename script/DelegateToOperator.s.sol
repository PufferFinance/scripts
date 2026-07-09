// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {IDelegationManager} from "../src/interface/Eigenlayer-Slashing/IDelegationManager.sol";
import {ISignatureUtils} from "../src/interface/Eigenlayer-Slashing/ISignatureUtils.sol";
import {IInstitutionalVault} from "../src/interface/IInstitutionalVault.sol";

// forge script script/DelegateToOperator.s.sol:DelegateToOperator --rpc-url=$HOLESKY_RPC_URL --account institutional-deployer-testnet -vvvv --sig "run(address,address,address)" <institutionalVaultProxy> <operatorAddress> <delegationManagerAddress>
// add --broadcast to broadcast the transaction
contract DelegateToOperator is Script {
    function run(address payable institutionalVaultProxy, address operatorAddress, address delegationManagerAddress)
        public
    {
        vm.startBroadcast();

        // Encode the delegateTo call with an empty approver signature and zero salt
        ISignatureUtils.SignatureWithExpiry memory emptySignature;
        bytes memory innerCalldata =
            abi.encodeCall(IDelegationManager.delegateTo, (operatorAddress, emptySignature, bytes32(0)));

        console.log("Delegating to operator:", operatorAddress);
        console.log("Via delegation manager:", delegationManagerAddress);

        // Wrap it in a customExternalCall to the delegation manager
        IInstitutionalVault(institutionalVaultProxy).customExternalCall(delegationManagerAddress, innerCalldata, 0);

        console.log("Delegation successful");

        vm.stopBroadcast();
    }
}
