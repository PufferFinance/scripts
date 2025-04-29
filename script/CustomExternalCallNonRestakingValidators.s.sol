// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import {Script} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {console} from "forge-std/console.sol";

interface IInstitutionalVault {
    function customExternalCall(address target, bytes calldata data, uint256 amount) external payable;
}

interface IBeaconDepositContract {
    function deposit(
        bytes calldata pubkey,
        bytes calldata withdrawal_credentials,
        bytes calldata signature,
        bytes32 deposit_data_root
    ) external payable;
}

// forge script script/CustomExternalCallNonRestakingValidators.s.sol:CustomExternalCallNonRestakingValidators --rpc-url=$HOLESKY_RPC_URL --account institutional-deployer-testnet -vvvv --sig "run(address,string)" 0x205A6BCF458a40E1a30a000166c793Ec54b0d9D5 example
// add --broadcast to broadcast the transaction
contract CustomExternalCallNonRestakingValidators is Script {
    using stdJson for string;

    // That is generated using the deposit-cli -> https://deposit-cli.ethstaker.cc/landing.html

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

    bytes pubKey;
    bytes withdrawalCredentials;
    bytes signature;
    bytes32 depositDataRoot;
    uint256 amount;

    function run(address payable institutionalVaultProxy, string calldata depositFileName) public {
        vm.startBroadcast();

        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/validator_deposit_data/0x02/", depositFileName, ".json");

        console.log("Path:", path);

        string memory fileContent = vm.readFile(path);
        bytes memory rawJson = vm.parseJson(fileContent);

        ValidatorDepositData[] memory depositData = abi.decode(rawJson, (ValidatorDepositData[]));

        for (uint256 i = 0; i < depositData.length; i++) {
            pubKey = vm.parseBytes(depositData[i].pubkey);
            withdrawalCredentials = vm.parseBytes(depositData[i].withdrawal_credentials);
            signature = vm.parseBytes(depositData[i].signature);
            depositDataRoot = vm.parseBytes32(depositData[i].deposit_data_root);
            amount = depositData[i].amount * 10 ** 9; // The deposit data amount is in Gwei, we need to convert it to Wei
            bytes memory data = abi.encodeCall(
                IBeaconDepositContract.deposit, (pubKey, withdrawalCredentials, signature, depositDataRoot)
            );

            // TODO: Custom external call directly to the beacon deposit contract
            IInstitutionalVault(institutionalVaultProxy).customExternalCall(
                0x00000000219ab540356cBB839Cbe05303d7705Fa, data, amount
            );
        }

        vm.stopBroadcast();
    }
}
