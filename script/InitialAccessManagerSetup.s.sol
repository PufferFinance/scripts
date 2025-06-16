// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import {Script} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {console} from "forge-std/console.sol";
import {AccessManager} from "@openzeppelin-contracts/access/manager/AccessManager.sol";
import {Multicall} from "@openzeppelin-contracts/utils/Multicall.sol";
import {IInstitutionalVault} from "../src/interface/IInstitutionalVault.sol";

// forge script script/InitialAccessManagerSetup.s.sol:InitialAccessManagerSetup -vvvv
contract InitialAccessManagerSetup is Script {
    using stdJson for string;

    uint64 public constant ADMIN_ROLE_ID = type(uint64).min; // 0
    uint64 public constant DEPOSITOR_ROLE_ID = 1;
    uint64 public constant WITHDRAWER_ROLE_ID = 2;
    uint64 public constant CUSTOM_EXTERNAL_CALLER_ROLE_ID = 3;
    uint64 public constant WITHDRAWAL_MANAGER_ROLE_ID = 4;
    uint64 public constant ORACLE_ROLE_ID = 5;

    struct RolesConfiguration {
        address admin;
        address[] customExternalCallers;
        address pufferOpsMultisig;
        address vault;
        address withdrawalManager;
    }

    function run() public view {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/roles-configuration.json");

        console.log("Path:", path);

        string memory fileContent = vm.readFile(path);
        bytes memory rawJson = vm.parseJson(fileContent);

        RolesConfiguration memory accessManagerConfiguration = abi.decode(rawJson, (RolesConfiguration));

        console.log("Access manager institution admin:", address(accessManagerConfiguration.admin));

        // Calculate total number of calldatas needed
        uint256 totalCalldatas = 14 + accessManagerConfiguration.customExternalCallers.length + 1; // +1 for revoke role
        bytes[] memory calldatas = new bytes[](totalCalldatas);
        uint256 calldataIndex = 0;

        calldatas[calldataIndex++] = abi.encodeCall(AccessManager.labelRole, (DEPOSITOR_ROLE_ID, "Depositor"));
        calldatas[calldataIndex++] = abi.encodeCall(AccessManager.labelRole, (WITHDRAWER_ROLE_ID, "Withdrawer"));
        calldatas[calldataIndex++] =
            abi.encodeCall(AccessManager.labelRole, (CUSTOM_EXTERNAL_CALLER_ROLE_ID, "Custom External Caller"));
        calldatas[calldataIndex++] =
            abi.encodeCall(AccessManager.labelRole, (WITHDRAWAL_MANAGER_ROLE_ID, "Withdrawal Manager"));
        calldatas[calldataIndex++] = abi.encodeCall(AccessManager.labelRole, (ORACLE_ROLE_ID, "Oracle"));
        // Grant the admin role to the institution admin, without any delay
        calldatas[calldataIndex++] =
            abi.encodeCall(AccessManager.grantRole, (ADMIN_ROLE_ID, accessManagerConfiguration.admin, 0));

        bytes4[] memory depositorSelectors = new bytes4[](3);
        depositorSelectors[0] = IInstitutionalVault.depositETH.selector;
        depositorSelectors[1] = IInstitutionalVault.mint.selector;
        depositorSelectors[2] = IInstitutionalVault.deposit.selector;

        calldatas[calldataIndex++] = abi.encodeCall(
            AccessManager.setTargetFunctionRole,
            (accessManagerConfiguration.vault, depositorSelectors, DEPOSITOR_ROLE_ID)
        );

        bytes4[] memory withdrawerSelectors = new bytes4[](2);
        withdrawerSelectors[0] = IInstitutionalVault.withdraw.selector;
        withdrawerSelectors[1] = IInstitutionalVault.redeem.selector;

        calldatas[calldataIndex++] = abi.encodeCall(
            AccessManager.setTargetFunctionRole,
            (accessManagerConfiguration.vault, withdrawerSelectors, WITHDRAWER_ROLE_ID)
        );

        bytes4[] memory withdrawalManagerSelectors = new bytes4[](2);
        withdrawalManagerSelectors[0] = IInstitutionalVault.queueWithdrawals.selector;
        withdrawalManagerSelectors[1] = IInstitutionalVault.completeQueuedWithdrawals.selector;

        calldatas[calldataIndex++] = abi.encodeCall(
            AccessManager.grantRole, (WITHDRAWAL_MANAGER_ROLE_ID, accessManagerConfiguration.withdrawalManager, 0)
        );

        calldatas[calldataIndex++] =
            abi.encodeCall(AccessManager.grantRole, (ORACLE_ROLE_ID, accessManagerConfiguration.admin, 0));

        calldatas[calldataIndex++] = abi.encodeCall(
            AccessManager.setTargetFunctionRole,
            (accessManagerConfiguration.vault, withdrawalManagerSelectors, WITHDRAWAL_MANAGER_ROLE_ID)
        );

        calldatas[calldataIndex++] =
            abi.encodeCall(AccessManager.grantRole, (DEPOSITOR_ROLE_ID, accessManagerConfiguration.admin, 0));

        calldatas[calldataIndex++] =
            abi.encodeCall(AccessManager.grantRole, (WITHDRAWER_ROLE_ID, accessManagerConfiguration.admin, 0));

        bytes4[] memory customExternalCallerSelectors = new bytes4[](1);
        customExternalCallerSelectors[0] = IInstitutionalVault.customExternalCall.selector;

        calldatas[calldataIndex++] = abi.encodeCall(
            AccessManager.setTargetFunctionRole,
            (accessManagerConfiguration.vault, customExternalCallerSelectors, CUSTOM_EXTERNAL_CALLER_ROLE_ID)
        );

        // Grant the custom external caller role to the custom external callers
        for (uint256 i = 0; i < accessManagerConfiguration.customExternalCallers.length; i++) {
            calldatas[calldataIndex++] = abi.encodeCall(
                AccessManager.grantRole,
                (CUSTOM_EXTERNAL_CALLER_ROLE_ID, accessManagerConfiguration.customExternalCallers[i], 0)
            );
        }

        // Revoke the admin role from the puffer ops multisig - Clean up
        calldatas[calldataIndex++] =
            abi.encodeCall(AccessManager.revokeRole, (ADMIN_ROLE_ID, accessManagerConfiguration.pufferOpsMultisig));

        bytes memory encodedMulticall = abi.encodeCall(Multicall.multicall, (calldatas));

        console.log("Total calldatas:", totalCalldatas, "calldataIndex:", calldataIndex);
        console.log("Encoded multicall:");
        console.logBytes(encodedMulticall);
    }
}
