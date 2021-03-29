//SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "hardhat/console.sol";

/// @title Users bid to this contract in order to win a slot with deposited ERC721 tokens.
/// @notice This interface should be implemented by the Auction contract
/// @dev This interface should be implemented by the Auction contract
interface IAuctionFactory {
    struct Auction {
        address auctionOwner;
        uint256 startBlockNumber;
        uint256 endBlockNumber;
        uint256 resetTimer;
        uint256 numberOfSlots;
        uint256 numberOfBids;
        uint256 lowestEligibleBid;
        bool supportsWhitelist;
        bool isCanceled;
        address bidToken;
        mapping(uint256 => Slot) slots;
        mapping(address => bool) whitelistAddresses;
        mapping(address => uint256) balanceOf;
    }

    struct Slot {
        uint256 auctionId;
        uint256 slotIndex;
        uint256 totalDepositedNfts;
        uint256 totalWithdrawnNfts;
        mapping(uint256 => DepositedERC721) depositedNfts;
    }

    struct DepositedERC721 {
        address tokenAddress;
        uint256 tokenId;
        uint256 auctionId;
        uint256 slotIndex;
        address depositor;
    }

    /// @notice Create an auction with initial parameters
    /// @param _startBlockNumber The start of the auction
    /// @param _endBlockNumber End of the auction
    /// @param _resetTimer Reset timer in blocks
    /// @param _numberOfSlots The number of slots which the auction will have
    /// @param _supportsWhitelist Array of addresses allowed to deposit
    /// @param _bidToken Address of the token used for bidding - can be address(0)
    function createAuction(
        uint256 _startBlockNumber,
        uint256 _endBlockNumber,
        uint256 _resetTimer,
        uint256 _numberOfSlots,
        bool _supportsWhitelist,
        address _bidToken
    ) external returns (uint256);

    /// @notice Deposit ERC721 assets to the specified Auction
    /// @param auctionId The auction id
    /// @param slotIndex Index of the slot
    /// @param tokenId Id of the ERC721 token
    /// @param tokenAddress Address of the ERC721 contract
    function depositERC721(
        uint256 auctionId,
        uint256 slotIndex,
        uint256 tokenId,
        address tokenAddress
    ) external returns (uint256);

    /// @notice Deposit ERC721 assets to the specified Auction
    /// @param auctionId The auction id
    /// @param slotIndex Index of the slot
    /// @param tokenIds Array of ERC721 token ids
    /// @param tokenAddress Address of the ERC721 contract
    function depositMultipleERC721(
        uint256 auctionId,
        uint256 slotIndex,
        uint256[] calldata tokenIds,
        address tokenAddress
    ) external returns (uint256[] memory);

    /// @notice Sends a bid (ETH) to the specified auciton
    /// @param auctionId The auction id
    function bid(uint256 auctionId) external payable returns (bool);

    /// @notice Sends a bid (ERC20) to the specified auciton
    /// @param auctionId The auction id
    function bid(uint256 auctionId, uint256 amount) external returns (bool);

    /// @notice Distributes all slot assets to the bidders and winning bids to the collector
    /// @param auctionId The auction id
    function finalize(uint256 auctionId) external returns (bool);

    /// @notice Withdraws the bid amount from an auction (if slot is non-winning)
    /// @param auctionId The auction id
    function withdrawERC20Bid(uint256 auctionId) external returns (bool);

    /// @notice Withdraws the eth amount from an auction (if slot is non-winning)
    /// @param auctionId The auction id
    function withdrawEthBid(uint256 auctionId) external returns (bool);

    /// @notice Withdraws the deposited ERC721 if it hasn't been awarded
    /// @param auctionId The auction id
    /// @param slotIndex The slot index
    /// @param nftSlotIndex The index of the NFT inside the particular slot - it is returned on depositERC721() call
    function withdrawDepositedERC721(
        uint256 auctionId,
        uint256 slotIndex,
        uint256 nftSlotIndex
    ) external returns (bool);

    /// @notice Cancels an auction which has not started yet
    /// @param auctionId The auction id
    function cancelAuction(uint256 auctionId) external returns (bool);

    /// @notice Whitelist single address to be able to participate in auction
    /// @param auctionId The auction id
    /// @param addressToWhitelist The address which will be whitelisted
    function whitelistAddress(uint256 auctionId, address addressToWhitelist)
        external
        returns (bool);

    /// @notice Whitelist multiple addresses which will be able to participate in the auction
    /// @param auctionId The auction id
    /// @param addressesToWhitelist The array of addresses which will be whitelisted
    function whitelistMultipleAddresses(
        uint256 auctionId,
        address[] calldata addressesToWhitelist
    ) external returns (bool);

    /// @notice Gets deposited erc721s for slot
    /// @param auctionId The auction id
    /// @param slotIndex The slot index
    function getDepositedNftsInSlot(uint256 auctionId, uint256 slotIndex)
        external
        view
        returns (DepositedERC721[] memory);

    /// @notice Gets the bidder total bids in auction
    /// @param auctionId The auction id
    /// @param bidder The address of the bidder
    function getBidderBalance(uint256 auctionId, address bidder)
        external
        view
        returns (uint256);

    /// @notice Checks id an address is whitelisted for specific auction
    /// @param auctionId The auction id
    /// @param addressToCheck The address to be checked
    function isAddressWhitelisted(uint256 auctionId, address addressToCheck)
        external
        view
        returns (bool);
}
