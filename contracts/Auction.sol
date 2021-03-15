//SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.0;

import "hardhat/console.sol";
import "./IAuction.sol";

contract Auction is IAuction {
    struct Slot {
        uint256 tokenId;
        address tokenAddress;
    }

    struct _Auction {
        uint256 startBlockNumber;
        uint256 endBlockNumber;
        uint256 resetTimer;
        address[] whitelistAddresses;
        Slot[] slots;
    }

    mapping(address => _Auction[]) auctionsOf;

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
        address auctionOwner,
        uint256 auctionId,
        uint256 slotIndex,
        uint256 tokenId,
        address tokenAddress
    ) external override returns (bool) {
        require(
            auctionOwner != address(0),
            "Zero address was provided for auction owner"
        );
        require(
            tokenAddress != address(0),
            "Zero address was provided for token address"
        );

        _Auction storage auction = auctionsOf[auctionOwner][auctionId];

        require(
            auction.slots[slotIndex].tokenId == 0 &&
                auction.slots[slotIndex].tokenAddress == address(0),
            "Slot index is already taken"
        );

        Slot memory slot;

        slot.tokenAddress = tokenAddress;
        slot.tokenId = tokenId;

        auction.slots.push(slot);

        return true;
    }

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
