//SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.0;

import "hardhat/console.sol";

/// @title Users bid to this contract in order to win a slot with deposited ERC721 tokens.
/// @notice This interface should be implemented by the Auction contract
/// @dev This interface should be implemented by the Auction contract
interface IAuctionFactory {
    /// @notice Create an auction with initial parameters
    /// @param _startBlockNumber The start of the auction
    /// @param _endBlockNumber End of the auction
    /// @param _resetTimer Reset timer
    /// @param _numberOfSlots The number of slots which the auction will have
    /// @param _supportsWhitelist Array of addresses allowed to deposit
    function createAuction(
        uint256 _startBlockNumber,
        uint256 _endBlockNumber,
        uint256 _resetTimer,
        uint256 _numberOfSlots,
        bool _supportsWhitelist
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
    ) external returns (bool);

    /// @notice Sends a bid to the specified auciton
    /// @param auctionId The auction id
    /// @param amount Amount of the bid
    function bid(uint256 auctionId, uint256 amount) external returns (bool);

    /// @notice Distributes all slot assets to the bidders and winning bids to the collector
    /// @param auctionId The auction id
    function finalize(uint256 auctionId) external returns (bool);

    /// @notice Withdraws the bid amount from an auction (if slot is non-winning)
    /// @param auctionId The auction id
    function withdrawBid(uint256 auctionId) external returns (bool);

    /// @notice Matches the bid to the highest slot
    /// @param auctionId The auction id
    /// @param amount Amount of the bid
    function matchBidToSlot(uint256 auctionId, uint256 amount)
        external
        returns (uint256);

    /// @notice Cancels an auction which has not started yet
    /// @param auctionId The auction id
    function cancelAuction(uint256 auctionId) external returns (bool);
}
