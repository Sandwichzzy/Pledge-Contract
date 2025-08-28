//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMultiSignature {
    function getValidSignature(bytes32 msghash, uint256 lastIndex) external view returns (uint256);
}


contract multiSignatureClient {
    uint256 public constant multiSignaturePosition =
}