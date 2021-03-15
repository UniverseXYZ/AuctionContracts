//SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.0;

import "hardhat/console.sol";
import "./IAuction.sol";

contract Auction is IAuction {
    struct Slot {
        address tokenAddress;
        address owner;
        uint256 tokenId;
    }

    struct _Auction {
        bool supportWhitelist;
        uint256 startBlockNumber;
        uint256 endBlockNumber;
        uint256 resetTimer;
        uint256 numberOfSlots;
        mapping(address => bool) isWhiteListed;
        Slot[] slots;
    }

    mapping(address => _Auction[]) auctionsOf;

    event DEPOSIT_ERC721(
        address sender,
        address tokenAddress,
        uint256 tokenId,
        uint256 auction,
        uint256 slot,
        uint256 time
    );

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
        address sender = msg.sender;

        if (auction.supportWhitelist) {
            require(
                auction.isWhiteListed[sender],
                "You are not allowed to deposit in this auction"
            );
        }

        require(
            auction.slots[slotIndex].tokenId == 0 &&
                auction.slots[slotIndex].tokenAddress == address(0),
            "Slot index is already taken"
        );

        require(
            auction.slots.length <= auction.numberOfSlots,
            "All slots are filled"
        );

        Slot memory slot;

        slot.tokenAddress = tokenAddress;
        slot.tokenId = tokenId;
        slot.owner = sender;

        auction.slots.push(slot);

        emit DEPOSIT_ERC721(
            sender,
            tokenAddress,
            tokenId,
            auctionId,
            auction.slots.length,
            block.timestamp
        );

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
