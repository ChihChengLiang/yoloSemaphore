include "../node_modules/circomlib/circuits/poseidon.circom";
include "../node_modules/circomlib/circuits/bitify.circom";
include "merkleTree.circom";


template Semaphore(levels) {

    signal input signalHash;
    signal input externalNullifier;

    signal private input identityNullifier;
    signal private input identityPathElements[levels];
    signal private input identityPathIndex[levels];

    signal output root;
    signal output nullifiersHash;

    component identityCommitment = Poseidon(2);
    identityCommitment.inputs[0] <== identityNullifier;
    identityCommitment.inputs[1] <== 0;

    component tree = MerkleTreeChecker(levels);
    component leafIndexNum = Bits2Num(levels);

    tree.leaf <== identityCommitment.out;
    tree.root <== root;
    for (var i = 0; i < levels; i++) {
        tree.pathElements[i] <== identityPathElements[i];
        tree.pathIndices[i] <== identityPathIndex[i];
        leafIndexNum.in[i] <== identityPathIndex[i];
    }

    component nullifiersHasher = Poseidon(3);
    nullifiersHasher.inputs[0] <== externalNullifier;
    nullifiersHasher.inputs[1] <== identityNullifier;
    nullifiersHasher.inputs[2] <== leafIndexNum.out;
    nullifiersHash <== nullifiersHasher.out;

    // Dummy square to prevent tampering signalHash
    signal signalSquare;
    signalSquare <== signalHash * signalHash;
}

component main = Semaphore(20);
