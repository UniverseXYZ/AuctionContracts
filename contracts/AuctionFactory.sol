//SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./IAuctionFactory.sol";

contract AuctionFactory is IAuctionFactory, IERC721Receiver {
    using SafeMath for uint256;

    struct Auction {
        address auctionOwner;
        uint256 startBlockNumber;
        uint256 endBlockNumber;
        uint256 resetTimer;
        uint256 numberOfSlots;
        bool supportsWhitelist;
    }

    struct Slot {
        uint256 auctionId;
        uint256 slotIndex;
        DepositedERC721[] nfts;
    }

    struct DepositedERC721 {
        address tokenAddress;
        uint256 tokenId;
        uint256 auctionId;
        uint256 slotIndex;
    }

    // totalAuctions
    uint256 public totalAuctions;
    // auctionId -> Auction
    mapping(uint256 => Auction) public auctions;
    // auctionId -> slotIndex -> Slot
    mapping(uint256 => mapping(uint256 => Slot)) public auctionsSlots;
    // auctionId -> depositorAddress -> true/false
    mapping(uint256 => mapping(address => bool)) public auctionWhitelistAddresses;

    event LogERC721Deposit(
        address depositor,
        address tokenAddress,
        uint256 tokenId,
        uint256 auctionId,
        uint256 slotIndex,
        uint256 time
    );

    event LogAuctionCreated(
        uint256 auctionId,
        address auctionOwner,
        uint256 numberOfSlots
    );

    constructor() {
        totalAuctions = 0;
    }

    function createAuction(
        uint256 _startBlockNumber,
        uint256 _endBlockNumber,
        uint256 _resetTimer,
        uint256 _numberOfSlots,
        bool _supportsWhitelist
    ) external override returns (uint256) {
        uint blockNumber = block.number;
        require(blockNumber >= _startBlockNumber);
        require(blockNumber < _endBlockNumber);

        uint256 auctionId = totalAuctions.add(1);

        Auction memory auction =
            Auction({
                auctionOwner: msg.sender,
                startBlockNumber: _startBlockNumber,
                endBlockNumber: _endBlockNumber,
                resetTimer: _resetTimer,
                numberOfSlots: _numberOfSlots,
                supportsWhitelist: _supportsWhitelist
            });

        auctions[auctionId] = auction;
        totalAuctions.add(1);

        emit LogAuctionCreated(auctionId, msg.sender, _numberOfSlots);

        return auctionId;
    }

    function depositERC721(
        uint256 auctionId,
        uint256 slotIndex,
        uint256 tokenId,
        address tokenAddress
    ) external override returns (bool) {
        require(
            tokenAddress != address(0),
            "Zero address was provided for token address"
        );

        address depositor = msg.sender;

        if (auctions[auctionId].supportsWhitelist) {
            require(
                auctionWhitelistAddresses[auctionId][depositor],
                "You are not allowed to deposit in this auction"
            );
        }

        require(
            auctions[auctionId].numberOfSlots > slotIndex,
            "You are trying to deposit to a non-existing slot"
        );

        DepositedERC721 memory item;

        item.tokenAddress = tokenAddress;
        item.tokenId = tokenId;
        item.auctionId = auctionId;
        item.slotIndex = slotIndex;

        auctionsSlots[auctionId][slotIndex].auctionId = auctionId;
        auctionsSlots[auctionId][slotIndex].slotIndex = slotIndex;
        auctionsSlots[auctionId][slotIndex].nfts.push(item);

        IERC721(tokenAddress).safeTransferFrom(
            depositor,
            address(this),
            tokenId
        );

        emit LogERC721Deposit(
            depositor,
            tokenAddress,
            tokenId,
            auctionId,
            slotIndex,
            block.timestamp
        );

        return true;
    }

    function bid(uint256 auctionId, uint256 amount) external override returns (bool) {}

    function finalize(uint256 auctionId) external override returns (bool) {}

    function withdrawBid(uint256 auctionId) external override returns (bool) {}

    function matchBidToSlot(uint256 auctionId, uint256 amount) external override returns (uint256) {}

    function cancelAuction(uint256 auctionId) external override returns (bool) {}

    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external override returns (bytes4){
        return IERC721Receiver(0).onERC721Received.selector;
    }
}
