// SPDX-License-Identifier: GPL-3.0-only

pragma solidity ^0.7.3;

import { Verifier } from "./Verifier.sol";
import { MerkleTreeWithHistory } from "./MerkleTreeWithHistory.sol";

contract Semaphore is Verifier, MerkleTreeWithHistory {
    mapping(uint256 => bool) public externalNullifierMapping;

    uint256 public nextExternalNullifier = 0;

    mapping(uint256 => bool) public nullifierHashHistory;

    event IdentityAdd(bytes32 indexed commitment, uint32 leafIndex);
    event ExternalNullifierAdd(uint256 indexed externalNullifier);

    // treeHeight in the contract needs to match the treeHeight in the circuit
    uint32 public constant treeHeight = 20;

    constructor(address hasher) MerkleTreeWithHistory(treeHeight, hasher) {}

    function insertIdentity(bytes32 identityCommitment)
        internal
        returns (uint32)
    {
        uint32 leafIndex = _insert(identityCommitment);
        emit IdentityAdd(identityCommitment, leafIndex);
    }

    function addExternalNullifier(uint256 externalNullifier) internal {
        require(
            externalNullifier < FIELD_SIZE,
            "Semaphore: external nullifier should be lt the field sizee"
        );
        require(
            externalNullifierMapping[externalNullifier] == false,
            "Semaphore: external nullifier already exists"
        );
        externalNullifierMapping[externalNullifier] = true;
        emit ExternalNullifierAdd(externalNullifier);
        nextExternalNullifier++;
    }

    function broadcastSignal(
        uint256[2] memory proofA,
        uint256[2][2] memory proofB,
        uint256[2] memory proofC,
        bytes32 root,
        uint256 nullifiersHash,
        uint256 externalNullifier,
        bytes memory signal
    ) internal returns (bool success) {
        require(
            nullifierHashHistory[nullifiersHash] == false,
            "Semaphore: nullifier already seen"
        );
        require(
            externalNullifierMapping[externalNullifier] == true,
            "Semaphore: external nullifier not found"
        );
        require(isKnownRoot(root), "Semaphore: root not seen");
        uint256[4] memory publicSignals = [
            nullifiersHash,
            externalNullifier,
            uint256(root),
            uint256(keccak256(signal))
        ];
        require(
            verifyProof(proofA, proofB, proofC, publicSignals),
            "Semaphore: invalid proof"
        );

        // Store the nullifiers hash to prevent double-signalling
        nullifierHashHistory[nullifiersHash] = true;
        return true;
    }
}
