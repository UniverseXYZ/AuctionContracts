// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

interface IRoyaltiesProvider {
    
    struct Part {
        address payable account;
        uint96 value;
    }

    function getRoyalties(address token, uint tokenId) external returns (Part[] memory);
}
