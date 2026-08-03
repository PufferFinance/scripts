// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import {FeeRecipient} from "../src/InstitutionalVaultStorage.sol";
import {IInstitutionalVault} from "../src/interface/IInstitutionalVault.sol";
import {IAccessManager} from "@openzeppelin-contracts/access/manager/IAccessManager.sol";
import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

/**
 * @notice Calls (or generates calldata for) InstitutionalVault.initializerV3, which switches on a new vault.
 *         On a fresh vault it deploys the non-restaking withdrawal credentials contract, records the starting
 *         total assets, and writes the fee recipients and both caps.
 *
 *         All values come from a JSON config file, so nothing is hardcoded and the same file can be reviewed
 *         and kept alongside the deployment record. Copy vault-init-config.example.json, fill it in, and pass
 *         the path. It defaults to vault-init-config.json.
 *
 * @dev initializerV3 runs at most once per vault, and the caller must hold the admin role on the vault's
 *      AccessManager.
 *
 *      It must be the first call made against a new vault. Until it runs, the reward allowance is 0, so once a
 *      report has recorded a balance above 1 ETH every later report showing a profit is rejected, and the fee
 *      list is empty, so rewards earned in the meantime are never charged a fee. `check` enforces that
 *      ordering against live chain state before anything is broadcast.
 *
 * Order of use:
 *
 *   1. Dry run every precondition. Read-only, broadcasts nothing. Run this first, and only continue if it
 *      prints ALL CHECKS PASSED:
 *        forge script script/InitializeV3.s.sol:InitializeV3 --rpc-url $RPC --sig "check(string)" <config.json>
 *
 *   2a. Wallet admin - broadcast directly:
 *        forge script script/InitializeV3.s.sol:InitializeV3 --rpc-url $RPC --account <admin> --broadcast \
 *            --sig "run(string)" <config.json>
 *
 *   2b. Multisig admin - print the calldata to propose, then execute it from the multisig. Re-run `check`
 *       just before executing, because signatures take time to collect:
 *        forge script script/InitializeV3.s.sol:InitializeV3 --rpc-url $RPC \
 *            --sig "getCalldata(string)" <config.json>
 *
 *   3. Confirm the result on chain before funding the vault or starting validators:
 *        forge script script/InitializeV3.s.sol:InitializeV3 --rpc-url $RPC --sig "verify(string)" <config.json>
 */
