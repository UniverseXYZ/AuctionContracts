//SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721Holder.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./IAuctionFactory.sol";
import "./HasSecondarySaleFees.sol";

contract AuctionFactory is IAuctionFactory, ERC721Holder, Ownable {
    using SafeMath for uint256;

    uint slotLimit = 100;

    uint256 public totalAuctions;
    uint256 public maxNumberOfSlotsPerAuction;
    uint256 public royaltyFeeMantissa;
    mapping(uint256 => Auction) public auctions;
    mapping(uint256 => uint256) public auctionsRevenue;
    mapping(address => uint256) public royaltiesReserve;
    bytes4 private constant _INTERFACE_ID_FEES = 0xb7799584;

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
        uint256 startTime,
        uint256 endTime,
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

    event LogBidMatched(
        uint256 auctionId,
        uint256 slotIndex,
        uint256 slotReservePrice,
        uint256 winningBidAmount,
        address winner,
        uint256 time
    );

    event LogAuctionExtended(uint256 auctionId, uint256 endTime, uint256 time);

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

    event LogRoyaltiesWithdrawal(
        uint256 amount,
        address to,
        address token,
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
            auctions[_auctionId].startTime < block.timestamp,
            "Auction hasn't started"
        );
        _;
    }

    modifier onlyAuctionNotStarted(uint256 _auctionId) {
        require(
            auctions[_auctionId].startTime > block.timestamp,
            "Auction has started"
        );
        _;
    }

    modifier onlyAuctionNotCanceled(uint256 _auctionId) {
        require(
            !auctions[_auctionId].isCanceled,
            "Auction is canceled"
        );
        _;
    }

    modifier onlyAuctionCanceled(uint256 _auctionId) {
        require(
            auctions[_auctionId].isCanceled,
            "Auction is not canceled"
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

    constructor(uint256 _maxNumberOfSlotsPerAuction) {
        require(
            _maxNumberOfSlotsPerAuction > 0 &&
                _maxNumberOfSlotsPerAuction <= 2000,
            "Number of slots cannot be more than 2000"
        );
        maxNumberOfSlotsPerAuction = _maxNumberOfSlotsPerAuction;
    }

    function createAuction(
        uint256 _startTime,
        uint256 _endTime,
        uint256 _resetTimer,
        uint256 _numberOfSlots,
        bool _supportsWhitelist,
        address _bidToken
    ) external override returns (uint256) {
        uint256 currentTime = block.timestamp;

        require(
            currentTime < _startTime,
            "Auction cannot begin before current block timestamp"
        );

        require(
            _startTime < _endTime,
            "Auction cannot end before it has launched"
        );

        require(_resetTimer > 0, "Reset timer must be higher than 0 seconds");

        require(
            _numberOfSlots > 0 && _numberOfSlots <= maxNumberOfSlotsPerAuction,
            "Auction can have between 1 and 2000 slots"
        );

        uint256 _auctionId = totalAuctions.add(1);

        auctions[_auctionId].auctionOwner = msg.sender;
        auctions[_auctionId].startTime = _startTime;
        auctions[_auctionId].endTime = _endTime;
        auctions[_auctionId].resetTimer = _resetTimer;
        auctions[_auctionId].numberOfSlots = _numberOfSlots;
        auctions[_auctionId].supportsWhitelist = _supportsWhitelist;
        auctions[_auctionId].bidToken = _bidToken;

        totalAuctions = _auctionId;

        emit LogAuctionCreated(
            _auctionId,
            msg.sender,
            _numberOfSlots,
            _startTime,
            _endTime,
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
            !auctions[_auctionId].supportsWhitelist ||
            auctions[_auctionId].whitelistAddresses[_depositor],
            "You are not allowed to deposit"
        );

        require(
            auctions[_auctionId].numberOfSlots >= _slotIndex && _slotIndex > 0,
            "You are trying to deposit into a non-existing slot"
        );

        require(
            auctions[_auctionId].slots[_slotIndex].totalDepositedNfts < slotLimit,
            "Cannot have more than 100 NFTs in slot"
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

        auctions[_auctionId].totalDepositedERC721s = 
            auctions[_auctionId].totalDepositedERC721s.add(1);

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
        ERC721[] calldata _tokens
    )
        public
        override
        onlyExistingAuction(_auctionId)
        onlyAuctionNotStarted(_auctionId)
        onlyAuctionNotCanceled(_auctionId)
        returns (uint256[] memory)
    {
        address _depositor = msg.sender;
        uint256[] memory _nftSlotIndexes = new uint256[](_tokens.length);

        require(
            !auctions[_auctionId].supportsWhitelist ||
            auctions[_auctionId].whitelistAddresses[_depositor],
            "You are not allowed to deposit"
        );

        require(
            auctions[_auctionId].numberOfSlots >= _slotIndex && _slotIndex > 0,
            "You are trying to deposit into a non-existing slot"
        );

        require(
            ((auctions[_auctionId].slots[_slotIndex].totalDepositedNfts +
                _tokens.length) <= slotLimit),
            "Cannot have more than 100 NFTs in slot"
        );

        for (uint256 i = 0; i < _tokens.length; i++) {
            _nftSlotIndexes[i] = depositERC721(
                _auctionId,
                _slotIndex,
                _tokens[i].tokenId,
                _tokens[i].tokenAddress
            );
        }

        return _nftSlotIndexes;
    }

    function batchDepositToAuction(
        uint256 _auctionId,
        uint256[] calldata _slotIndices,
        ERC721[][] calldata _tokens
    )
        external
        override
        onlyExistingAuction(_auctionId)
        onlyAuctionNotStarted(_auctionId)
        onlyAuctionNotCanceled(_auctionId)
        returns (bool)
    {
        Auction storage auction = auctions[_auctionId];

        require(_slotIndices.length <= auction.numberOfSlots, "Exceeding auction slots");
        require(_slotIndices.length <= 10, "Slots should be no more than 10");
        require(
            _slotIndices.length == _tokens.length,
            "Slots number should be equal to the ERC721 batches"
        );

        for (uint256 i = 0; i < _slotIndices.length; i++) {
            require(
                _tokens[i].length <= 5,
                "Max 5 ERC721s could be transferred"
            );
            depositMultipleERC721(_auctionId, _slotIndices[i], _tokens[i]);
        }

        return true;
    }

    function ethBid(uint256 _auctionId)
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

        require(block.timestamp < auction.endTime, "Auction has ended");
        require(auction.totalDepositedERC721s > 0, "No deposited NFTs in auction");

        if (
            auction.numberOfBids >= auction.numberOfSlots &&
            _bid > auction.lowestTotalBid &&
            auction.endTime.sub(block.timestamp) < auction.resetTimer
        ) {
            extendAuction(_auctionId);
        }

        uint256 bidderBalance = auction.balanceOf[_bidder];
        auction.balanceOf[_bidder] = auction.balanceOf[_bidder].add(_bid);

        if (bidderBalance == 0) {
            auction.numberOfBids = auction.numberOfBids.add(1);
        }

        if (auction.balanceOf[_bidder] > auction.highestTotalBid) {
            auction.highestTotalBid = auction.balanceOf[_bidder];
        }

        if (
            auction.balanceOf[_bidder] < auction.lowestTotalBid ||
            auction.lowestTotalBid == 0
        ) {
            auction.lowestTotalBid = auction.balanceOf[_bidder];
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

    function erc20Bid(uint256 _auctionId, uint256 _amount)
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

        require(block.timestamp < auction.endTime, "Auction has ended");
        require(auction.totalDepositedERC721s > 0, "No deposited NFTs in auction");

        IERC20 bidToken = IERC20(auction.bidToken);
        uint256 allowance = bidToken.allowance(msg.sender, address(this));

        require(allowance >= _bid, "Token allowance too small");

        uint256 bidderBalance = auction.balanceOf[_bidder];
        auction.balanceOf[_bidder] = auction.balanceOf[_bidder].add(_bid);

        if (bidderBalance == 0) {
            auction.numberOfBids = auction.numberOfBids.add(1);
        }

        if (
            auction.numberOfBids >= auction.numberOfSlots &&
            _bid > auction.lowestTotalBid &&
            auction.endTime.sub(block.timestamp) < auction.resetTimer
        ) {
            extendAuction(_auctionId);
        }

        if (auction.balanceOf[_bidder] > auction.highestTotalBid) {
            auction.highestTotalBid = auction.balanceOf[_bidder];
        }

        if (
            auction.balanceOf[_bidder] < auction.lowestTotalBid ||
            auction.lowestTotalBid == 0
        ) {
            auction.lowestTotalBid = auction.balanceOf[_bidder];
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

    function finalizeAuction(uint256 auctionId, address[] calldata bidders)
        external
        override
        onlyExistingAuction(auctionId)
        onlyAuctionNotCanceled(auctionId)
        returns (bool)
    {
        Auction storage auction = auctions[auctionId];
        bool isValid = true;

        require(
            (msg.sender == auction.auctionOwner),
            "Only the auction owner can finalize the auction"
        );
        require(
            (bidders.length <= auction.numberOfSlots),
            "Incorrect number of bidders"
        );
        require(
            block.timestamp > auction.endTime && !auction.isFinalized,
            "Auction has not finished"
        );
        require(
            auction.balanceOf[bidders[0]] == auction.highestTotalBid,
            "First address should have the highest bid"
        );

        for (uint256 i = 1; i < bidders.length; i++) {
            if (
                auction.balanceOf[bidders[i - 1]] <
                auction.balanceOf[bidders[i]]
            ) {
                isValid = false;
            }
        }

        if (!isValid) {
            return false;
        }

        uint256 lastAwardedIndex = 0;

        for (uint256 i = 0; i < bidders.length; i++) {
            for (
                lastAwardedIndex;
                lastAwardedIndex < auction.numberOfSlots;
                lastAwardedIndex++
            ) {
                if (
                    auction.balanceOf[bidders[i]] >=
                    auction.slots[lastAwardedIndex + 1].reservePrice
                ) {
                    auction.slots[lastAwardedIndex + 1]
                        .reservePriceReached = true;
                    auction.slots[lastAwardedIndex + 1]
                        .winningBidAmount = auction.balanceOf[bidders[i]];
                    auction.slots[lastAwardedIndex + 1].winner = bidders[i];

                    emit LogBidMatched(
                        auctionId,
                        lastAwardedIndex + 1,
                        auction.slots[lastAwardedIndex + 1].reservePrice,
                        auction.slots[lastAwardedIndex + 1].winningBidAmount,
                        auction.slots[lastAwardedIndex + 1].winner,
                        block.timestamp
                    );

                    lastAwardedIndex++;

                    break;
                }
            }
        }

        for (uint256 i = 0; i < auction.numberOfSlots; i++) {
            if (auction.slots[i + 1].reservePriceReached) {
                auction.winners[i + 1] = auction.slots[i + 1].winner;
                auctionsRevenue[auctionId] = auctionsRevenue[auctionId].add(
                    auction.balanceOf[auction.slots[i + 1].winner]
                );
                auction.balanceOf[auction.slots[i + 1].winner] = 0;
            }
        }

        uint256 _royaltyFee =
            calculateRoyaltyFee(auctionsRevenue[auctionId], royaltyFeeMantissa);
        auctionsRevenue[auctionId] = auctionsRevenue[auctionId].sub(
            _royaltyFee
        );
        royaltiesReserve[auction.bidToken] = royaltiesReserve[auction.bidToken]
            .add(_royaltyFee);
        auction.isFinalized = true;

        return true;
    }

    function withdrawERC20Bid(uint256 auctionId)
        external
        override
        onlyExistingAuction(auctionId)
        onlyAuctionStarted(auctionId)
        onlyAuctionNotCanceled(auctionId)
        onlyERC20(auctionId)
        returns (bool)
    {
        Auction storage auction = auctions[auctionId];
        address _sender = msg.sender;
        uint256 _amount = auction.balanceOf[_sender];

        require(_amount > 0, "You have 0 deposited");
        require(auction.isFinalized, "Auction should be finalized");

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
        returns (bool)
    {
        Auction storage auction = auctions[_auctionId];
        address payable _recipient = msg.sender;
        uint256 _amount = auction.balanceOf[_recipient];

        require(_amount > 0, "You have 0 deposited");
        require(auction.isFinalized, "Auction should be finalized");

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
        public
        override
        onlyExistingAuction(auctionId)
        onlyAuctionCanceled(auctionId)
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

    function withdrawMultipleERC721FromNonWinningSlot(
        uint256 auctionId,
        uint256 slotIndex
    )
        external
        override
        onlyExistingAuction(auctionId)
        onlyAuctionStarted(auctionId)
        onlyAuctionNotCanceled(auctionId)
        returns (bool)
    {
        Auction storage auction = auctions[auctionId];
        Slot storage nonWinningSlot = auction.slots[slotIndex];

        require(
            !auction.slots[slotIndex].reservePriceReached,
            "Can withdraw only if reserve price is not met"
        );

        require(auction.isFinalized, "Auction should be finalized");

        for (uint256 i = 0; i < nonWinningSlot.totalDepositedNfts; i++) {
            withdrawERC721FromNonWinningSlot(auctionId, slotIndex, (i+1));
        }

        return true;
    }

    function withdrawERC721FromNonWinningSlot(
        uint256 auctionId,
        uint256 slotIndex,
        uint256 nftSlotIndex
    )
        public
        override
        onlyExistingAuction(auctionId)
        onlyAuctionStarted(auctionId)
        onlyAuctionNotCanceled(auctionId)
        returns (bool)
    {
        DepositedERC721 memory nftForWithdrawal =
            auctions[auctionId].slots[slotIndex].depositedNfts[nftSlotIndex];

        require(
            msg.sender == nftForWithdrawal.depositor,
            "Only depositor can withdraw"
        );

        require(
            !auctions[auctionId].slots[slotIndex].reservePriceReached,
            "Can withdraw only if reserve price is not met"
        );

        require(auctions[auctionId].isFinalized, "Auction should be finalized");

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

        emit LogAuctionCanceled(_auctionId, block.timestamp);

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

    function getTotalDepositedNftsInSlot(uint256 auctionId, uint256 slotIndex)
        external
        view
        override
        onlyExistingAuction(auctionId)
        returns (uint256)
    {
        return auctions[auctionId].slots[slotIndex].totalDepositedNfts;
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
            block.timestamp < auction.endTime,
            "Cannot extend the auction if it has already ended"
        );

        uint256 resetTimer = auction.resetTimer;
        auction.endTime = auction.endTime.add(resetTimer);

        emit LogAuctionExtended(auctionId, auction.endTime, block.timestamp);

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

        emit LogAuctionRevenueWithdrawal(
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
        require(
            winningSlot.reservePriceReached,
            "The reserve price hasn't been met"
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

    function setRoyaltyFeeMantissa(uint256 _royaltyFeeMantissa)
        external
        override
        onlyOwner
        returns (uint256)
    {
        require(
            _royaltyFeeMantissa < 1e17,
            "Should be less than 10%"
        );
        royaltyFeeMantissa = _royaltyFeeMantissa;

        return royaltyFeeMantissa;
    }

    function calculateRoyaltyFee(uint256 amount, uint256 _royaltyFeeMantissa)
        internal
        pure
        returns (uint256)
    {
        uint256 result = _royaltyFeeMantissa.mul(amount);
        result = result.div(1e18);
        return result;
    }

    function calculateAndDistributeSecondarySaleFees(
        uint256 _auctionId,
        uint256 _slotIndex
    ) internal returns (uint256) {
        Auction storage auction = auctions[_auctionId];
        Slot storage slot = auction.slots[_slotIndex];

        require(slot.totalDepositedNfts > 0, "No NFTs deposited");
        require(slot.winningBidAmount > 0, "Winning bid should be more than 0");

        uint256 averageERC721SalePrice =
            slot.winningBidAmount.div(slot.totalDepositedNfts);

        uint256 totalFeesPaidForSlot = 0;

        for (uint256 i = 0; i < slot.totalDepositedNfts; i++) {
            DepositedERC721 memory nft = slot.depositedNfts[i + 1];

            if (
                nft.tokenAddress != address(0) &&
                IERC721(nft.tokenAddress).supportsInterface(_INTERFACE_ID_FEES)
            ) {
                HasSecondarySaleFees withFees =
                    HasSecondarySaleFees(nft.tokenAddress);
                address payable[] memory recipients =
                    withFees.getFeeRecipients(nft.tokenId);
                uint256[] memory fees = withFees.getFeeBps(nft.tokenId);
                require(
                    fees.length == recipients.length,
                    "Splits number should be equal"
                );
                uint256 value = averageERC721SalePrice;
                for (uint256 j = 0; j < fees.length; j++) {
                    Fee memory interimFee =
                        subFee(
                            value,
                            averageERC721SalePrice.mul(fees[j]).div(10000)
                        );
                    value = interimFee.remainingValue;

                    if (
                        auction.bidToken == address(0) &&
                        interimFee.feeValue > 0
                    ) {
                        recipients[j].transfer(interimFee.feeValue);
                    }

                    if (
                        auction.bidToken != address(0) &&
                        interimFee.feeValue > 0
                    ) {
                        IERC20 token = IERC20(auction.bidToken);
                        token.transfer(
                            address(recipients[j]),
                            interimFee.feeValue
                        );
                    }

                    totalFeesPaidForSlot = totalFeesPaidForSlot.add(
                        interimFee.feeValue
                    );
                }
            }
        }

        return totalFeesPaidForSlot;
    }

    function subFee(uint256 value, uint256 fee)
        internal
        pure
        returns (Fee memory interimFee)
    {
        if (value > fee) {
            interimFee.remainingValue = value - fee;
            interimFee.feeValue = fee;
        } else {
            interimFee.remainingValue = 0;
            interimFee.feeValue = value;
        }
    }

    function withdrawRoyalties(address _token, address _to)
        external
        override
        onlyOwner
        returns (uint256)
    {
        uint256 amountToWithdraw = royaltiesReserve[_token];
        require(amountToWithdraw > 0, "Amount is 0");

        royaltiesReserve[_token] = 0;

        if (_token == address(0)) {
            payable(_to).transfer(amountToWithdraw);
        }

        if (_token != address(0)) {
            IERC20 token = IERC20(_token);
            token.transfer(_to, amountToWithdraw);
        }

        emit LogRoyaltiesWithdrawal(
            amountToWithdraw,
            _to,
            _token,
            block.timestamp
        );

        return amountToWithdraw;
    }

    function setMinimumReserveForAuctionSlots(
        uint256 auctionId,
        uint256[] calldata minimumReserveValues
    )
        external
        override
        onlyExistingAuction(auctionId)
        onlyAuctionNotStarted(auctionId)
        onlyAuctionNotCanceled(auctionId)
        returns (bool)
    {
        Auction storage auction = auctions[auctionId];

        require(
            auction.numberOfSlots == minimumReserveValues.length,
            "Incorrect number of slots"
        );

        for (uint256 i = 0; i < minimumReserveValues.length; i++) {
            auction.slots[i + 1].reservePrice = minimumReserveValues[i];
        }

        return true;
    }

    function getMinimumReservePriceForSlot(uint256 auctionId, uint256 slotIndex)
        external
        view
        override
        returns (uint256)
    {
        return auctions[auctionId].slots[slotIndex].reservePrice;
    }
}
