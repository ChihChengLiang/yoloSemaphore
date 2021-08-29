// SPDX-License-Identifier: GPL-3.0-only

pragma solidity ^0.7.3;

import { Semaphore } from "./Semaphore.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * People are allowed to cast 2 votes privately
 */
contract Voting is Semaphore, Ownable {
    struct Proposal {
        bytes32 name;
        uint256 voteCount;
    }

    Proposal[] public proposals;

    constructor(address hasher, bytes32[] memory proposalNames)
        Semaphore(hasher)
    {
        for (uint256 i = 0; i < proposalNames.length; i++) {
            proposals.push(Proposal({ name: proposalNames[i], voteCount: 0 }));
        }
        // First vote
        addExternalNullifier(0);
        // Second vote
        addExternalNullifier(1);
    }

    function addVoter(bytes32 identityCommitment) external onlyOwner {
        insertIdentity(identityCommitment);
    }

    function vote(
        uint256[2] calldata proofA,
        uint256[2][2] calldata proofB,
        uint256[2] calldata proofC,
        bytes32 root,
        uint256 nullifiersHash,
        uint256 externalNullifier,
        uint256 proposalID
    ) external {
        require(proposalID < proposals.length, "Voting: Invalid proposalID");
        bytes memory signal = abi.encodePacked(proposalID);
        require(
            broadcastSignal(
                proofA,
                proofB,
                proofC,
                root,
                nullifiersHash,
                externalNullifier,
                signal
            ),
            "Voting: Failing to broadcast signal"
        );

        proposals[proposalID].voteCount++;
    }
}
