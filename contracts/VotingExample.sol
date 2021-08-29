// SPDX-License-Identifier: GPL-3.0-only

pragma solidity ^0.7.3;

import { Semaphore } from "./Semaphore.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract Voting is Semaphore, Ownable {
    constructor(address _hasher) Semaphore(32, _hasher) {}

    function addCandidates(uint256 candidates) external onlyOwner {
        addExternalNullifier(candidates);
    }

    function addVoters(bytes32 identityCommitment) external onlyOwner {
        insertIdentity(identityCommitment);
    }

    function vote(
        uint256[2] calldata proofA,
        uint256[2][2] calldata proofB,
        uint256[2] calldata proofC,
        bytes32 root,
        uint256 nullifiersHash,
        uint232 externalNullifier,
        bytes calldata signal
    ) external {
        broadcastSignal(
            proofA,
            proofB,
            proofC,
            root,
            nullifiersHash,
            externalNullifier,
            signal
        );
    }
}
