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

    uint256 public totalAuctions;
    uint256 public maxNumberOfSlotsPerAuction;
    uint256 public royaltyFeeMantissa;
    mapping(uint256 => Auction) public auctions;
    mapping(uint256 => uint256) public auctionsRevenue;
    mapping(address => uint256) public royaltiesReserve;
    bytes4 private constant _INTERFACE_ID_FEES = 0xb7799584;
    address constant GUARD = address(1);

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
        require(!auctions[_auctionId].isCanceled, "Auction is canceled");
        _;
    }

    modifier onlyAuctionCanceled(uint256 _auctionId) {
        require(auctions[_auctionId].isCanceled, "Auction is not canceled");
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
        auctions[_auctionId].nextBidders[GUARD] = GUARD;

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
            auctions[_auctionId].slots[_slotIndex].totalDepositedNfts < 40,
            "Cannot have more than 40 NFTs in slot"
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

        auctions[_auctionId].totalDepositedERC721s = auctions[_auctionId]
            .totalDepositedERC721s
            .add(1);

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
                _tokens.length) <= 40),
            "Cannot have more than 40 NFTs in slot"
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

        require(
            _slotIndices.length <= auction.numberOfSlots,
            "Exceeding auction slots"
        );
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

    function ethBid(uint256 auctionId)
        public
        payable
        override
        onlyExistingAuction(auctionId)
        onlyAuctionStarted(auctionId)
        onlyAuctionNotCanceled(auctionId)
        onlyETH(auctionId)
        onlyValidBidAmount(msg.value)
    {
        Auction storage auction = auctions[auctionId];

        require(block.timestamp < auction.endTime, "Auction has ended");
        require(
            auction.totalDepositedERC721s > 0,
            "No deposited NFTs in auction"
        );

        uint256 bidderCurrentBalance = auction.bidBalance[msg.sender];

        // Check if this is first time bidding
        if (bidderCurrentBalance == 0) {
            // Add bid without checks if total bids are less than total slots
            if (auction.numberOfBids < auction.numberOfSlots) {
                addBid(auctionId, msg.sender, msg.value);
                // Check if slots are filled (we have more bids than slots)
            } else if (auction.numberOfBids >= auction.numberOfSlots) {
                // If slots are filled, check if the bid is within the winning slots
                require(
                    isWinningBid(auctionId, msg.value),
                    "Bid should be winnning"
                );
                // Add bid only if it is within the winning slots
                addBid(auctionId, msg.sender, msg.value);
                if (auction.endTime.sub(block.timestamp) < auction.resetTimer) {
                    // Extend the auction if the remaining time is less than the reset timer
                    extendAuction(auctionId);
                }
            }
            // Check if the user has previously submitted bids
        } else if (bidderCurrentBalance > 0) {
            // Find which is the next highest bidder balance and ensure the incremented bid is bigger
            address previousBidder = _findPreviousBidder(auctionId, msg.sender);
            require(
                msg.value > auction.bidBalance[previousBidder],
                "New bid should be higher than next highest slot bid"
            );
            // Update bid directly without additional checks if total bids are less than total slots
            if (auction.numberOfBids < auction.numberOfSlots) {
                updateBid(
                    auctionId,
                    msg.sender,
                    bidderCurrentBalance.add(msg.value)
                );
                // If slots are filled, check if the current bidder balance + the new amount will be withing the winning slots
            } else if (auction.numberOfBids >= auction.numberOfSlots) {
                require(
                    isWinningBid(
                        auctionId,
                        bidderCurrentBalance.add(msg.value)
                    ),
                    "Bid should be winnning"
                );
                // Update the bid if the new incremented balance falls within the winning slots
                updateBid(
                    auctionId,
                    msg.sender,
                    bidderCurrentBalance.add(msg.value)
                );
                if (auction.endTime.sub(block.timestamp) < auction.resetTimer) {
                    // Extend the auction if the remaining time is less than the reset timer
                    extendAuction(auctionId);
                }
            }
        }
    }

    function erc20Bid(uint256 auctionId, uint256 amount)
        external
        override
        onlyExistingAuction(auctionId)
        onlyAuctionStarted(auctionId)
        onlyAuctionNotCanceled(auctionId)
        onlyERC20(auctionId)
        onlyValidBidAmount(amount)
    {
        Auction storage auction = auctions[auctionId];

        require(block.timestamp < auction.endTime, "Auction has ended");
        require(
            auction.totalDepositedERC721s > 0,
            "No deposited NFTs in auction"
        );

        IERC20 bidToken = IERC20(auction.bidToken);
        uint256 allowance = bidToken.allowance(msg.sender, address(this));

        require(allowance >= amount, "Token allowance too small");

        uint256 bidderCurrentBalance = auction.bidBalance[msg.sender];

        // Check if this is first time bidding
        if (bidderCurrentBalance == 0) {
            // Add bid without checks if total bids are less than total slots
            if (auction.numberOfBids < auction.numberOfSlots) {
                addBid(auctionId, msg.sender, amount);
                bidToken.transferFrom(msg.sender, address(this), amount);
                // Check if slots are filled (if we have more bids than slots)
            } else if (auction.numberOfBids >= auction.numberOfSlots) {
                // If slots are filled, check if the bid is within the winning slots
                require(
                    isWinningBid(auctionId, amount),
                    "Bid should be winnning"
                );
                // Add bid only if it is within the winning slots
                addBid(auctionId, msg.sender, amount);
                bidToken.transferFrom(msg.sender, address(this), amount);
                if (auction.endTime.sub(block.timestamp) < auction.resetTimer) {
                    // Extend the auction if the remaining time is less than the reset timer
                    extendAuction(auctionId);
                }
            }
            // Check if the user has previously submitted bids
        } else if (bidderCurrentBalance > 0) {
            // Find which is the next highest bidder balance and ensure the incremented bid is bigger
            address previousBidder = _findPreviousBidder(auctionId, msg.sender);
            require(
                amount > auction.bidBalance[previousBidder],
                "New bid should be higher than next highest slot bid"
            );
            // Update bid directly without additional checks if total bids are less than total slots
            if (auction.numberOfBids < auction.numberOfSlots) {
                updateBid(
                    auctionId,
                    msg.sender,
                    bidderCurrentBalance.add(amount)
                );
                bidToken.transferFrom(msg.sender, address(this), amount);
                // If slots are filled, check if the current bidder balance + the new amount will be withing the winning slots
            } else if (auction.numberOfBids >= auction.numberOfSlots) {
                require(
                    isWinningBid(auctionId, bidderCurrentBalance.add(amount)),
                    "Bid should be winnning"
                );
                // Update the bid if the new incremented balance falls within the winning slots
                updateBid(
                    auctionId,
                    msg.sender,
                    bidderCurrentBalance.add(amount)
                );
                bidToken.transferFrom(msg.sender, address(this), amount);
                if (auction.endTime.sub(block.timestamp) < auction.resetTimer) {
                    // Extend the auction if the remaining time is less than the reset timer
                    extendAuction(auctionId);
                }
            }
        }
    }

    function finalizeAuction(uint256 auctionId)
        external
        override
        onlyExistingAuction(auctionId)
        onlyAuctionNotCanceled(auctionId)
        returns (bool)
    {
        Auction storage auction = auctions[auctionId];

        require(
            block.timestamp > auction.endTime && !auction.isFinalized,
            "Auction has not finished"
        );

        address[] memory bidders;
        uint256 lastAwardedIndex = 0;

        // Get top bidders for the auction, according to the number of slots
        if (auction.numberOfBids > auction.numberOfSlots) {
            bidders = getTopBidders(auctionId, auction.numberOfSlots);
        } else {
            bidders = getTopBidders(auctionId, auction.numberOfBids);
        }

        // Award the slots by checking the highest bidders and minimum reserve values
        for (uint256 i = 0; i < bidders.length; i++) {
            for (
                lastAwardedIndex;
                lastAwardedIndex < auction.numberOfSlots;
                lastAwardedIndex++
            ) {
                if (
                    auction.bidBalance[bidders[i]] >=
                    auction.slots[lastAwardedIndex + 1].reservePrice
                ) {
                    auction.slots[lastAwardedIndex + 1]
                        .reservePriceReached = true;
                    auction.slots[lastAwardedIndex + 1]
                        .winningBidAmount = auction.bidBalance[bidders[i]];
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

        // Calculate the auction revenue from sold slots and reset bid balances
        for (uint256 i = 0; i < auction.numberOfSlots; i++) {
            if (auction.slots[i + 1].reservePriceReached) {
                auction.winners[i + 1] = auction.slots[i + 1].winner;
                auctionsRevenue[auctionId] = auctionsRevenue[auctionId].add(
                    auction.bidBalance[auction.slots[i + 1].winner]
                );
                auction.bidBalance[auction.slots[i + 1].winner] = 0;
            }
        }

        // Calculate DAO fee and deduct from auction revenue
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
        address sender = msg.sender;
        uint256 amount = auction.bidBalance[sender];

        require(amount > 0, "You have 0 deposited");
        require(
            auction.numberOfBids > auction.numberOfSlots,
            "Cannot withdraw winning bid!"
        );
        require(
            !isWinningBid(auctionId, amount),
            "Cannot withdraw winning bid!"
        );

        removeBid(auctionId, sender);
        IERC20 bidToken = IERC20(auction.bidToken);
        bidToken.transfer(sender, amount);

        emit LogBidWithdrawal(sender, auctionId, amount, block.timestamp);

        return true;
    }

    function withdrawEthBid(uint256 auctionId)
        external
        override
        onlyExistingAuction(auctionId)
        onlyAuctionStarted(auctionId)
        onlyAuctionNotCanceled(auctionId)
        onlyETH(auctionId)
        returns (bool)
    {
        Auction storage auction = auctions[auctionId];
        address payable recipient = msg.sender;
        uint256 amount = auction.bidBalance[recipient];

        require(amount > 0, "You have 0 deposited");
        require(
            auction.numberOfBids > auction.numberOfSlots,
            "Cannot withdraw winning bid!"
        );
        require(
            !isWinningBid(auctionId, amount),
            "Cannot withdraw winning bid!"
        );

        removeBid(auctionId, recipient);
        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Transfer failed.");

        emit LogBidWithdrawal(recipient, auctionId, amount, block.timestamp);

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
            withdrawERC721FromNonWinningSlot(auctionId, slotIndex, (i + 1));
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
        return auctions[auctionId].bidBalance[bidder];
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
            (bool success, ) =
                payable(auction.auctionOwner).call{value: amountToWithdraw}("");
            require(success, "Transfer failed.");
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
        require(_royaltyFeeMantissa < 1e17, "Should be less than 10%");
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
                        (bool success, ) =
                            recipients[j].call{value: interimFee.feeValue}("");
                        require(success, "Transfer failed.");
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
            (bool success, ) = payable(_to).call{value: amountToWithdraw}("");
            require(success, "Transfer failed.");
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

    function addBid(
        uint256 auctionId,
        address bidder,
        uint256 bid
    ) internal {
        require(auctions[auctionId].nextBidders[bidder] == address(0));
        address index = _findIndex(auctionId, bid);
        auctions[auctionId].bidBalance[bidder] = bid;
        auctions[auctionId].nextBidders[bidder] = auctions[auctionId]
            .nextBidders[index];
        auctions[auctionId].nextBidders[index] = bidder;
        auctions[auctionId].numberOfBids++;

        emit LogBidSubmitted(
            bidder,
            auctionId,
            bid,
            auctions[auctionId].bidBalance[bidder],
            block.timestamp
        );
    }

    function removeBid(uint256 auctionId, address bidder) internal {
        require(auctions[auctionId].nextBidders[bidder] != address(0));
        address previousBidder = _findPreviousBidder(auctionId, bidder);
        auctions[auctionId].nextBidders[previousBidder] = auctions[auctionId]
            .nextBidders[bidder];
        auctions[auctionId].nextBidders[bidder] = address(0);
        auctions[auctionId].bidBalance[bidder] = 0;
        auctions[auctionId].numberOfBids--;
    }

    function updateBid(
        uint256 auctionId,
        address bidder,
        uint256 newValue
    ) internal {
        require(auctions[auctionId].nextBidders[bidder] != address(0));
        address previousBidder = _findPreviousBidder(auctionId, bidder);
        address nextBidder = auctions[auctionId].nextBidders[bidder];
        if (_verifyIndex(auctionId, previousBidder, newValue, nextBidder)) {
            auctions[auctionId].bidBalance[bidder] = newValue;
        } else {
            removeBid(auctionId, bidder);
            addBid(auctionId, bidder, newValue);
        }
    }

    function getTopBidders(uint256 auctionId, uint256 n)
        public
        view
        returns (address[] memory)
    {
        require(n <= auctions[auctionId].numberOfBids);
        address[] memory biddersList = new address[](n);
        address currentAddress = auctions[auctionId].nextBidders[GUARD];
        for (uint256 i = 0; i < n; ++i) {
            biddersList[i] = currentAddress;
            currentAddress = auctions[auctionId].nextBidders[currentAddress];
        }

        return biddersList;
    }

    function isWinningBid(uint256 auctionId, uint256 bid)
        public
        view
        returns (bool)
    {
        address[] memory bidders =
            getTopBidders(auctionId, auctions[auctionId].numberOfSlots);
        uint256 lowestEligibleBid =
            auctions[auctionId].bidBalance[bidders[bidders.length - 1]];
        if (bid > lowestEligibleBid) {
            return true;
        } else {
            return false;
        }
    }

    function _verifyIndex(
        uint256 auctionId,
        address previousBidder,
        uint256 newValue,
        address nextBidder
    ) internal view returns (bool) {
        return
            (previousBidder == GUARD ||
                auctions[auctionId].bidBalance[previousBidder] >= newValue) &&
            (nextBidder == GUARD ||
                newValue > auctions[auctionId].bidBalance[nextBidder]);
    }

    function _findIndex(uint256 auctionId, uint256 newValue)
        internal
        view
        returns (address)
    {
        address addressToInsertAfter = GUARD;
        while (true) {
            if (
                _verifyIndex(
                    auctionId,
                    addressToInsertAfter,
                    newValue,
                    auctions[auctionId].nextBidders[addressToInsertAfter]
                )
            ) return addressToInsertAfter;
            addressToInsertAfter = auctions[auctionId].nextBidders[
                addressToInsertAfter
            ];
        }
    }

    function _isPreviousBidder(
        uint256 auctionId,
        address bidder,
        address previousBidder
    ) internal view returns (bool) {
        return auctions[auctionId].nextBidders[previousBidder] == bidder;
    }

    function _findPreviousBidder(uint256 auctionId, address bidder)
        internal
        view
        returns (address)
    {
        address currentAddress = GUARD;
        while (auctions[auctionId].nextBidders[currentAddress] != GUARD) {
            if (_isPreviousBidder(auctionId, bidder, currentAddress))
                return currentAddress;
            currentAddress = auctions[auctionId].nextBidders[currentAddress];
        }
        return address(0);
    }

    receive() external payable {
        uint256 latestAuctionId = totalAuctions;
        ethBid(latestAuctionId);
    }
}
