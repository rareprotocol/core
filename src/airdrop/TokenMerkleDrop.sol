// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "openzeppelin-contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/utils/Context.sol";
import "openzeppelin-contracts/access/Ownable.sol";

contract TokenMerkleDrop is Context, Ownable {
    bytes32 public claimRoot;
    IERC20 public token;
    mapping(address => bool) public rewardClaimed;

    event TokensClaimed(
        bytes32 indexed root,
        address indexed addr,
        uint256 amount
    );

    constructor(address superRareToken, bytes32 merkleRoot) {
        require(
            superRareToken != address(0),
            "Token address cant be 0 address."
        );
        require(merkleRoot != bytes32(0), "MerkleRoot cant be empty.");
        token = IERC20(superRareToken);
        claimRoot = merkleRoot;
    }

    function claim(uint256 amount, bytes32[] calldata proof) public {
        require(
            verifyEntitled(_msgSender(), amount, proof),
            "The proof could not be verified."
        );
        require(
            !rewardClaimed[_msgSender()],
            "You have already withdrawn your entitled token."
        );

        rewardClaimed[_msgSender()] = true;

        require(token.transfer(_msgSender(), amount), "Transfer failed.");
        emit TokensClaimed(claimRoot, _msgSender(), amount);
    }

    function verifyEntitled(
        address recipient,
        uint256 value,
        bytes32[] memory proof
    ) public view returns (bool) {
        // We need to pack the 20 bytes address to the 32 bytes value
        // to match with the proof
        bytes32 leaf = keccak256(abi.encodePacked(recipient, value));
        return verifyProof(leaf, proof);
    }

    function verifyProof(bytes32 leaf, bytes32[] memory proof)
        internal
        view
        returns (bool)
    {
        bytes32 currentHash = leaf;

        for (uint256 i = 0; i < proof.length; i++) {
            currentHash = parentHash(currentHash, proof[i]);
        }

        return currentHash == claimRoot;
    }

    function parentHash(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        return
            a <= b
                ? keccak256(abi.encodePacked(a, b))
                : keccak256(abi.encodePacked(b, a));
    }

    function updateMerkleRoot(bytes32 newRoot) external onlyOwner {
        claimRoot = newRoot;
    }

    function updateTokenAddress(address _token) external onlyOwner {
        require(
            _token != address(0),
            "New token address cannot be the zero address"
        );
        token = IERC20(_token);
    }
}
