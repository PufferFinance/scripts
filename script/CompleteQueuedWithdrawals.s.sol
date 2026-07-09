// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import {Script} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {console} from "forge-std/console.sol";
import {IDelegationManagerTypes} from "../src/interface/Eigenlayer-Slashing/IDelegationManager.sol";
import {IStrategy} from "../src/interface/Eigenlayer-Slashing/IStrategy.sol";
import {IInstitutionalVault} from "../src/interface/IInstitutionalVault.sol";

// forge script script/CompleteQueuedWithdrawals.s.sol:CompleteQueuedWithdrawals --rpc-url=$HOLESKY_RPC_URL --account institutional-deployer-testnet -vvvv --sig "run(address,string)" <institutionalVaultProxy> <withdrawalFileName>
// add --broadcast to broadcast the transaction
contract CompleteQueuedWithdrawals is Script {
    using stdJson for string;

    // Struct needs to be ordered alphabetically, see foundry docs for more info
    struct WithdrawalData {
        address delegatedTo;
        uint256 nonce;
        uint256 scaledShares;
        address staker;
        uint32 startBlock;
        address withdrawer;
    }

    function run(address payable institutionalVaultProxy, string calldata withdrawalFileName) public {
        vm.startBroadcast();

        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/withdrawal_data/", withdrawalFileName, ".json");

        console.log("Path:", path);

        string memory fileContent = vm.readFile(path);
        bytes memory rawJson = vm.parseJson(fileContent);

        WithdrawalData[] memory withdrawalData = abi.decode(rawJson, (WithdrawalData[]));

        IDelegationManagerTypes.Withdrawal[] memory withdrawals =
            new IDelegationManagerTypes.Withdrawal[](withdrawalData.length);
        bool[] memory receiveAsTokens = new bool[](withdrawalData.length);

        for (uint256 i = 0; i < withdrawalData.length; i++) {
            IStrategy[] memory strategies = new IStrategy[](1);
            strategies[0] = IStrategy(0xbeaC0eeEeeeeEEeEeEEEEeeEEeEeeeEeeEEBEaC0);

            uint256[] memory scaledShares = new uint256[](1);
            scaledShares[0] = withdrawalData[i].scaledShares;

            withdrawals[i] = IDelegationManagerTypes.Withdrawal({
                staker: withdrawalData[i].staker,
                delegatedTo: withdrawalData[i].delegatedTo,
                withdrawer: withdrawalData[i].withdrawer,
                nonce: withdrawalData[i].nonce,
                startBlock: withdrawalData[i].startBlock,
                strategies: strategies,
                scaledShares: scaledShares
            });

            receiveAsTokens[i] = true;

            console.log("Withdrawal", i);
            console.log("  staker:", withdrawalData[i].staker);
            console.log("  delegatedTo:", withdrawalData[i].delegatedTo);
            console.log("  nonce:", withdrawalData[i].nonce);
            console.log("  startBlock:", uint256(withdrawalData[i].startBlock));
            console.log("  scaledShares:", withdrawalData[i].scaledShares);
        }

        IInstitutionalVault(institutionalVaultProxy).completeQueuedWithdrawals(withdrawals, receiveAsTokens);

        console.log("Queued withdrawals completed successfully");

        vm.stopBroadcast();
    }
}
