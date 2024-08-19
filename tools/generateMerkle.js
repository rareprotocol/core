
function main() {
    const { MerkleTree } = require('merkletreejs')
    const keccak256 = require("keccak256")

    const leaves = ['0x789 -> 1','0x456 -> 54','0x123 -> 123'].map(x => keccak256(x))

    const tree = new MerkleTree(leaves, keccak256, {sortPairs: true})

    const root = tree.getRoot().toString('hex')

    console.log(`root: ${root}\n`)

    const leaf = keccak256('0x123 -> 123')
    const proof = tree.getProof(leaf)
    console.log(`proof: ${tree.getHexProof(keccak256('0x123 -> 123'))}`)
    console.log(`testLeaf proven: ${tree.verify(proof, leaf, root)}`) //-> true
}

main()