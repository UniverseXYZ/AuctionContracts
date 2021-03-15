//SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.0;

import "hardhat/console.sol";
import "./IAuction.sol";

contract Auction is IAuction {
    constructor() {}

    function createAuction(
        uint256 startBlockNumber,
        uint256 endBlockNumber,
        uint256 resetTimer,
        uint256 numberOfSlots,
        address[] memory whitelistAddresses
    ) external override {}

    function cancelAuction(uint256 auctionId)
        external
        override
        returns (bool)
    {}

    function depositERC721(
        uint256 auctionId,
        uint256 slotIndex,
        uint256 tokenId,
        address tokenAddress
    ) external override returns (bool) {}

    function bid(uint256 auctionId, uint256 amount)
        external
        override
        returns (bool)
    {}

    function finalize(uint256 auctionId) external override returns (bool) {}

    function withdrawBid(uint256 auctionId) external override returns (bool) {}

    function matchBidToSlot(uint256 auctionId, uint256 amount)
        external
        override
        returns (uint256)
    {}
}
