// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

interface IEigenPodManager {
    function stake(bytes calldata pubKey, bytes calldata signature, bytes32 depositDataRoot) external payable;

    function createPod() external returns (address);
}