contract InitializeV3 is Script {
    /// @dev The version string the vault implementation behind the proxy is expected to report.
    string internal constant EXPECTED_VAULT_VERSION = "3.0.0";
    /// @dev The vault's own hard ceiling on the sum of recipient bps.
    uint16 internal constant HARD_FEE_BPS_CAP = 9_900;
    uint16 internal constant BPS_DENOMINATOR = 10_000;

    string internal constant DEFAULT_CONFIG_PATH = "vault-init-config.json";

    struct Config {
        address vault;
        address admin;
        uint16 maxAprBps;
        uint16 maxTotalFeeBps;
        FeeRecipient[] recipients;
    }

    // ---------------------------------------------------------------- entry points

    /// @notice Run every precondition against live chain state. Read-only: broadcasts nothing.
    function check(string memory configPath) public view {
        Config memory cfg = _load(configPath);
        _print(cfg);
        _checkConfig(cfg);
        _checkChainState(cfg);
        console.log("");
        console.log("ALL CHECKS PASSED. Safe to broadcast initializerV3.");
    }

    function check() public view {
        check(DEFAULT_CONFIG_PATH);
    }

    /// @notice Broadcast initializerV3 from the caller, who must be the admin named in the config.
    function run(string memory configPath) public {
        Config memory cfg = _load(configPath);
        _print(cfg);
        _checkConfig(cfg);
        _checkChainState(cfg);

        (, address sender,) = vm.readCallers();
        require(sender == cfg.admin, "broadcasting address is not the admin in the config");

        vm.startBroadcast();
        IInstitutionalVault(cfg.vault).initializerV3(cfg.recipients, cfg.maxAprBps, cfg.maxTotalFeeBps);
        vm.stopBroadcast();

        console.log("");
        console.log("initializerV3 broadcast. Now run `verify` against the same config.");
    }

    function run() public {
        run(DEFAULT_CONFIG_PATH);
    }

    /// @notice Print the raw calldata for the admin (for example a multisig) to execute on the vault.
    function getCalldata(string memory configPath) public view {
        Config memory cfg = _load(configPath);
        _print(cfg);
        _checkConfig(cfg);
        _checkChainState(cfg);

        console.log("");
        console.log("Execute this from the admin, as a single call:");
        console.log("  to:   ", cfg.vault);
        console.log("  from: ", cfg.admin);
        console.log("  value: 0");
        console.log("  data:");
        console.logBytes(
            abi.encodeCall(IInstitutionalVault.initializerV3, (cfg.recipients, cfg.maxAprBps, cfg.maxTotalFeeBps))
        );
    }

    function getCalldata() public view {
        getCalldata(DEFAULT_CONFIG_PATH);
    }

    /// @notice Confirm on chain that initializerV3 landed and wrote what the config asked for.
    function verify(string memory configPath) public view {
        Config memory cfg = _load(configPath);
        IInstitutionalVault vault = IInstitutionalVault(cfg.vault);

        console.log("Verifying vault:", cfg.vault);

        address wc = vault.getNoRestakingWithdrawalCredentials();
        require(wc != address(0), "withdrawal credentials not deployed: initializerV3 did not run");
        console.log("  withdrawal credentials:", wc);

        address pod = vault.getEigenPod();
        require(pod != address(0), "EigenPod not set");
        console.log("  eigenPod:              ", pod);

        require(vault.getMaxAprBps() == cfg.maxAprBps, "maxAprBps mismatch");
        require(vault.getMaxTotalFeeBps() == cfg.maxTotalFeeBps, "maxTotalFeeBps mismatch");
        console.log("  maxAprBps:             ", vault.getMaxAprBps());
        console.log("  maxTotalFeeBps:        ", vault.getMaxTotalFeeBps());

        FeeRecipient[] memory onChain = vault.getFeeRecipients();
        require(onChain.length == cfg.recipients.length, "fee recipient count mismatch");
        for (uint256 i; i < onChain.length; ++i) {
            require(onChain[i].recipient == cfg.recipients[i].recipient, "fee recipient address mismatch");
            require(onChain[i].bps == cfg.recipients[i].bps, "fee recipient bps mismatch");
            console.log("  recipient:", onChain[i].name, onChain[i].recipient, onChain[i].bps);
        }

        console.log("  lastTotalAssets:       ", vault.getLastTotalAssets());
        console.log("  netLPFlow:             ", vault.getNetLPFlow());
        console.log("  lastReportTimestamp:   ", vault.getLastReportTimestamp());

        console.log("");
        console.log("VERIFIED. The vault matches the config and is ready to be funded.");
    }

    function verify() public view {
        verify(DEFAULT_CONFIG_PATH);
    }

    // ---------------------------------------------------------------- config

    /**
     * @dev Reads the config with explicit typed key lookups rather than decoding straight into a struct.
     *      `vm.parseJson` orders struct fields alphabetically, which does not match FeeRecipient's declared
     *      order (recipient, bps, name), so a struct decode would compile but silently misread the file.
     */
    function _load(string memory configPath) internal view returns (Config memory cfg) {
        string memory json = vm.readFile(configPath);

        cfg.vault = vm.parseJsonAddress(json, ".vault");
        cfg.admin = vm.parseJsonAddress(json, ".admin");
        cfg.maxAprBps = _toBps(vm.parseJsonUint(json, ".maxAprBps"), "maxAprBps");
        cfg.maxTotalFeeBps = _toBps(vm.parseJsonUint(json, ".maxTotalFeeBps"), "maxTotalFeeBps");

        uint256 count;
        while (vm.keyExistsJson(json, _recipientPath(count))) {
            ++count;
        }

        cfg.recipients = new FeeRecipient[](count);
        for (uint256 i; i < count; ++i) {
            string memory p = _recipientPath(i);
            cfg.recipients[i] = FeeRecipient({
                recipient: vm.parseJsonAddress(json, string.concat(p, ".recipient")),
                bps: _toBps(vm.parseJsonUint(json, string.concat(p, ".bps")), "recipient bps"),
                name: vm.parseJsonString(json, string.concat(p, ".name"))
            });
        }
    }

    function _recipientPath(uint256 i) internal pure returns (string memory) {
        return string.concat(".feeRecipients[", vm.toString(i), "]");
    }

    function _toBps(uint256 value, string memory label) internal pure returns (uint16) {
        require(value <= type(uint16).max, string.concat(label, " does not fit in uint16"));
        return uint16(value);
    }

    // ---------------------------------------------------------------- checks

    /// @dev Mirrors every requirement initializerV3 enforces, so a bad config fails locally, not on chain.
    function _checkConfig(Config memory cfg) internal pure {
        require(cfg.vault != address(0), "vault is the zero address");
        require(cfg.admin != address(0), "admin is the zero address");

        require(cfg.maxAprBps != 0 && cfg.maxAprBps <= BPS_DENOMINATOR, "maxAprBps must be in (0, 10000]");
        require(
            cfg.maxTotalFeeBps != 0 && cfg.maxTotalFeeBps <= HARD_FEE_BPS_CAP, "maxTotalFeeBps must be in (0, 9900]"
        );

        uint256 sumBps;
        for (uint256 i; i < cfg.recipients.length; ++i) {
            FeeRecipient memory r = cfg.recipients[i];
            require(r.recipient != address(0), "fee recipient is the zero address");
            require(r.recipient != cfg.vault, "fee recipient is the vault itself");
            require(r.bps != 0, "fee recipient bps is zero");

            // initializerV3 does not reject duplicates: they would silently split one party's fee across two
            // entries, which is almost always a copy-paste mistake in the config.
            for (uint256 j; j < i; ++j) {
                require(cfg.recipients[j].recipient != r.recipient, "duplicate fee recipient");
            }

            sumBps += r.bps;
        }
        require(sumBps <= cfg.maxTotalFeeBps, "sum of recipient bps exceeds maxTotalFeeBps");
    }

    /**
     * @dev Confirms the vault is the one we mean, has not been touched, and that the admin can make the call.
     *      Because initializerV3 is a separate transaction from vault creation, the ordering rule it protects
     *      has to be checked against live state rather than guaranteed by construction.
     */
    function _checkChainState(Config memory cfg) internal view {
        require(cfg.vault.code.length != 0, "no contract at the vault address");

        IInstitutionalVault vault = IInstitutionalVault(cfg.vault);

        require(
            keccak256(bytes(vault.VERSION())) == keccak256(bytes(EXPECTED_VAULT_VERSION)),
            "vault implementation is not v3: check the proxy points at the right implementation"
        );

        require(
            vault.getNoRestakingWithdrawalCredentials() == address(0),
            "already initialized: withdrawal credentials are already deployed"
        );
        require(vault.getMaxAprBps() == 0, "already initialized: maxAprBps is already set");

        // Anything already in the vault is recorded as the starting balance and is never charged a fee, and
        // any balance at all means the vault was used before being switched on.
        require(vault.totalSupply() == 0, "vault already has shares: initializerV3 is no longer the first call");
        require(
            vault.totalAssets() == 0,
            "vault already holds assets: initializerV3 must run before the vault is funded or donated to"
        );
        require(vault.getRestakedValidatorETH() == 0, "restaked validator ETH is already non-zero");
        require(vault.getNonRestakedValidatorETH() == 0, "non-restaked validator ETH is already non-zero");

        require(vault.getEigenPod() != address(0), "EigenPod not set: the vault was never created properly");

        // initializerV3 is restricted, and on a fresh AccessManager its selector is unassigned, so it falls
        // through to the admin role. Checking canCall catches a wrong admin before a transaction is sent.
        address authority = vault.authority();
        require(authority != address(0), "vault has no authority set");
        (bool allowed,) =
            IAccessManager(authority).canCall(cfg.admin, cfg.vault, IInstitutionalVault.initializerV3.selector);
        require(allowed, "admin cannot call initializerV3: it does not hold the admin role on the AccessManager");

        console.log("  accessManager:         ", authority);
        console.log("  admin can initialize:  ", allowed);
    }

    // ---------------------------------------------------------------- output

    function _print(Config memory cfg) internal pure {
        console.log("Vault:          ", cfg.vault);
        console.log("Admin:          ", cfg.admin);
        console.log("maxAprBps:      ", cfg.maxAprBps);
        console.log("maxTotalFeeBps: ", cfg.maxTotalFeeBps);
        console.log("Fee recipients: ", cfg.recipients.length);

        uint256 sumBps;
        for (uint256 i; i < cfg.recipients.length; ++i) {
            console.log("  ", cfg.recipients[i].name, cfg.recipients[i].recipient, cfg.recipients[i].bps);
            sumBps += cfg.recipients[i].bps;
        }
        console.log("sum(bps):       ", sumBps);
    }
}
