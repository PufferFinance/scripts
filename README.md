# Puffer Institutional Vault — Operations Scripts

Foundry scripts for operating Puffer Institutional Vaults. Partners use these scripts to deposit ETH, activate validators, delegate to EigenLayer operators, manage withdrawals, and monitor vault state.

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) installed
- RPC URL (set `HOLESKY_RPC_URL` or `MAINNET_RPC_URL` env var)
- Funded account configured via `cast wallet` (e.g. `--account institutional-deployer-testnet`)

## Scripts

| Script | Purpose | Broadcast |
|--------|---------|-----------|
| `InitialAccessManagerSetup` | Configure AccessManager roles (one-time setup) | No (generates calldata) |
| `DepositETH` | Deposit ETH into the vault and receive shares | Yes |
| `StartRestakingValidators` | Activate restaking validators via EigenLayer | Yes |
| `StartNoRestakingValidators` | Activate non-restaking validators | Yes |
| `CustomExternalCallNonRestakingValidators` | Generate beacon deposit calldata for non-restaking validators | No (generates calldata) |
| `DelegateToOperator` | Delegate restaked ETH to an EigenLayer operator | Yes |
| `QueueWithdrawals` | Queue EigenLayer withdrawal (starts unbonding period) | Yes |
| `CompleteQueuedWithdrawals` | Complete queued withdrawals after unbonding delay | Yes |
| `WithdrawNonRestakedETH` | Pull exited non-restaked validator ETH back to vault | Yes |
| `SetValidatorsETH` | Update oracle accounting for validator ETH amounts | Yes |
| `VaultInfo` | Read-only vault state monitoring | No (view-only) |

## Operational Workflow

```
1. Setup          →  InitialAccessManagerSetup (configure roles)
2. Deposit        →  DepositETH (fund the vault with ETH)
3. Validators     →  StartRestakingValidators / StartNoRestakingValidators
4. Delegate       →  DelegateToOperator (delegate to EigenLayer operator)
5. Monitor        →  VaultInfo (check vault state)
6. Oracle         →  SetValidatorsETH (update accounting)
7. Withdraw       →  QueueWithdrawals → CompleteQueuedWithdrawals (restaking)
                     WithdrawNonRestakedETH (non-restaking)
```

## Usage

All scripts follow the same pattern. Add `--broadcast` to execute on-chain.

### Initial Access Manager Setup

Generates multicall calldata for configuring AccessManager roles. Update `roles-configuration.json` first.

```shell
forge script script/InitialAccessManagerSetup.s.sol:InitialAccessManagerSetup -vvvv
```

### Deposit ETH

```shell
forge script script/DepositETH.s.sol:DepositETH \
  --rpc-url=$HOLESKY_RPC_URL \
  --account institutional-deployer-testnet \
  -vvvv \
  --sig "run(address,address)" <vaultProxy> <receiver> \
  --value <amountInWei>
```

### Start Restaking Validators

Deposit data files go in `validator_deposit_data/restaking_validators/`. Generate them with [staking-deposit-cli](https://github.com/ethereum/staking-deposit-cli).

```shell
forge script script/StartRestakingValidators.s.sol:StartRestakingValidators \
  --rpc-url=$HOLESKY_RPC_URL \
  --account institutional-deployer-testnet \
  -vvvv \
  --sig "run(address,string)" <vaultProxy> <depositFileName>
```

### Start Non-Restaking Validators

Deposit data files go in `validator_deposit_data/0x02/`.

```shell
forge script script/StartNoRestakingValidators.s.sol:StartNoRestakingValidators \
  --rpc-url=$HOLESKY_RPC_URL \
  --account institutional-deployer-testnet \
  -vvvv \
  --sig "run(address,string)" <vaultProxy> <depositFileName>
```

### Delegate to EigenLayer Operator

After starting restaking validators, delegate to an operator.

```shell
forge script script/DelegateToOperator.s.sol:DelegateToOperator \
  --rpc-url=$HOLESKY_RPC_URL \
  --account institutional-deployer-testnet \
  -vvvv \
  --sig "run(address,address,address)" <vaultProxy> <operatorAddress> <delegationManagerAddress>
```

### Queue Withdrawals

Start the unbonding period for restaked ETH.

```shell
forge script script/QueueWithdrawals.s.sol:QueueWithdrawals \
  --rpc-url=$HOLESKY_RPC_URL \
  --account institutional-deployer-testnet \
  -vvvv \
  --sig "run(address,uint256)" <vaultProxy> <shareAmountInWei>
```

### Complete Queued Withdrawals

After the unbonding delay, complete the withdrawal. Provide a JSON file in `withdrawal_data/` with the withdrawal params (see `withdrawal_data/example.json`).

```shell
forge script script/CompleteQueuedWithdrawals.s.sol:CompleteQueuedWithdrawals \
  --rpc-url=$HOLESKY_RPC_URL \
  --account institutional-deployer-testnet \
  -vvvv \
  --sig "run(address,string)" <vaultProxy> <withdrawalFileName>
```

### Withdraw Non-Restaked ETH

After non-restaking validators exit, pull ETH from the withdrawal credentials contract back to the vault.

```shell
forge script script/WithdrawNonRestakedETH.s.sol:WithdrawNonRestakedETH \
  --rpc-url=$HOLESKY_RPC_URL \
  --account institutional-deployer-testnet \
  -vvvv \
  --sig "run(address)" <vaultProxy>
```

### Set Validators ETH (Oracle Update)

Update the tracked ETH amounts for accurate exchange rate accounting.

```shell
forge script script/SetValidatorsETH.s.sol:SetValidatorsETH \
  --rpc-url=$HOLESKY_RPC_URL \
  --account institutional-deployer-testnet \
  -vvvv \
  --sig "run(address,uint128,uint128)" <vaultProxy> <restakedETH> <nonRestakedETH>
```

### Vault Info (Read-Only)

```shell
forge script script/VaultInfo.s.sol:VaultInfo \
  --rpc-url=$HOLESKY_RPC_URL \
  -vvvv \
  --sig "run(address)" <vaultProxy>
```

## Configuration

### `roles-configuration.json`

Defines AccessManager role assignments:

```json
{
    "admin": "0x...",
    "customExternalCallers": ["0x...", "0x..."],
    "pufferOpsMultisig": "0x...",
    "vault": "0x...",
    "withdrawalManager": "0x..."
}
```

### Validator Deposit Data

Generated using [staking-deposit-cli](https://github.com/ethereum/staking-deposit-cli). Place files in:
- `validator_deposit_data/restaking_validators/` — for restaking validators
- `validator_deposit_data/0x02/` — for non-restaking validators

### Withdrawal Data

JSON files for `CompleteQueuedWithdrawals` go in `withdrawal_data/`. See `withdrawal_data/example.json` for the expected format:

```json
[
    {
        "delegatedTo": "0x...",
        "nonce": 0,
        "scaledShares": 1000000000000000000,
        "staker": "0x...",
        "startBlock": 3151116,
        "withdrawer": "0x..."
    }
]
```

## Deployed Addresses

### Holesky Testnet

| Contract | Address |
|----------|---------|
| InstitutionalVault Proxy | `0x205A6BCF458a40E1a30a000166c793Ec54b0d9D5` |
| EigenLayer DelegationManager | `0xA44151489861Fe9e3055d95adC98FbD462B948e7` |

### Mainnet

| Contract | Address |
|----------|---------|
| Beacon Deposit Contract | `0x00000000219ab540356cBB839Cbe05303d7705Fa` |
| EigenLayer DelegationManager | `0x39053D51B77DC0d36036Fc1fCc8Cb819df8Ef37A` |
