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
        uint256 highestTotalBid;
        uint256 lowestTotalBid;
        bool supportsWhitelist;
        bool isCanceled;
        address bidToken;
        bool isFinalized;
        mapping(uint256 => Slot) slots;
        mapping(address => bool) whitelistAddresses;
        mapping(address => uint256) balanceOf;
        mapping(uint256 => address) winners;
    }

    struct Slot {
        uint256 totalDepositedNfts;
        uint256 reservePrice;
        uint256 winningBidAmount;
        bool reservePriceReached;
        address winner;
        mapping(uint256 => DepositedERC721) depositedNfts;
    }

    struct DepositedERC721 {
        address tokenAddress;
        uint256 tokenId;
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
    function ethBid(uint256 auctionId) external payable returns (bool);

    /// @notice Sends a bid (ERC20) to the specified auciton
    /// @param auctionId The auction id
    function erc20Bid(uint256 auctionId, uint256 amount) external returns (bool);

    /// @notice Distributes all slot assets to the bidders and winning bids to the collector
    /// @param auctionId The auction id
    /// @param winners Array of winners addresses to be vrified onchain
    function finalizeAuction(uint256 auctionId, address[] calldata winners)
        external
        returns (bool);

    /// @notice Withdraws the bid amount after auction is finialized and bid is non winning
    /// @param auctionId The auction id
    function withdrawERC20Bid(uint256 auctionId) external returns (bool);

    /// @notice Withdraws the eth bid amount after auction is finalized and bid is non winning
    /// @param auctionId The auction id
    function withdrawEthBid(uint256 auctionId) external returns (bool);

    /// @notice Withdraws the deposited ERC721 before an auction has started
    /// @param auctionId The auction id
    /// @param slotIndex The slot index
    /// @param nftSlotIndex The index of the NFT inside the particular slot - it is returned on depositERC721() call
    function withdrawDepositedERC721(
        uint256 auctionId,
        uint256 slotIndex,
        uint256 nftSlotIndex
    ) external returns (bool);

    /// @notice Withdraws the deposited ERC721 if the reserve price is not reached
    /// @param auctionId The auction id
    /// @param slotIndex The slot index
    /// @param nftSlotIndex The index of the NFT inside the particular slot - it is returned on depositERC721() call
    function withdrawERC721FromNonWinningSlot(
        uint256 auctionId,
        uint256 slotIndex,
        uint256 nftSlotIndex
    ) external returns (bool);

    /// @notice Cancels an auction which has not started yet
    /// @param auctionId The auction id
    function cancelAuction(uint256 auctionId) external returns (bool);

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

    /// @notice Gets slot winner for particular auction
    /// @param auctionId The auction id
    /// @param slotIndex The slot index
    function getSlotWinner(uint256 auctionId, uint256 slotIndex)
        external
        view
        returns (address);

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

    /// @notice Withdraws the generated revenue from the auction to the auction owner
    /// @param auctionId The auction id
    function withdrawAuctionRevenue(uint256 auctionId) external returns (bool);

    /// @notice Claims and distributes the NFTs from a winning slot
    /// @param auctionId The auction id
    /// @param slotIndex The slot index
    function claimERC721Rewards(uint256 auctionId, uint256 slotIndex)
        external
        returns (bool);

    /// @notice Sets the percentage of the royalty which wil be kept from each sale
    /// @param royaltyFeeMantissa The royalty percentage
    function setRoyaltyFeeMantissa(uint256 royaltyFeeMantissa)
        external
        returns (uint256);

    /// @notice Withdraws the aggregated royalites amount of specific token to a specified address
    /// @param token The address of the token to withdraw
    /// @param to The address to which the royalties will be transfered
    function withdrawRoyalties(address token, address to)
        external
        returns (uint256);

    /// @notice Sets the minimum reserve price for auction slots
    /// @param auctionId The auction id
    /// @param minimumReserveValues The array of minimum reserve values to be set for each slot, starting from slot 1
    function setMinimumReserveForAuctionSlots(
        uint256 auctionId,
        uint256[] calldata minimumReserveValues
    ) external returns (bool);

    /// @notice Gets the minimum reserve price for auciton slot
    /// @param auctionId The auction id
    /// @param slotIndex The slot index
    function getMinimumReservePriceForSlot(uint256 auctionId, uint256 slotIndex)
        external
        view
        returns (uint256);
}
