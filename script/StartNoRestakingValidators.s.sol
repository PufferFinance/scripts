// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import {Script} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {console} from "forge-std/console.sol";

interface IInstitutionalVault {
    function startNonRestakingValidators(
        bytes[] calldata pubKeys,
        bytes[] calldata signatures,
        bytes32[] calldata depositDataRoots
    ) external;
}

// forge script script/StartRestakingValidators.s.sol:StartRestakingValidators --rpc-url=$HOLESKY_RPC_URL --account institutional-deployer-testnet -vvvv --sig "run(address,string)" 0x205A6BCF458a40E1a30a000166c793Ec54b0d9D5 1
// add --broadcast to broadcast the transaction
contract StartNoRestakingValidators is Script {
    using stdJson for string;

    // Expected file to have the format of test/validator-keys/no_restaking_validator_keys_holesky/deposit_data-1736424571.json
    // That is generated using the deposit-cli -> https://github.com/ethereum/staking-deposit-cli

    struct DepositData {
        ValidatorDepositData[] validatorDepositData;
    }

    // Struct needs to be ordered alphabetically, see foundry docs for more info
    struct ValidatorDepositData {
        uint256 amount;
        string deposit_cli_version;
        string deposit_data_root;
        string deposit_message_root;
        string fork_version;
        string network_name;
        string pubkey;
        string signature;
        string withdrawal_credentials;
    }

    function run(address payable institutionalVaultProxy, string calldata depositFileName) public {
        vm.startBroadcast();

        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/validator_deposit_data/0x01/", depositFileName, ".json");

        console.log("Path:", path);

        string memory fileContent = vm.readFile(path);
        bytes memory rawJson = vm.parseJson(fileContent);

        ValidatorDepositData[] memory depositData = abi.decode(rawJson, (ValidatorDepositData[]));

        bytes[] memory pubKeys = new bytes[](depositData.length);
        bytes[] memory signatures = new bytes[](depositData.length);
        bytes32[] memory depositDataRoots = new bytes32[](depositData.length);

        for (uint256 i = 0; i < depositData.length; i++) {
            pubKeys[i] = vm.parseBytes(depositData[i].pubkey);
            signatures[i] = vm.parseBytes(depositData[i].signature);
            depositDataRoots[i] = vm.parseBytes32(depositData[i].deposit_data_root);
        }

        IInstitutionalVault(institutionalVaultProxy).startNonRestakingValidators(pubKeys, signatures, depositDataRoots);

        vm.stopBroadcast();
    }
}
