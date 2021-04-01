//SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721Holder.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./IAuctionFactory.sol";

contract AuctionFactory is IAuctionFactory, ERC721Holder, Ownable {
    using SafeMath for uint256;

    uint256 private totalAuctions;
    mapping(uint256 => Auction) public auctions;
    mapping(uint256 => uint256) private auctionsRevenue;

    event LogERC721Deposit(
        address depositor,
        address tokenAddress,
        uint256 tokenId,
        uint256 auctionId,
        uint256 slotIndex,
        uint256 nftSlotIndex,
        uint256 time
    );

    event LogERC721Withdrawal(
        address depositor,
        address tokenAddress,
        uint256 tokenId,
        uint256 auctionId,
        uint256 slotIndex,
        uint256 nftSlotIndex,
        uint256 time
    );

    event LogAuctionCreated(
        uint256 auctionId,
        address auctionOwner,
        uint256 numberOfSlots,
        uint256 startBlockNumber,
        uint256 endBlockNumber,
        uint256 resetTimer,
        bool supportsWhitelist,
        uint256 time
    );

    event LogBidSubmitted(
        address sender,
        uint256 auctionId,
        uint256 currentBid,
        uint256 totalBid,
        uint256 time
    );

    event LogBidWithdrawal(
        address recipient,
        uint256 auctionId,
        uint256 amount,
        uint256 time
    );

    event LogAuctionExtended(
        uint256 auctionId,
        uint256 endBlockNumber,
        uint256 time
    );

    event LogAuctionCanceled(uint256 auctionId, uint256 time);

    event LogAuctionRevenueWithdrawal(
        address recipient,
        uint256 auctionId,
        uint256 amount,
        uint256 time
    );

    event LogERC721RewardsClaim(
        address claimer,
        uint256 auctionId,
        uint256 slotIndex,
        uint256 time
    );

    modifier onlyExistingAuction(uint256 _auctionId) {
        require(
            _auctionId > 0 && _auctionId <= totalAuctions,
            "Auction doesn't exist"
        );
        _;
    }

    modifier onlyAuctionStarted(uint256 _auctionId) {
        require(
            auctions[_auctionId].startBlockNumber < block.number,
            "Auction hasn't started"
        );
        _;
    }

    modifier onlyAuctionNotStarted(uint256 _auctionId) {
        require(
            auctions[_auctionId].startBlockNumber > block.number,
            "Auction has started"
        );
        _;
    }

    modifier onlyAuctionNotCanceled(uint256 _auctionId) {
        require(
            auctions[_auctionId].isCanceled == false,
            "Auction is canceled"
        );
        _;
    }

    modifier onlyValidBidAmount(uint256 _bid) {
        require(_bid > 0, "Bid amount must be higher than 0");
        _;
    }

    modifier onlyETH(uint256 _auctionId) {
        require(
            auctions[_auctionId].bidToken == address(0),
            "Token address provided"
        );
        _;
    }

    modifier onlyERC20(uint256 _auctionId) {
        require(
            auctions[_auctionId].bidToken != address(0),
            "No token address provided"
        );
        _;
    }

    modifier onlyWhenBidOnAllSlots(uint256 _auctionId) {
        require(
            auctions[_auctionId].numberOfBids >
                auctions[_auctionId].numberOfSlots,
            "All slots must have bids before a withdrawal can occur"
        );
        _;
    }

    modifier onlyWhenBidNotEligible(uint256 _auctionId) {
        require(
            auctions[_auctionId].balanceOf[msg.sender] <
                auctions[_auctionId].lowestEligibleBid,
            "Bid is still eligible"
        );
        _;
    }

    modifier onlyIfWhitelistSupported(uint256 _auctionId) {
        require(
            auctions[_auctionId].supportsWhitelist,
            "The auction should support whitelisting"
        );
        _;
    }

    modifier onlyAuctionOwner(uint256 _auctionId) {
        require(
            auctions[_auctionId].auctionOwner == msg.sender,
            "Only auction owner can whitelist addresses"
        );
        _;
    }

    constructor() {}

    function createAuction(
        uint256 _startBlockNumber,
        uint256 _endBlockNumber,
        uint256 _resetTimer,
        uint256 _numberOfSlots,
        bool _supportsWhitelist,
        address _bidToken
    ) external override returns (uint256) {
        uint256 blockNumber = block.number;

        require(
            blockNumber < _startBlockNumber,
            "Auction cannot begin before current block"
        );

        require(
            _startBlockNumber < _endBlockNumber,
            "Auction cannot end before it has launched"
        );

        require(_resetTimer > 0, "Reset timer must be higher than 0 blocks");

        require(
            _numberOfSlots > 0 && _numberOfSlots <= 2000,
            "Auction can have between 1 and 2000 slots"
        );

        uint256 _auctionId = totalAuctions.add(1);

        auctions[_auctionId].auctionOwner = msg.sender;
        auctions[_auctionId].startBlockNumber = _startBlockNumber;
        auctions[_auctionId].endBlockNumber = _endBlockNumber;
        auctions[_auctionId].resetTimer = _resetTimer;
        auctions[_auctionId].numberOfSlots = _numberOfSlots;
        auctions[_auctionId].lowestEligibleBid = uint256(-1);
        auctions[_auctionId].supportsWhitelist = _supportsWhitelist;
        auctions[_auctionId].bidToken = _bidToken;

        totalAuctions = _auctionId;

        emit LogAuctionCreated(
            _auctionId,
            msg.sender,
            _numberOfSlots,
            _startBlockNumber,
            _endBlockNumber,
            _resetTimer,
            _supportsWhitelist,
            block.timestamp
        );

        return _auctionId;
    }

    function depositERC721(
        uint256 _auctionId,
        uint256 _slotIndex,
        uint256 _tokenId,
        address _tokenAddress
    )
        public
        override
        onlyExistingAuction(_auctionId)
        onlyAuctionNotStarted(_auctionId)
        onlyAuctionNotCanceled(_auctionId)
        returns (uint256)
    {
        address _depositor = msg.sender;

        require(
            _tokenAddress != address(0),
            "Zero address was provided for token"
        );

        require(
            auctions[_auctionId].supportsWhitelist == false ||
                auctions[_auctionId].whitelistAddresses[_depositor] == true,
            "You are not allowed to deposit"
        );

        require(
            auctions[_auctionId].numberOfSlots >= _slotIndex && _slotIndex > 0,
            "You are trying to deposit into a non-existing slot"
        );

        DepositedERC721 memory item =
            DepositedERC721({
                tokenId: _tokenId,
                tokenAddress: _tokenAddress,
                depositor: _depositor
            });

        uint256 _nftSlotIndex =
            auctions[_auctionId].slots[_slotIndex].totalDepositedNfts.add(1);

        auctions[_auctionId].slots[_slotIndex].depositedNfts[
            _nftSlotIndex
        ] = item;

        auctions[_auctionId].slots[_slotIndex]
            .totalDepositedNfts = _nftSlotIndex;

        IERC721(_tokenAddress).safeTransferFrom(
            _depositor,
            address(this),
            _tokenId
        );

        emit LogERC721Deposit(
            _depositor,
            _tokenAddress,
            _tokenId,
            _auctionId,
            _slotIndex,
            _nftSlotIndex,
            block.timestamp
        );

        return _nftSlotIndex;
    }

    function depositMultipleERC721(
        uint256 _auctionId,
        uint256 _slotIndex,
        uint256[] calldata _tokenIds,
        address _tokenAddress
    )
        external
        override
        onlyExistingAuction(_auctionId)
        onlyAuctionNotStarted(_auctionId)
        onlyAuctionNotCanceled(_auctionId)
        returns (uint256[] memory)
    {
        address _depositor = msg.sender;
        uint256[] memory _nftSlotIndexes = new uint256[](_tokenIds.length);

        require(
            _tokenAddress != address(0),
            "Zero address was provided for token"
        );

        require(
            auctions[_auctionId].supportsWhitelist == false ||
                auctions[_auctionId].whitelistAddresses[_depositor] == true,
            "You are not allowed to deposit"
        );

        require(
            auctions[_auctionId].numberOfSlots >= _slotIndex && _slotIndex > 0,
            "You are trying to deposit into a non-existing slot"
        );

        for (uint256 i = 0; i < _tokenIds.length; i++) {
            _nftSlotIndexes[i] = depositERC721(
                _auctionId,
                _slotIndex,
                _tokenIds[i],
                _tokenAddress
            );
        }

        return _nftSlotIndexes;
    }

    function bid(uint256 _auctionId)
        external
        payable
        override
        onlyExistingAuction(_auctionId)
        onlyAuctionStarted(_auctionId)
        onlyAuctionNotCanceled(_auctionId)
        onlyETH(_auctionId)
        onlyValidBidAmount(msg.value)
        returns (bool)
    {
        uint256 _bid = msg.value;
        address _bidder = msg.sender;
        Auction storage auction = auctions[_auctionId];

        require(
            (auction.numberOfBids < auction.numberOfSlots ||
                _bid > auction.lowestEligibleBid),
            "Bid amount must be greater than the lowest eligible bid when all auction slots are filled"
        );

        if (
            _bid < auction.lowestEligibleBid ||
            auction.numberOfSlots <= auction.numberOfBids
        ) {
            auction.lowestEligibleBid = _bid;
        }

        if (
            _bid > auction.lowestEligibleBid &&
            auction.endBlockNumber.sub(block.number) < auction.resetTimer
        ) {
            extendAuction(_auctionId);
        }

        auction.balanceOf[_bidder] = auction.balanceOf[_bidder].add(_bid);
        auction.numberOfBids = auction.numberOfBids.add(1);

        if (auction.balanceOf[_bidder] > auction.highestTotalBid) {
            auction.highestTotalBid = auction.balanceOf[_bidder];
        }

        emit LogBidSubmitted(
            _bidder,
            _auctionId,
            _bid,
            auction.balanceOf[_bidder],
            block.timestamp
        );

        return true;
    }

    function bid(uint256 _auctionId, uint256 _amount)
        external
        override
        onlyExistingAuction(_auctionId)
        onlyAuctionStarted(_auctionId)
        onlyAuctionNotCanceled(_auctionId)
        onlyERC20(_auctionId)
        onlyValidBidAmount(_amount)
        returns (bool)
    {
        uint256 _bid = _amount;
        address _bidder = msg.sender;
        Auction storage auction = auctions[_auctionId];

        require(
            (auction.numberOfBids < auction.numberOfSlots ||
                _bid > auction.lowestEligibleBid),
            "Bid amount must be greater than the lowest eligible bid when all auction slots are filled"
        );

        IERC20 bidToken = IERC20(auction.bidToken);
        uint256 allowance = bidToken.allowance(msg.sender, address(this));

        require(allowance >= _bid, "Token allowance too small");

        if (
            _bid < auction.lowestEligibleBid ||
            auction.numberOfSlots <= auction.numberOfBids
        ) {
            auction.lowestEligibleBid = _bid;
        }

        auction.balanceOf[_bidder] = auction.balanceOf[_bidder].add(_bid);
        auction.numberOfBids = auction.numberOfBids.add(1);

        if (
            _bid > auction.lowestEligibleBid &&
            auction.endBlockNumber.sub(block.number) < auction.resetTimer
        ) {
            extendAuction(_auctionId);
        }

        if (auction.balanceOf[_bidder] > auction.highestTotalBid) {
            auction.highestTotalBid = auction.balanceOf[_bidder];
        }

        bidToken.transferFrom(_bidder, address(this), _bid);

        emit LogBidSubmitted(
            _bidder,
            _auctionId,
            _bid,
            auction.balanceOf[_bidder],
            block.timestamp
        );

        return true;
    }

    function finalizeAuction(uint256 auctionId, address[] calldata winners)
        external
        override
        onlyExistingAuction(auctionId)
        onlyAuctionNotCanceled(auctionId)
        returns (bool)
    {
        Auction storage auction = auctions[auctionId];
        bool isValid = true;

        require(
            winners.length == auction.numberOfSlots,
            "Incorrect number of winners"
        );
        require(
            block.number > auction.endBlockNumber &&
                auction.isFinalized == false,
            "Auction has not finished"
        );
        require(
            auction.balanceOf[winners[0]] == auction.highestTotalBid,
            "First address should have the highest bid"
        );
        require(
            auction.balanceOf[winners[winners.length - 1]] ==
                auction.lowestEligibleBid,
            "Last address should have the lowest bid"
        );

        for (uint256 i = 1; i < winners.length; i++) {
            if (
                auction.balanceOf[winners[i - 1]] <
                auction.balanceOf[winners[i]]
            ) {
                isValid = false;
            }
        }

        if (isValid) {
            for (uint256 i = 0; i < winners.length; i++) {
                auction.winners[i + 1] = winners[i];
                auctionsRevenue[auctionId] = auctionsRevenue[auctionId].add(
                    auction.balanceOf[winners[i]]
                );
            }
            auction.isFinalized = true;
        }
        return isValid;
    }

    function withdrawERC20Bid(uint256 auctionId)
        external
        override
        onlyExistingAuction(auctionId)
        onlyAuctionStarted(auctionId)
        onlyAuctionNotCanceled(auctionId)
        onlyERC20(auctionId)
        onlyWhenBidOnAllSlots(auctionId)
        onlyWhenBidNotEligible(auctionId)
        returns (bool)
    {
        Auction storage auction = auctions[auctionId];
        address _sender = msg.sender;
        uint256 _amount = auction.balanceOf[_sender];

        auction.balanceOf[_sender] = 0;
        IERC20 bidToken = IERC20(auction.bidToken);
        bidToken.transfer(_sender, _amount);

        emit LogBidWithdrawal(_sender, auctionId, _amount, block.timestamp);

        return true;
    }

    function withdrawEthBid(uint256 _auctionId)
        external
        override
        onlyExistingAuction(_auctionId)
        onlyAuctionStarted(_auctionId)
        onlyAuctionNotCanceled(_auctionId)
        onlyETH(_auctionId)
        onlyWhenBidOnAllSlots(_auctionId)
        onlyWhenBidNotEligible(_auctionId)
        returns (bool)
    {
        Auction storage auction = auctions[_auctionId];
        address payable _recipient = msg.sender;
        uint256 _amount = auction.balanceOf[_recipient];

        require(_amount > 0, "You have 0 deposited");

        auction.balanceOf[_recipient] = 0;
        _recipient.transfer(_amount);

        emit LogBidWithdrawal(_recipient, _auctionId, _amount, block.timestamp);

        return true;
    }

    function withdrawDepositedERC721(
        uint256 auctionId,
        uint256 slotIndex,
        uint256 nftSlotIndex
    )
        external
        override
        onlyExistingAuction(auctionId)
        onlyAuctionNotStarted(auctionId)
        returns (bool)
    {
        DepositedERC721 memory nftForWithdrawal =
            auctions[auctionId].slots[slotIndex].depositedNfts[nftSlotIndex];

        require(
            msg.sender == nftForWithdrawal.depositor,
            "Only depositor can withdraw"
        );

        delete auctions[auctionId].slots[slotIndex].depositedNfts[nftSlotIndex];

        IERC721(nftForWithdrawal.tokenAddress).safeTransferFrom(
            address(this),
            nftForWithdrawal.depositor,
            nftForWithdrawal.tokenId
        );

        emit LogERC721Withdrawal(
            msg.sender,
            nftForWithdrawal.tokenAddress,
            nftForWithdrawal.tokenId,
            auctionId,
            slotIndex,
            nftSlotIndex,
            block.timestamp
        );

        return true;
    }

    function cancelAuction(uint256 _auctionId)
        external
        override
        onlyExistingAuction(_auctionId)
        onlyAuctionNotStarted(_auctionId)
        onlyAuctionNotCanceled(_auctionId)
        onlyAuctionOwner(_auctionId)
        returns (bool)
    {
        auctions[_auctionId].isCanceled = true;

        LogAuctionCanceled(_auctionId, block.timestamp);

        return true;
    }

    function whitelistMultipleAddresses(
        uint256 auctionId,
        address[] calldata addressesToWhitelist
    )
        external
        override
        onlyExistingAuction(auctionId)
        onlyIfWhitelistSupported(auctionId)
        onlyAuctionOwner(auctionId)
        onlyAuctionNotStarted(auctionId)
        onlyAuctionNotCanceled(auctionId)
        returns (bool)
    {
        Auction storage auction = auctions[auctionId];

        for (uint256 i = 0; i < addressesToWhitelist.length; i++) {
            auction.whitelistAddresses[addressesToWhitelist[i]] = true;
        }

        return true;
    }

    function getDepositedNftsInSlot(uint256 auctionId, uint256 slotIndex)
        external
        view
        override
        onlyExistingAuction(auctionId)
        returns (DepositedERC721[] memory)
    {
        uint256 nftsInSlot =
            auctions[auctionId].slots[slotIndex].totalDepositedNfts;

        DepositedERC721[] memory nfts = new DepositedERC721[](nftsInSlot);

        for (uint256 i = 0; i < nftsInSlot; i++) {
            nfts[i] = auctions[auctionId].slots[slotIndex].depositedNfts[i + 1];
        }
        return nfts;
    }

    function getSlotWinner(uint256 auctionId, uint256 slotIndex)
        external
        view
        override
        returns (address)
    {
        return auctions[auctionId].winners[slotIndex];
    }

    function getBidderBalance(uint256 auctionId, address bidder)
        external
        view
        override
        onlyExistingAuction(auctionId)
        returns (uint256)
    {
        return auctions[auctionId].balanceOf[bidder];
    }

    function isAddressWhitelisted(uint256 auctionId, address addressToCheck)
        external
        view
        override
        onlyExistingAuction(auctionId)
        returns (bool)
    {
        return auctions[auctionId].whitelistAddresses[addressToCheck];
    }

    function extendAuction(uint256 auctionId)
        internal
        onlyExistingAuction(auctionId)
        returns (bool)
    {
        Auction storage auction = auctions[auctionId];

        require(
            block.number < auction.endBlockNumber,
            "Cannot extend the auction if it has already ended"
        );

        uint256 resetTimer = auction.resetTimer;
        auction.endBlockNumber = auction.endBlockNumber.add(resetTimer);

        emit LogAuctionExtended(
            auctionId,
            auction.endBlockNumber,
            block.timestamp
        );

        return true;
    }

    function withdrawAuctionRevenue(uint256 auctionId)
        external
        override
        onlyExistingAuction(auctionId)
        returns (bool)
    {
        Auction storage auction = auctions[auctionId];
        require(auction.isFinalized, "Auction should have ended");

        uint256 amountToWithdraw = auctionsRevenue[auctionId];

        auctionsRevenue[auctionId] = 0;

        if (auction.bidToken == address(0)) {
            payable(auction.auctionOwner).transfer(amountToWithdraw);
        }

        if (auction.bidToken != address(0)) {
            IERC20 bidToken = IERC20(auction.bidToken);
            bidToken.transfer(auction.auctionOwner, amountToWithdraw);
        }

        LogAuctionRevenueWithdrawal(
            auction.auctionOwner,
            auctionId,
            amountToWithdraw,
            block.timestamp
        );

        return true;
    }

    function claimERC721Rewards(uint256 auctionId, uint256 slotIndex)
        external
        override
        returns (bool)
    {
        address claimer = msg.sender;

        Auction storage auction = auctions[auctionId];
        Slot storage winningSlot = auction.slots[slotIndex];

        require(auction.isFinalized, "Auction should have ended");
        require(
            auction.winners[slotIndex] == claimer,
            "Only the winner can claim rewards"
        );

        for (uint256 i = 0; i < winningSlot.totalDepositedNfts; i++) {
            DepositedERC721 memory nftForWithdrawal =
                winningSlot.depositedNfts[i + 1];

            if (nftForWithdrawal.tokenId != 0) {
                IERC721(nftForWithdrawal.tokenAddress).safeTransferFrom(
                    address(this),
                    claimer,
                    nftForWithdrawal.tokenId
                );
            }
        }

        emit LogERC721RewardsClaim(
            claimer,
            auctionId,
            slotIndex,
            block.timestamp
        );

        return true;
    }
}
