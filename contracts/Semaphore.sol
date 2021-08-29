// SPDX-License-Identifier: GPL-3.0-only

pragma solidity ^0.7.3;

import { Verifier } from "./Verifier.sol";
import { MerkleTreeWithHistory } from "./MerkleTreeWithHistory.sol";

contract Semaphore is Verifier, MerkleTreeWithHistory {
    mapping(uint256 => bool) public externalNullifierMapping;

    uint256 public nextExternalNullifier = 0;

    mapping(uint256 => bool) public nullifierHashHistory;

    event ExternalNullifierAdd(uint256 indexed externalNullifier);

    constructor(uint32 _treeLevels, address _hasher)
        MerkleTreeWithHistory(_treeLevels, _hasher)
    {}

    function insertIdentity(bytes32 identityCommitment)
        internal
        returns (uint32)
    {
        return _insert(identityCommitment);
    }

    function addExternalNullifier(uint256 externalNullifier) internal {
        uint256 en = externalNullifier % FIELD_SIZE;
        require(
            externalNullifierMapping[en] == false,
            "Semaphore: external nullifier already exists"
        );
        externalNullifierMapping[en] = true;
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
    ) internal {
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
            uint256(root),
            nullifiersHash,
            uint256(keccak256(signal)),
            externalNullifier
        ];
        require(
            verifyProof(proofA, proofB, proofC, publicSignals),
            "Semaphore: invalid proof"
        );

        // Store the nullifiers hash to prevent double-signalling
        nullifierHashHistory[nullifiersHash] = true;
    }
}
