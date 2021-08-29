import { assert } from "chai";
import { Voting__factory, Voting } from "../types/";

import { ethers } from "hardhat";
import { ContractFactory, BigNumber, BigNumberish, BytesLike } from "ethers";
// @ts-ignore
import { createCode, generateABI } from "circomlib/src/poseidon_gencontract";
// @ts-ignore
import poseidon from "circomlib/src/poseidon";
import { MerkleTree, Hasher } from "../src/merkleTree";
// @ts-ignore
import { groth16 } from "snarkjs";
import path from "path";
import { keccak256 } from "@ethersproject/keccak256";
import { solidityKeccak256 } from "ethers/lib/utils";

const HEIGHT = 20;

function poseidonHash(inputs: BigNumberish[]): string {
    const hash = poseidon(inputs.map((x) => BigNumber.from(x).toBigInt()));
    const bytes32 = ethers.utils.hexZeroPad(
        BigNumber.from(hash).toHexString(),
        32
    );
    return bytes32;
}

class PoseidonHasher implements Hasher {
    hash(left: string, right: string) {
        return poseidonHash([left, right]);
    }
}

class Identity {
    private constructor(
        public readonly nullifier: Uint8Array,
        public leafIndex?: number
    ) {}
    static new() {
        const nullifier = ethers.utils.randomBytes(15);
        return new this(nullifier);
    }
    get commitment() {
        return poseidonHash([this.nullifier, 0]);
    }

    nullifierHash(externalNullifier: BigNumberish) {
        if (!this.leafIndex && this.leafIndex !== 0)
            throw Error("leafIndex is unset yet");
        return poseidonHash([
            this.nullifier,
            externalNullifier,
            this.leafIndex,
        ]);
    }
}

function getPoseidonFactory(nInputs: number) {
    const bytecode = createCode(nInputs);
    const abiJson = generateABI(nInputs);
    const abi = new ethers.utils.Interface(abiJson);
    return new ContractFactory(abi, bytecode);
}

interface Witness {
    // Public
    root: BytesLike;
    signalHash: BytesLike;
    nullifiersHash: BigNumberish;
    externalNullifier: BigNumberish;
    // Private
    identityNullifier: BigNumberish;
    identityPathElements: BigNumberish[];
    identityPathIndex: BigNumberish[];
}

async function prove(witness: Witness) {
    const wasmPath = path.join(__dirname, "../build/semaphore.wasm");
    const zkeyPath = path.join(__dirname, "../build/circuit_final.zkey");

    const { proof } = await groth16.fullProve(witness, wasmPath, zkeyPath);

    const a: [BigNumberish, BigNumberish] = [proof.pi_a[0], proof.pi_a[1]];
    const b: [[BigNumberish, BigNumberish], [BigNumberish, BigNumberish]] = [
        [proof.pi_b[0][1], proof.pi_b[0][0]],
        [proof.pi_b[1][1], proof.pi_b[1][0]],
    ];
    const c: [BigNumberish, BigNumberish] = [proof.pi_c[0], proof.pi_c[1]];
    return { a, b, c };
}

describe("Voting Example", function () {
    let voting: Voting;
    beforeEach(async function () {
        const [signer] = await ethers.getSigners();
        const poseidon = await getPoseidonFactory(2).connect(signer).deploy();
        voting = await new Voting__factory(signer).deploy(poseidon.address, [
            ethers.utils.formatBytes32String("eat fruit for lunch"),
            ethers.utils.formatBytes32String("eat vegetable for lunch"),
        ]);
    });
    it("full user flow", async function () {
        const [coordinatorSigner, relayerSigner] = await ethers.getSigners();
        const identity = Identity.new();
        // coordinator add voters
        const tx = await voting
            .connect(coordinatorSigner)
            .addVoter(identity.commitment);
        const receipt = await tx.wait();
        const events = await voting.queryFilter(
            voting.filters.IdentityAdd(),
            receipt.blockHash
        );
        assert.equal(events[0].args.commitment, identity.commitment);
        console.log("Identity gas cost", receipt.gasUsed.toNumber());
        identity.leafIndex = events[0].args.leafIndex;

        const tree = new MerkleTree(HEIGHT, "test", new PoseidonHasher());
        assert.equal(await tree.root(), await voting.roots(0));
        await tree.insert(identity.commitment);
        assert.equal(tree.totalElements, await voting.nextIndex());
        assert.equal(await tree.root(), await voting.roots(1));

        const externalNullifier1 = 0;
        const externalNullifier2 = 1;

        // First Vote
        const nullifierHash1 = identity.nullifierHash(externalNullifier1);
        const { root, path_elements, path_index } = await tree.path(
            identity.leafIndex
        );

        const proposalToVote1 = 0;

        const firstVoteWitness: Witness = {
            // Public
            root,
            signalHash: solidityKeccak256(["uint256"], [proposalToVote1]),
            nullifiersHash: nullifierHash1,
            externalNullifier: externalNullifier1,
            // Private
            identityNullifier: BigNumber.from(identity.nullifier).toBigInt(),
            identityPathElements: path_elements,
            identityPathIndex: path_index,
        };

        const proof1 = await prove(firstVoteWitness);

        const txVote1 = await voting
            .connect(relayerSigner)
            .vote(
                proof1.a,
                proof1.b,
                proof1.c,
                root,
                nullifierHash1,
                externalNullifier1,
                proposalToVote1
            );
        const receiptVote = await txVote1.wait();
        console.log("Vote gas cost", receiptVote.gasUsed.toNumber());
        // Second Vote
        const nullifierHash2 = identity.nullifierHash(externalNullifier2);

        const proposalToVote2 = 0;

        const secondVoteWitness: Witness = {
            // Public
            root,
            signalHash: solidityKeccak256(["uint256"], [proposalToVote2]),
            nullifiersHash: nullifierHash2,
            externalNullifier: externalNullifier2,
            // Private
            identityNullifier: BigNumber.from(identity.nullifier).toBigInt(),
            identityPathElements: path_elements,
            identityPathIndex: path_index,
        };

        const proof2 = await prove(secondVoteWitness);

        await voting
            .connect(relayerSigner)
            .vote(
                proof2.a,
                proof2.b,
                proof2.c,
                root,
                nullifierHash2,
                externalNullifier2,
                proposalToVote2
            );
    }).timeout(500000);
});
