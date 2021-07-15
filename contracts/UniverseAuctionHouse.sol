// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721Holder.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./IUniverseAuctionHouse.sol";
import "./HasSecondarySaleFees.sol";

contract UniverseAuctionHouse is IUniverseAuctionHouse, ERC721Holder, ReentrancyGuard {
    using SafeMath for uint256;

    uint256 public totalAuctions;
    uint256 public maxNumberOfSlotsPerAuction;
    uint256 public royaltyFeeBps;
    uint256 public nftSlotLimit;
    address payable public daoAddress;

    mapping(uint256 => Auction) public auctions;
    mapping(uint256 => uint256) public auctionsRevenue;
    mapping(address => uint256) public royaltiesReserve;
    mapping(address => bool) public supportedBidTokens;

    bytes4 private constant _INTERFACE_ID_FEES = 0xb7799584;
    address private constant GUARD = address(1);

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

    event LogAuctionExtended(
        uint256 auctionId, 
        uint256 endTime, 
        uint256 time
    );

    event LogAuctionCanceled(
        uint256 auctionId, 
        uint256 time
    );

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

    modifier onlyExistingAuction(uint256 auctionId) {
        require(auctionId > 0 && auctionId <= totalAuctions, "Auction doesn't exist");
        _;
    }

    modifier onlyAuctionStarted(uint256 auctionId) {
        require(auctions[auctionId].startTime < block.timestamp, "Auction hasn't started");
        _;
    }

    modifier onlyAuctionNotStarted(uint256 auctionId) {
        require(auctions[auctionId].startTime > block.timestamp, "Auction has started");
        _;
    }

    modifier onlyAuctionNotCanceled(uint256 auctionId) {
        require(!auctions[auctionId].isCanceled, "Auction is canceled");
        _;
    }

    modifier onlyAuctionCanceled(uint256 auctionId) {
        require(auctions[auctionId].isCanceled, "Auction is not canceled");
        _;
    }

    modifier onlyValidBidAmount(uint256 bid) {
        require(bid > 0, "Bid amount must be higher than 0");
        _;
    }

    modifier onlyETH(uint256 auctionId) {
        require(auctions[auctionId].bidToken == address(0), "Token address provided");
        _;
    }

    modifier onlyERC20(uint256 auctionId) {
        require(auctions[auctionId].bidToken != address(0), "No token address provided");
        _;
    }

    modifier onlyIfWhitelistSupported(uint256 auctionId) {
        require(auctions[auctionId].supportsWhitelist, "Whitelisting should be supported");
        _;
    }

    modifier onlyAuctionOwner(uint256 auctionId) {
        require(auctions[auctionId].auctionOwner == msg.sender, "Only owner can whitelist");
        _;
    }

    modifier onlyDAO() {
        require(msg.sender == daoAddress, "Not called from the dao");
        _;
    }

    constructor(
        uint256 _maxNumberOfSlotsPerAuction,
        uint256 _nftSlotLimit,
        uint256 _royaltyFeeBps,
        address payable _daoAddress,
        address[] memory _supportedBidTokens
    ) {
        maxNumberOfSlotsPerAuction = _maxNumberOfSlotsPerAuction;
        nftSlotLimit = _nftSlotLimit;
        royaltyFeeBps = _royaltyFeeBps;
        daoAddress = _daoAddress;

        for (uint256 i = 0; i < _supportedBidTokens.length; i += 1) {
            supportedBidTokens[_supportedBidTokens[i]] = true;
        }
        supportedBidTokens[address(0)] = true;
    }

    function createAuction(AuctionConfig calldata config) external override returns (uint256) {
        uint256 currentTime = block.timestamp;

        require(
            currentTime < config.startTime &&
                config.startTime < config.endTime &&
                config.resetTimer > 0,
            "Wrong time config"
        );
        require(
            config.numberOfSlots > 0 && config.numberOfSlots <= maxNumberOfSlotsPerAuction,
            "Slots out of bound"
        );
        require(supportedBidTokens[config.bidToken], "Bid token is not supported");
        require(
            config.minimumReserveValues.length == 0 ||
                config.numberOfSlots == config.minimumReserveValues.length,
            "Incorrect number of slots"
        );

        uint256 auctionId = totalAuctions.add(1);

        auctions[auctionId].auctionOwner = msg.sender;
        auctions[auctionId].startTime = config.startTime;
        auctions[auctionId].endTime = config.endTime;
        auctions[auctionId].resetTimer = config.resetTimer;
        auctions[auctionId].numberOfSlots = config.numberOfSlots;
        auctions[auctionId].supportsWhitelist = config.addressesToWhitelist.length > 0
            ? true
            : false;
        auctions[auctionId].bidToken = config.bidToken;
        auctions[auctionId].nextBidders[GUARD] = GUARD;

        for (uint256 i = 0; i < config.addressesToWhitelist.length; i += 1) {
            auctions[auctionId].whitelistAddresses[config.addressesToWhitelist[i]] = true;
        }

        for (uint256 j = 0; j < config.minimumReserveValues.length; j += 1) {
            auctions[auctionId].slots[j + 1].reservePrice = config.minimumReserveValues[j];
        }

        uint256 checkSum = 0;
        for (uint256 k = 0; k < config.paymentSplits.length; k += 1) {
            require(config.paymentSplits[k].recipient != address(0), "Recipient should be present");
            require(config.paymentSplits[k].value != 0, "Fee value should be positive");
            checkSum += config.paymentSplits[k].value;
            auctions[auctionId].paymentSplits.push(config.paymentSplits[k]);
        }
        require(checkSum < 10000, "Splits should be less than 100%");

        totalAuctions = auctionId;

        emit LogAuctionCreated(
            auctionId,
            msg.sender,
            config.numberOfSlots,
            config.startTime,
            config.endTime,
            config.resetTimer,
            block.timestamp
        );

        return auctionId;
    }

    function batchDepositToAuction(
        uint256 auctionId,
        uint256[] calldata slotIndices,
        ERC721[][] calldata tokens
    )
        external
        override
        onlyExistingAuction(auctionId)
        onlyAuctionNotStarted(auctionId)
        onlyAuctionNotCanceled(auctionId)
        returns (bool)
    {
        Auction storage auction = auctions[auctionId];

        require(slotIndices.length <= auction.numberOfSlots, "Exceeding auction slots");
        require(slotIndices.length <= 10, "Slots should be no more than 10");
        require(slotIndices.length == tokens.length, "Slots should be equal to batches");

        for (uint256 i = 0; i < slotIndices.length; i += 1) {
            require(tokens[i].length <= 5, "Max 5 NFTs could be transferred");
            depositERC721(auctionId, slotIndices[i], tokens[i]);
        }

        return true;
    }

    function ethBid(uint256 auctionId)
        external
        payable
        override
        onlyExistingAuction(auctionId)
        onlyAuctionStarted(auctionId)
        onlyAuctionNotCanceled(auctionId)
        onlyETH(auctionId)
        onlyValidBidAmount(msg.value)
        nonReentrant
        returns (bool)
    {
        Auction storage auction = auctions[auctionId];

        require(block.timestamp < auction.endTime, "Auction has ended");
        require(auction.totalDepositedERC721s > 0, "No deposited NFTs in auction");

        uint256 bidderCurrentBalance = auction.bidBalance[msg.sender];

        // Check if this is first time bidding
        if (bidderCurrentBalance == 0) {
            // Add bid without checks if total bids are less than total slots
            if (auction.numberOfBids < auction.numberOfSlots) {
                addBid(auctionId, msg.sender, msg.value);

                // Check if slots are filled (we have more bids than slots)
            } else if (auction.numberOfBids >= auction.numberOfSlots) {
                // If slots are filled, check if the bid is within the winning slots
                require(isWinningBid(auctionId, msg.value), "Bid should be winnning");

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
                "Bid should be > next highest bid"
            );

            // Update bid directly without additional checks if total bids are less than total slots
            if (auction.numberOfBids < auction.numberOfSlots) {
                updateBid(auctionId, msg.sender, bidderCurrentBalance.add(msg.value));

                // If slots are filled, check if the current bidder balance + the new amount will be withing the winning slots
            } else if (auction.numberOfBids >= auction.numberOfSlots) {
                require(
                    isWinningBid(auctionId, bidderCurrentBalance.add(msg.value)),
                    "Bid should be winnning"
                );

                // Update the bid if the new incremented balance falls within the winning slots
                updateBid(auctionId, msg.sender, bidderCurrentBalance.add(msg.value));
                if (auction.endTime.sub(block.timestamp) < auction.resetTimer) {
                    // Extend the auction if the remaining time is less than the reset timer
                    extendAuction(auctionId);
                }
            }
        }
        return true;
    }

    function withdrawEthBid(uint256 auctionId)
        external
        override
        onlyExistingAuction(auctionId)
        onlyAuctionStarted(auctionId)
        onlyAuctionNotCanceled(auctionId)
        onlyETH(auctionId)
        nonReentrant
        returns (bool)
    {
        Auction storage auction = auctions[auctionId];
        address payable recipient = msg.sender;
        uint256 amount = auction.bidBalance[recipient];

        require(amount > 0, "You have 0 deposited");
        require(auction.numberOfBids > auction.numberOfSlots, "Can't withdraw winning bid");
        require(!isWinningBid(auctionId, amount), "Can't withdraw winning bid");

        removeBid(auctionId, recipient);
        emit LogBidWithdrawal(recipient, auctionId, amount, block.timestamp);

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Transfer failed");

        return true;
    }

    function erc20Bid(uint256 auctionId, uint256 amount)
        external
        override
        onlyExistingAuction(auctionId)
        onlyAuctionStarted(auctionId)
        onlyAuctionNotCanceled(auctionId)
        onlyERC20(auctionId)
        onlyValidBidAmount(amount)
        nonReentrant
        returns (bool)
    {
        Auction storage auction = auctions[auctionId];

        require(block.timestamp < auction.endTime, "Auction has ended");
        require(auction.totalDepositedERC721s > 0, "No deposited NFTs in auction");

        IERC20 bidToken = IERC20(auction.bidToken);

        uint256 bidderCurrentBalance = auction.bidBalance[msg.sender];

        // Check if this is first time bidding
        if (bidderCurrentBalance == 0) {
            // Add bid without checks if total bids are less than total slots
            if (auction.numberOfBids < auction.numberOfSlots) {
                addBid(auctionId, msg.sender, amount);
                require(
                    bidToken.transferFrom(msg.sender, address(this), amount),
                    "Transfer failed"
                );

                // Check if slots are filled (if we have more bids than slots)
            } else if (auction.numberOfBids >= auction.numberOfSlots) {
                // If slots are filled, check if the bid is within the winning slots
                require(isWinningBid(auctionId, amount), "Bid should be winnning");

                // Add bid only if it is within the winning slots
                addBid(auctionId, msg.sender, amount);
                require(
                    bidToken.transferFrom(msg.sender, address(this), amount),
                    "Transfer failed"
                );
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
                "Bid should be > next highest bid"
            );

            // Update bid directly without additional checks if total bids are less than total slots
            if (auction.numberOfBids < auction.numberOfSlots) {
                updateBid(auctionId, msg.sender, bidderCurrentBalance.add(amount));
                require(
                    bidToken.transferFrom(msg.sender, address(this), amount),
                    "Transfer failed"
                );

                // If slots are filled, check if the current bidder balance + the new amount will be withing the winning slots
            } else if (auction.numberOfBids >= auction.numberOfSlots) {
                require(
                    isWinningBid(auctionId, bidderCurrentBalance.add(amount)),
                    "Bid should be winnning"
                );

                // Update the bid if the new incremented balance falls within the winning slots
                updateBid(auctionId, msg.sender, bidderCurrentBalance.add(amount));
                require(
                    bidToken.transferFrom(msg.sender, address(this), amount),
                    "Transfer failed"
                );
                if (auction.endTime.sub(block.timestamp) < auction.resetTimer) {
                    // Extend the auction if the remaining time is less than the reset timer
                    extendAuction(auctionId);
                }
            }
        }
        return true;
    }

    function withdrawERC20Bid(uint256 auctionId)
        external
        override
        onlyExistingAuction(auctionId)
        onlyAuctionStarted(auctionId)
        onlyAuctionNotCanceled(auctionId)
        onlyERC20(auctionId)
        nonReentrant
        returns (bool)
    {
        Auction storage auction = auctions[auctionId];
        address sender = msg.sender;
        uint256 amount = auction.bidBalance[sender];

        require(amount > 0, "You have 0 deposited");
        require(auction.numberOfBids > auction.numberOfSlots, "Can't withdraw winning bid");
        require(!isWinningBid(auctionId, amount), "Can't withdraw winning bid");

        removeBid(auctionId, sender);
        IERC20 bidToken = IERC20(auction.bidToken);

        emit LogBidWithdrawal(sender, auctionId, amount, block.timestamp);

        require(bidToken.transfer(sender, amount), "Transfer Failed");

        return true;
    }

    function withdrawERC721FromNonWinningSlot(
        uint256 auctionId,
        uint256 slotIndex,
        uint256 amount
    )
        external
        override
        onlyExistingAuction(auctionId)
        onlyAuctionStarted(auctionId)
        onlyAuctionNotCanceled(auctionId)
        nonReentrant
        returns (bool)
    {
        Auction storage auction = auctions[auctionId];
        Slot storage nonWinningSlot = auction.slots[slotIndex];

        uint256 totalDeposited = nonWinningSlot.totalDepositedNfts;
        uint256 totalWithdrawn = nonWinningSlot.totalWithdrawnNfts;

        require(!auction.slots[slotIndex].reservePriceReached, "Reserve price met");

        require(auction.isFinalized, "Auction should be finalized");
        require(amount <= 40, "Can't withdraw more than 40");
        require(amount <= totalDeposited.sub(totalWithdrawn), "Not enough available");

        for (uint256 i = totalWithdrawn; i < amount.add(totalWithdrawn); i += 1) {
            _withdrawERC721FromNonWinningSlot(auctionId, slotIndex, (i + 1));
        }

        return true;
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
        // Upper bound for bidders.length is maxNumberOfSlotsPerAuction
        for (uint256 i = 0; i < bidders.length; i += 1) {
            for (
                lastAwardedIndex;
                lastAwardedIndex < auction.numberOfSlots;
                lastAwardedIndex += 1
            ) {
                if (
                    auction.bidBalance[bidders[i]] >=
                    auction.slots[lastAwardedIndex + 1].reservePrice
                ) {
                    auction.slots[lastAwardedIndex + 1].reservePriceReached = true;
                    auction.slots[lastAwardedIndex + 1].winningBidAmount = auction.bidBalance[
                        bidders[i]
                    ];
                    auction.slots[lastAwardedIndex + 1].winner = bidders[i];
                    auction.winners[lastAwardedIndex + 1] = auction
                    .slots[lastAwardedIndex + 1]
                    .winner;

                    emit LogBidMatched(
                        auctionId,
                        lastAwardedIndex + 1,
                        auction.slots[lastAwardedIndex + 1].reservePrice,
                        auction.slots[lastAwardedIndex + 1].winningBidAmount,
                        auction.slots[lastAwardedIndex + 1].winner,
                        block.timestamp
                    );

                    lastAwardedIndex += 1;

                    break;
                }
            }
        }

        auction.isFinalized = true;

        return true;
    }

    function captureSlotRevenue(uint256 auctionId, uint256 slotIndex)
        public
        override
        onlyExistingAuction(auctionId)
        onlyAuctionNotCanceled(auctionId)
        returns (bool)
    {
        Auction storage auction = auctions[auctionId];

        require(auction.isFinalized, "Not finalized");

        // Calculate the auction revenue from sold slots and reset bid balances
        if (auction.slots[slotIndex].reservePriceReached) {
            auctionsRevenue[auctionId] = auctionsRevenue[auctionId].add(
                auction.bidBalance[auction.slots[slotIndex].winner]
            );
            auction.bidBalance[auction.slots[slotIndex].winner] = 0;

            // Calculate the amount accounted for secondary sale fees
            if (auction.slots[slotIndex].totalDepositedNfts > 0) {
                uint256 _secondarySaleFeesForSlot = calculateSecondarySaleFees(
                    auctionId,
                    (slotIndex)
                );
                auctionsRevenue[auctionId] = auctionsRevenue[auctionId].sub(
                    _secondarySaleFeesForSlot
                );
            }
        }

        // Calculate DAO fee and deduct from auction revenue
        uint256 _royaltyFee = royaltyFeeBps.mul(auctionsRevenue[auctionId]).div(10000);
        auctionsRevenue[auctionId] = auctionsRevenue[auctionId].sub(_royaltyFee);
        royaltiesReserve[auction.bidToken] = royaltiesReserve[auction.bidToken].add(_royaltyFee);
        auction.slots[slotIndex].revenueCaptured = true;

        return true;
    }

    function captureSlotRevenueRange(
        uint256 auctionId,
        uint256 startSlotIndex,
        uint256 endSlotIndex
    )
        external
        override
        onlyExistingAuction(auctionId)
        onlyAuctionNotCanceled(auctionId)
        returns (bool)
    {
        require(
            startSlotIndex >= 1 && endSlotIndex <= auctions[auctionId].numberOfSlots,
            "Slots out of bound"
        );
        for (uint256 i = startSlotIndex; i <= endSlotIndex; i += 1) {
            captureSlotRevenue(auctionId, i);
        }
        return true;
    }

    function cancelAuction(uint256 auctionId)
        external
        override
        onlyExistingAuction(auctionId)
        onlyAuctionNotStarted(auctionId)
        onlyAuctionNotCanceled(auctionId)
        onlyAuctionOwner(auctionId)
        returns (bool)
    {
        auctions[auctionId].isCanceled = true;

        emit LogAuctionCanceled(auctionId, block.timestamp);

        return true;
    }

    function distributeCapturedAuctionRevenue(uint256 auctionId)
        external
        override
        onlyExistingAuction(auctionId)
        nonReentrant
        returns (bool)
    {
        Auction storage auction = auctions[auctionId];
        require(auction.isFinalized, "Not finalized");

        uint256 amountToWithdraw = auctionsRevenue[auctionId];
        uint256 value = amountToWithdraw;
        uint256 paymentSplitsPaid;

        auctionsRevenue[auctionId] = 0;

        emit LogAuctionRevenueWithdrawal(
            auction.auctionOwner,
            auctionId,
            amountToWithdraw,
            block.timestamp
        );

        // Distribute the payment splits to the respective recipients
        for (uint256 i = 0; i < auction.paymentSplits.length && i < 5; i += 1) {
            Fee memory interimFee = subFee(
                value,
                amountToWithdraw.mul(auction.paymentSplits[i].value).div(10000)
            );
            value = interimFee.remainingValue;
            paymentSplitsPaid = paymentSplitsPaid.add(interimFee.feeValue);

            if (auction.bidToken == address(0) && interimFee.feeValue > 0) {
                (bool success, ) = auction.paymentSplits[i].recipient.call{value: interimFee.feeValue}("");
                require(success, "Transfer failed");
            }

            if (auction.bidToken != address(0) && interimFee.feeValue > 0) {
                IERC20 token = IERC20(auction.bidToken);
                require(
                    token.transfer(
                        address(auction.paymentSplits[i].recipient),
                        interimFee.feeValue
                    ),
                    "Transfer Failed"
                );
            }
        }

        // Distribute the remaining revenue to the auction owner
        if (auction.bidToken == address(0)) {
            (bool success, ) = payable(auction.auctionOwner).call{value: amountToWithdraw.sub(paymentSplitsPaid)}("");
            require(success, "Transfer failed");
        }

        if (auction.bidToken != address(0)) {
            IERC20 bidToken = IERC20(auction.bidToken);
            require(
                bidToken.transfer(auction.auctionOwner, amountToWithdraw.sub(paymentSplitsPaid)),
                "Transfer Failed"
            );
        }

        return true;
    }

    function claimERC721Rewards(
        uint256 auctionId,
        uint256 slotIndex,
        uint256 amount
    ) external override nonReentrant returns (bool) {
        address claimer = msg.sender;

        Auction storage auction = auctions[auctionId];
        Slot storage winningSlot = auction.slots[slotIndex];

        uint256 totalDeposited = winningSlot.totalDepositedNfts;
        uint256 totalWithdrawn = winningSlot.totalWithdrawnNfts;

        require(auction.isFinalized && winningSlot.revenueCaptured, "Not finalized");
        require(auction.winners[slotIndex] == claimer, "Only winner can claim");
        require(winningSlot.reservePriceReached, "Reserve price not met");

        require(amount <= 40, "More than 40 NFTs");
        require(amount <= totalDeposited.sub(totalWithdrawn), "Can't claim more than available");

        emit LogERC721RewardsClaim(claimer, auctionId, slotIndex, block.timestamp);

        for (uint256 i = totalWithdrawn; i < amount.add(totalWithdrawn); i += 1) {
            DepositedERC721 memory nftForWithdrawal = winningSlot.depositedNfts[i + 1];

            auction.totalWithdrawnERC721s = auction.totalWithdrawnERC721s.add(1);
            auction.slots[slotIndex].totalWithdrawnNfts = auction
            .slots[slotIndex]
            .totalWithdrawnNfts
            .add(1);

            if (nftForWithdrawal.tokenId != 0) {
                IERC721(nftForWithdrawal.tokenAddress).safeTransferFrom(
                    address(this),
                    claimer,
                    nftForWithdrawal.tokenId
                );
            }
        }

        return true;
    }

    function distributeSecondarySaleFees(
        uint256 auctionId,
        uint256 slotIndex,
        uint256 nftSlotIndex
    ) external override nonReentrant returns (bool) {
        Auction storage auction = auctions[auctionId];
        Slot storage slot = auction.slots[slotIndex];
        DepositedERC721 storage nft = slot.depositedNfts[nftSlotIndex];

        require(nft.hasSecondarySaleFees && !nft.feesPaid, "Not supported/Fees already paid");
        require(slot.revenueCaptured, "Slot revenue should be captured");

        uint256 averageERC721SalePrice = slot.winningBidAmount.div(slot.totalDepositedNfts);

        HasSecondarySaleFees withFees = HasSecondarySaleFees(nft.tokenAddress);
        address payable[] memory recipients = withFees.getFeeRecipients(nft.tokenId);
        uint256[] memory fees = withFees.getFeeBps(nft.tokenId);
        require(fees.length == recipients.length, "Splits should be equal");
        uint256 value = averageERC721SalePrice;
        nft.feesPaid = true;

        for (uint256 i = 0; i < fees.length && i < 5; i += 1) {
            Fee memory interimFee = subFee(value, averageERC721SalePrice.mul(fees[i]).div(10000));
            value = interimFee.remainingValue;

            if (auction.bidToken == address(0) && interimFee.feeValue > 0) {
                (bool success, ) = recipients[i].call{value: interimFee.feeValue}("");
                require(success, "Transfer failed");
            }

            if (auction.bidToken != address(0) && interimFee.feeValue > 0) {
                IERC20 token = IERC20(auction.bidToken);
                require(
                    token.transfer(address(recipients[i]), interimFee.feeValue),
                    "Transfer Failed"
                );
            }
        }

        return true;
    }

    function distributeRoyalties(address token)
        external
        override
        onlyDAO
        nonReentrant
        returns (uint256)
    {
        uint256 amountToWithdraw = royaltiesReserve[token];
        require(amountToWithdraw > 0, "Amount is 0");

        royaltiesReserve[token] = 0;

        emit LogRoyaltiesWithdrawal(amountToWithdraw, daoAddress, token, block.timestamp);

        if (token == address(0)) {
            (bool success, ) = payable(daoAddress).call{value: amountToWithdraw}("");
            require(success, "Transfer failed");
        }

        if (token != address(0)) {
            IERC20 erc20token = IERC20(token);
            require(erc20token.transfer(daoAddress, amountToWithdraw), "Transfer Failed");
        }

        return amountToWithdraw;
    }

    function setRoyaltyFeeBps(uint256 _royaltyFeeBps) external override onlyDAO returns (uint256) {
        royaltyFeeBps = _royaltyFeeBps;
        return royaltyFeeBps;
    }

    function setNftSlotLimit(uint256 _nftSlotLimit) external override onlyDAO returns (uint256) {
        nftSlotLimit = _nftSlotLimit;
        return nftSlotLimit;
    }

    function setSupportedBidToken(address erc20token, bool value)
        external
        override
        onlyDAO
        returns (address, bool)
    {
        supportedBidTokens[erc20token] = value;
        return (erc20token, value);
    }

    function getDepositedNftsInSlot(uint256 auctionId, uint256 slotIndex)
        external
        view
        override
        onlyExistingAuction(auctionId)
        returns (DepositedERC721[] memory)
    {
        uint256 nftsInSlot = auctions[auctionId].slots[slotIndex].totalDepositedNfts;

        DepositedERC721[] memory nfts = new DepositedERC721[](nftsInSlot);

        for (uint256 i = 0; i < nftsInSlot; i += 1) {
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

    function getMinimumReservePriceForSlot(uint256 auctionId, uint256 slotIndex)
        external
        view
        override
        returns (uint256)
    {
        return auctions[auctionId].slots[slotIndex].reservePrice;
    }

    function depositERC721(
        uint256 auctionId,
        uint256 slotIndex,
        ERC721[] calldata tokens
    )
        public
        override
        onlyExistingAuction(auctionId)
        onlyAuctionNotStarted(auctionId)
        onlyAuctionNotCanceled(auctionId)
        returns (uint256[] memory)
    {
        uint256[] memory nftSlotIndexes = new uint256[](tokens.length);

        require(
            !auctions[auctionId].supportsWhitelist ||
                auctions[auctionId].whitelistAddresses[msg.sender],
            "You are not allowed to deposit"
        );
        require(
            auctions[auctionId].numberOfSlots >= slotIndex && slotIndex > 0,
            "Deposit into a non-existing slot"
        );
        require((tokens.length <= 40), "Cannot deposit more than 40");
        require(
            (auctions[auctionId].slots[slotIndex].totalDepositedNfts + tokens.length <= nftSlotLimit),
            "Nfts slot limit exceeded"
        );

        for (uint256 i = 0; i < tokens.length; i += 1) {
            nftSlotIndexes[i] = _depositERC721(
                auctionId,
                slotIndex,
                tokens[i].tokenId,
                tokens[i].tokenAddress
            );
        }

        return nftSlotIndexes;
    }

    function withdrawDepositedERC721(
        uint256 auctionId,
        uint256 slotIndex,
        uint256 nftSlotIndex
    ) public override onlyExistingAuction(auctionId) onlyAuctionCanceled(auctionId) returns (bool) {
        Auction storage auction = auctions[auctionId];
        DepositedERC721 memory nftForWithdrawal = auction.slots[slotIndex].depositedNfts[
            nftSlotIndex
        ];

        require(msg.sender == nftForWithdrawal.depositor, "Only depositor can withdraw");

        delete auction.slots[slotIndex].depositedNfts[nftSlotIndex];

        auction.totalWithdrawnERC721s = auction.totalWithdrawnERC721s.add(1);
        auction.slots[slotIndex].totalWithdrawnNfts = auction
        .slots[slotIndex]
        .totalWithdrawnNfts
        .add(1);

        emit LogERC721Withdrawal(
            msg.sender,
            nftForWithdrawal.tokenAddress,
            nftForWithdrawal.tokenId,
            auctionId,
            slotIndex,
            nftSlotIndex,
            block.timestamp
        );

        IERC721(nftForWithdrawal.tokenAddress).safeTransferFrom(
            address(this),
            nftForWithdrawal.depositor,
            nftForWithdrawal.tokenId
        );

        return true;
    }

    function getTopBidders(uint256 auctionId, uint256 n)
        public
        view
        override
        returns (address[] memory)
    {
        require(n <= auctions[auctionId].numberOfBids, "N should be lower");
        address[] memory biddersList = new address[](n);
        address currentAddress = auctions[auctionId].nextBidders[GUARD];
        for (uint256 i = 0; i < n; ++i) {
            biddersList[i] = currentAddress;
            currentAddress = auctions[auctionId].nextBidders[currentAddress];
        }

        return biddersList;
    }

    function isWinningBid(uint256 auctionId, uint256 bid) public view override returns (bool) {
        address[] memory bidders = getTopBidders(auctionId, auctions[auctionId].numberOfSlots);
        uint256 lowestEligibleBid = auctions[auctionId].bidBalance[bidders[bidders.length - 1]];
        if (bid > lowestEligibleBid) {
            return true;
        } else {
            return false;
        }
    }

    function _depositERC721(
        uint256 auctionId,
        uint256 slotIndex,
        uint256 tokenId,
        address tokenAddress
    ) internal returns (uint256) {
        require(tokenAddress != address(0), "Zero address was provided");

        DepositedERC721 memory item = DepositedERC721({
            tokenId: tokenId,
            tokenAddress: tokenAddress,
            depositor: msg.sender,
            hasSecondarySaleFees: IERC721(tokenAddress).supportsInterface(_INTERFACE_ID_FEES),
            feesPaid: false
        });

        uint256 nftSlotIndex = auctions[auctionId].slots[slotIndex].totalDepositedNfts.add(1);

        auctions[auctionId].slots[slotIndex].depositedNfts[nftSlotIndex] = item;
        auctions[auctionId].slots[slotIndex].totalDepositedNfts = nftSlotIndex;
        auctions[auctionId].totalDepositedERC721s = auctions[auctionId].totalDepositedERC721s.add(
            1
        );

        emit LogERC721Deposit(
            msg.sender,
            tokenAddress,
            tokenId,
            auctionId,
            slotIndex,
            nftSlotIndex,
            block.timestamp
        );

        IERC721(tokenAddress).safeTransferFrom(msg.sender, address(this), tokenId);

        return nftSlotIndex;
    }

    function _withdrawERC721FromNonWinningSlot(
        uint256 auctionId,
        uint256 slotIndex,
        uint256 nftSlotIndex
    ) internal returns (bool) {
        Auction storage auction = auctions[auctionId];
        DepositedERC721 memory nftForWithdrawal = auction.slots[slotIndex].depositedNfts[
            nftSlotIndex
        ];

        require(msg.sender == nftForWithdrawal.depositor, "Only depositor can withdraw");

        auction.totalWithdrawnERC721s = auction.totalWithdrawnERC721s.add(1);
        auction.slots[slotIndex].totalWithdrawnNfts = auction
        .slots[slotIndex]
        .totalWithdrawnNfts
        .add(1);

        emit LogERC721Withdrawal(
            msg.sender,
            nftForWithdrawal.tokenAddress,
            nftForWithdrawal.tokenId,
            auctionId,
            slotIndex,
            nftSlotIndex,
            block.timestamp
        );

        IERC721(nftForWithdrawal.tokenAddress).safeTransferFrom(
            address(this),
            nftForWithdrawal.depositor,
            nftForWithdrawal.tokenId
        );

        return true;
    }

    function extendAuction(uint256 auctionId) internal returns (bool) {
        Auction storage auction = auctions[auctionId];

        require(block.timestamp < auction.endTime, "Can't extend auction if ended");

        uint256 resetTimer = auction.resetTimer;
        auction.endTime = auction.endTime.add(resetTimer);

        emit LogAuctionExtended(auctionId, auction.endTime, block.timestamp);

        return true;
    }

    function addBid(
        uint256 auctionId,
        address bidder,
        uint256 bid
    ) internal {
        require(
            auctions[auctionId].nextBidders[bidder] == address(0),
            "Next bidder should be address 0"
        );
        address index = _findIndex(auctionId, bid);
        auctions[auctionId].bidBalance[bidder] = bid;
        auctions[auctionId].nextBidders[bidder] = auctions[auctionId].nextBidders[index];
        auctions[auctionId].nextBidders[index] = bidder;
        auctions[auctionId].numberOfBids += 1;

        emit LogBidSubmitted(
            bidder,
            auctionId,
            bid,
            auctions[auctionId].bidBalance[bidder],
            block.timestamp
        );
    }

    function removeBid(uint256 auctionId, address bidder) internal {
        require(auctions[auctionId].nextBidders[bidder] != address(0), "Address 0 provided");
        address previousBidder = _findPreviousBidder(auctionId, bidder);
        auctions[auctionId].nextBidders[previousBidder] = auctions[auctionId].nextBidders[bidder];
        auctions[auctionId].nextBidders[bidder] = address(0);
        auctions[auctionId].bidBalance[bidder] = 0;
        auctions[auctionId].numberOfBids -= 1;
    }

    function updateBid(
        uint256 auctionId,
        address bidder,
        uint256 newValue
    ) internal {
        require(auctions[auctionId].nextBidders[bidder] != address(0), "Address 0 provided");
        address previousBidder = _findPreviousBidder(auctionId, bidder);
        address nextBidder = auctions[auctionId].nextBidders[bidder];
        if (_verifyIndex(auctionId, previousBidder, newValue, nextBidder)) {
            auctions[auctionId].bidBalance[bidder] = newValue;
        } else {
            removeBid(auctionId, bidder);
            addBid(auctionId, bidder, newValue);
        }
    }

    function calculateSecondarySaleFees(uint256 auctionId, uint256 slotIndex)
        internal
        view
        returns (uint256)
    {
        Slot storage slot = auctions[auctionId].slots[slotIndex];

        require(slot.winningBidAmount > 0, "Winning bid should be > 0");

        uint256 averageERC721SalePrice = slot.winningBidAmount.div(slot.totalDepositedNfts);

        uint256 totalFeesPayableForSlot = 0;

        for (uint256 i = 0; i < slot.totalDepositedNfts; i += 1) {
            DepositedERC721 memory nft = slot.depositedNfts[i + 1];

            if (nft.hasSecondarySaleFees) {
                HasSecondarySaleFees withFees = HasSecondarySaleFees(nft.tokenAddress);
                address payable[] memory recipients = withFees.getFeeRecipients(nft.tokenId);
                uint256[] memory fees = withFees.getFeeBps(nft.tokenId);
                require(fees.length == recipients.length, "Splits number should be equal");
                uint256 value = averageERC721SalePrice;

                for (uint256 j = 0; j < fees.length && j < 5; j += 1) {
                    Fee memory interimFee = subFee(
                        value,
                        averageERC721SalePrice.mul(fees[j]).div(10000)
                    );
                    value = interimFee.remainingValue;
                    totalFeesPayableForSlot = totalFeesPayableForSlot.add(interimFee.feeValue);
                }
            }
        }

        return totalFeesPayableForSlot;
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
            (nextBidder == GUARD || newValue > auctions[auctionId].bidBalance[nextBidder]);
    }

    function _findIndex(uint256 auctionId, uint256 newValue) internal view returns (address) {
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
            addressToInsertAfter = auctions[auctionId].nextBidders[addressToInsertAfter];
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
            if (_isPreviousBidder(auctionId, bidder, currentAddress)) return currentAddress;
            currentAddress = auctions[auctionId].nextBidders[currentAddress];
        }
        return address(0);
    }

    function subFee(uint256 value, uint256 fee) internal pure returns (Fee memory interimFee) {
        if (value > fee) {
            interimFee.remainingValue = value - fee;
            interimFee.feeValue = fee;
        } else {
            interimFee.remainingValue = 0;
            interimFee.feeValue = value;
        }
    }
}
