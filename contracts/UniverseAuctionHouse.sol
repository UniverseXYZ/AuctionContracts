// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@universe/marketplace/contracts/interfaces/IRoyaltiesProvider.sol";
import "@universe/marketplace/contracts/lib/LibPart.sol";
import "./IUniverseAuctionHouse.sol";

contract UniverseAuctionHouse is IUniverseAuctionHouse, ERC721HolderUpgradeable, ReentrancyGuardUpgradeable {
    using SafeMathUpgradeable for uint256;

    uint256 public totalAuctions;
    uint256 public maxNumberOfSlotsPerAuction;
    uint256 public royaltyFeeBps;
    uint256 public nftSlotLimit;
    address payable public daoAddress;

    mapping(uint256 => Auction) public auctions;
    mapping(uint256 => uint256) public auctionsRevenue;
    mapping(address => uint256) public royaltiesReserve;
    mapping(address => bool) public supportedBidTokens;

    IRoyaltiesProvider public royaltiesRegistry;
    address private constant GUARD = address(1);

    event LogERC721Deposit(
        address depositor,
        address tokenAddress,
        uint256 tokenId,
        uint256 auctionId,
        uint256 slotIndex,
        uint256 nftSlotIndex
    );

    event LogERC721Withdrawal(
        address depositor,
        address tokenAddress,
        uint256 tokenId,
        uint256 auctionId,
        uint256 slotIndex,
        uint256 nftSlotIndex
    );

    event LogAuctionCreated(
        uint256 auctionId,
        address auctionOwner,
        uint256 numberOfSlots,
        uint256 startTime,
        uint256 endTime,
        uint256 resetTimer
    );

    event LogBidSubmitted(
        address sender,
        uint256 auctionId,
        uint256 currentBid,
        uint256 totalBid
    );

    event LogBidWithdrawal(
        address recipient, 
        uint256 auctionId, 
        uint256 amount
    );

    event LogBidMatched(
        uint256 auctionId,
        uint256 slotIndex,
        uint256 slotReservePrice,
        uint256 winningBidAmount,
        address winner
    );

    event LogAuctionExtended(
        uint256 auctionId, 
        uint256 endTime
    );

    event LogAuctionCanceled(
        uint256 auctionId
    );

    event LogAuctionRevenueWithdrawal(
        address recipient,
        uint256 auctionId,
        uint256 amount
    );

    event LogERC721RewardsClaim(
        address claimer,
        uint256 auctionId,
        uint256 slotIndex
    );

    event LogRoyaltiesWithdrawal(
        uint256 amount, 
        address to, 
        address token
    );

    event LogSlotRevenueCaptured(
        uint256 auctionId,
        uint256 slotIndex,
        uint256 amount,
        address bidToken
    );

    event LogAuctionFinalized(
        uint256 auctionId
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
        require(auctions[auctionId].isCanceled, "Auction not canceled");
        _;
    }

    modifier onlyAuctionOwner(uint256 auctionId) {
        require(auctions[auctionId].auctionOwner == msg.sender, "Only auction owner");
        _;
    }

    modifier onlyDAO() {
        require(msg.sender == daoAddress, "Not called from the dao");
        _;
    }

    function __UniverseAuctionHouse_init(
        uint256 _maxNumberOfSlotsPerAuction,
        uint256 _nftSlotLimit,
        uint256 _royaltyFeeBps,
        address payable _daoAddress,
        address[] memory _supportedBidTokens,
        IRoyaltiesProvider _royaltiesRegistry
    ) external initializer {
        __ERC721Holder_init();
        __ReentrancyGuard_init();
        
        maxNumberOfSlotsPerAuction = _maxNumberOfSlotsPerAuction;
        nftSlotLimit = _nftSlotLimit;
        royaltyFeeBps = _royaltyFeeBps;
        daoAddress = _daoAddress;
        royaltiesRegistry = _royaltiesRegistry;

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
        require(supportedBidTokens[config.bidToken], "Bid token not supported");
        require(
            config.minimumReserveValues.length == 0 ||
                config.numberOfSlots == config.minimumReserveValues.length,
            "Incorrect number of slots"
        );
        // Ensure minimum reserve values are lower for descending slot numbers
        for (uint256 i = 1; i < config.minimumReserveValues.length; i += 1) {
            require(config.minimumReserveValues[i - 1] >= config.minimumReserveValues[i], "Invalid reserve value") ;
        }

        uint256 auctionId = totalAuctions.add(1);

        auctions[auctionId].auctionOwner = msg.sender;
        auctions[auctionId].startTime = config.startTime;
        auctions[auctionId].endTime = config.endTime;
        auctions[auctionId].resetTimer = config.resetTimer;
        auctions[auctionId].numberOfSlots = config.numberOfSlots;

        auctions[auctionId].bidToken = config.bidToken;
        auctions[auctionId].nextBidders[GUARD] = GUARD;

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
            config.resetTimer
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
    {
        Auction storage auction = auctions[auctionId];

        require(slotIndices.length <= auction.numberOfSlots && 
                slotIndices.length <= 10 && 
                slotIndices.length == tokens.length, "Incorrect auction slots");

        for (uint256 i = 0; i < slotIndices.length; i += 1) {
            require(tokens[i].length <= 5, "Max 5 NFTs could be transferred");
            depositERC721(auctionId, slotIndices[i], tokens[i]);
        }

    }

    function ethBid(uint256 auctionId)
        external
        payable
        override
        onlyExistingAuction(auctionId)
        onlyAuctionStarted(auctionId)
        onlyAuctionNotCanceled(auctionId)
        nonReentrant
    {
        Auction storage auction = auctions[auctionId];

        require(block.timestamp < auction.endTime, "Auction has ended");
        require(auction.totalDepositedERC721s > 0 && msg.value > 0, "Invalid bid");

        uint256 bidderCurrentBalance = auction.bidBalance[msg.sender];

        // Check if this is first time bidding
        if (bidderCurrentBalance == 0) {
            // If total bids are less than total slots, add bid without checking if the bid is within the winning slots (isWinningBid())
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
                msg.value.add(bidderCurrentBalance) > auction.bidBalance[previousBidder],
                "Bid should be > next highest bid"
            );

            // If total bids are less than total slots update the bid directly
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
    }

    function withdrawEthBid(uint256 auctionId)
        external
        override
        onlyExistingAuction(auctionId)
        onlyAuctionStarted(auctionId)
        nonReentrant
    {
        Auction storage auction = auctions[auctionId];
        address payable recipient = msg.sender;
        uint256 amount = auction.bidBalance[recipient];

        require(auction.numberOfBids > auction.numberOfSlots, "Can't withdraw bid");
        require(canWithdrawBid(auctionId, recipient), "Can't withdraw bid");

        removeBid(auctionId, recipient);
        emit LogBidWithdrawal(recipient, auctionId, amount);

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Failed");

    }

    function erc20Bid(uint256 auctionId, uint256 amount)
        external
        override
        onlyExistingAuction(auctionId)
        onlyAuctionStarted(auctionId)
        onlyAuctionNotCanceled(auctionId)
        nonReentrant
    {
        Auction storage auction = auctions[auctionId];

        require(block.timestamp < auction.endTime, "Auction has ended");
        require(auction.totalDepositedERC721s > 0 && amount > 0, "Invalid bid");

        IERC20Upgradeable bidToken = IERC20Upgradeable(auction.bidToken);

        uint256 bidderCurrentBalance = auction.bidBalance[msg.sender];

        // Check if this is first time bidding
        if (bidderCurrentBalance == 0) {
            // If total bids are less than total slots, add bid without checking if the bid is within the winning slots (isWinningBid())
            if (auction.numberOfBids < auction.numberOfSlots) {
                require(
                    bidToken.transferFrom(msg.sender, address(this), amount),
                    "Failed"
                );
                addBid(auctionId, msg.sender, amount);

                // Check if slots are filled (if we have more bids than slots)
            } else if (auction.numberOfBids >= auction.numberOfSlots) {
                // If slots are filled, check if the bid is within the winning slots
                require(isWinningBid(auctionId, amount), "Bid should be winnning");
                require(
                    bidToken.transferFrom(msg.sender, address(this), amount),
                    "Failed"
                );

                // Add bid only if it is within the winning slots
                addBid(auctionId, msg.sender, amount);

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
                amount.add(bidderCurrentBalance) > auction.bidBalance[previousBidder],
                "Bid should be > next highest bid"
            );

            // If total bids are less than total slots update the bid directly
            if (auction.numberOfBids < auction.numberOfSlots) {
                require(
                    bidToken.transferFrom(msg.sender, address(this), amount),
                    "Failed"
                );
                updateBid(auctionId, msg.sender, bidderCurrentBalance.add(amount));

                // If slots are filled, check if the current bidder balance + the new amount will be withing the winning slots
            } else if (auction.numberOfBids >= auction.numberOfSlots) {
                require(
                    isWinningBid(auctionId, bidderCurrentBalance.add(amount)),
                    "Bid should be winnning"
                );
                require(
                    bidToken.transferFrom(msg.sender, address(this), amount),
                    "Failed"
                );
                // Update the bid if the new incremented balance falls within the winning slots
                updateBid(auctionId, msg.sender, bidderCurrentBalance.add(amount));

                if (auction.endTime.sub(block.timestamp) < auction.resetTimer) {
                    // Extend the auction if the remaining time is less than the reset timer
                    extendAuction(auctionId);
                }
            }
        }
    }

    function withdrawERC20Bid(uint256 auctionId)
        external
        override
        onlyExistingAuction(auctionId)
        onlyAuctionStarted(auctionId)
        nonReentrant
    {
        Auction storage auction = auctions[auctionId];
        address sender = msg.sender;
        uint256 amount = auction.bidBalance[sender];

        require(auction.numberOfBids > auction.numberOfSlots, "Can't withdraw bid");
        require(canWithdrawBid(auctionId, sender), "Can't withdraw bid");

        removeBid(auctionId, sender);
        IERC20Upgradeable bidToken = IERC20Upgradeable(auction.bidToken);

        emit LogBidWithdrawal(sender, auctionId, amount);

        require(bidToken.transfer(sender, amount), "Failed");

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
        nonReentrant
    {
        Auction storage auction = auctions[auctionId];
        Slot storage nonWinningSlot = auction.slots[slotIndex];

        uint256 totalDeposited = nonWinningSlot.totalDepositedNfts;
        uint256 totalWithdrawn = nonWinningSlot.totalWithdrawnNfts;

        require(!nonWinningSlot.reservePriceReached, "Reserve price met");

        require(auction.isFinalized, "Auction should be finalized");
        require(amount <= 40, "Can't withdraw more than 40");
        require(amount <= totalDeposited.sub(totalWithdrawn), "Not enough available");

        for (uint256 i = totalWithdrawn; i < amount.add(totalWithdrawn); i += 1) {
            _withdrawERC721FromNonWinningSlot(auctionId, slotIndex, (i + 1));
        }

    }

    function finalizeAuction(uint256 auctionId)
        external
        override
        onlyExistingAuction(auctionId)
        onlyAuctionNotCanceled(auctionId)
        nonReentrant
    {
        Auction storage auction = auctions[auctionId];

        require(
            block.timestamp > auction.endTime && !auction.isFinalized,
            "Auction not finished"
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
                    auction.winners[lastAwardedIndex + 1] = bidders[i];

                    emit LogBidMatched(
                        auctionId,
                        lastAwardedIndex + 1,
                        auction.slots[lastAwardedIndex + 1].reservePrice,
                        auction.slots[lastAwardedIndex + 1].winningBidAmount,
                        auction.slots[lastAwardedIndex + 1].winner
                    );

                    lastAwardedIndex += 1;

                    break;
                }
            }
        }

        auction.isFinalized = true;

        emit LogAuctionFinalized(auctionId);

    }

    function captureSlotRevenue(uint256 auctionId, uint256 slotIndex)
        public
        override
        onlyExistingAuction(auctionId)
        onlyAuctionNotCanceled(auctionId)
    {
        Auction storage auction = auctions[auctionId];

        require(auction.isFinalized && !auction.slots[slotIndex].revenueCaptured, "Not finalized/Already captured");
        require(auction.numberOfSlots >= slotIndex && slotIndex > 0, "Non-existing slot");

        uint256 slotRevenue = auction.bidBalance[auction.slots[slotIndex].winner];
        uint256 _secondarySaleFeesForSlot;

        // Calculate the auction revenue from sold slots and reset bid balances
        if (auction.slots[slotIndex].reservePriceReached) {
            auctionsRevenue[auctionId] = auctionsRevenue[auctionId].add(slotRevenue);
            auction.bidBalance[auction.slots[slotIndex].winner] = 0;

            // Calculate the amount accounted for secondary sale fees
            if (auction.slots[slotIndex].totalDepositedNfts > 0 && auction.slots[slotIndex].winningBidAmount > 0) {
                _secondarySaleFeesForSlot = calculateSecondarySaleFees(
                    auctionId,
                    (slotIndex)
                );
                auctionsRevenue[auctionId] = auctionsRevenue[auctionId].sub(
                    _secondarySaleFeesForSlot
                );
            }
        }

        // Calculate DAO fee and deduct from auction revenue
        uint256 _royaltyFee = royaltyFeeBps.mul(slotRevenue).div(10000);
        auctionsRevenue[auctionId] = auctionsRevenue[auctionId].sub(_royaltyFee);
        royaltiesReserve[auction.bidToken] = royaltiesReserve[auction.bidToken].add(_royaltyFee);
        auction.slots[slotIndex].revenueCaptured = true;

        emit LogSlotRevenueCaptured(
            auctionId,
            slotIndex,
            slotRevenue.sub(_secondarySaleFeesForSlot).sub(_royaltyFee),
            auction.bidToken
        );

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
    {
        require(
            startSlotIndex >= 1 && endSlotIndex <= auctions[auctionId].numberOfSlots,
            "Slots out of bound"
        );
        for (uint256 i = startSlotIndex; i <= endSlotIndex; i += 1) {
            captureSlotRevenue(auctionId, i);
        }
    }

    function cancelAuction(uint256 auctionId)
        external
        override
        onlyExistingAuction(auctionId)
        onlyAuctionNotStarted(auctionId)
        onlyAuctionNotCanceled(auctionId)
        onlyAuctionOwner(auctionId)
    {
        auctions[auctionId].isCanceled = true;

        emit LogAuctionCanceled(auctionId);

    }

    function distributeCapturedAuctionRevenue(uint256 auctionId)
        external
        override
        onlyExistingAuction(auctionId)
        nonReentrant
    {
        Auction storage auction = auctions[auctionId];
        require(auction.isFinalized, "Not finalized");

        uint256 amountToWithdraw = auctionsRevenue[auctionId];
        require(amountToWithdraw > 0, "Amount is 0");

        uint256 value = amountToWithdraw;
        uint256 paymentSplitsPaid;

        auctionsRevenue[auctionId] = 0;

        emit LogAuctionRevenueWithdrawal(
            auction.auctionOwner,
            auctionId,
            amountToWithdraw
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
                require(success, "Failed");
            }

            if (auction.bidToken != address(0) && interimFee.feeValue > 0) {
                IERC20Upgradeable token = IERC20Upgradeable(auction.bidToken);
                require(
                    token.transfer(
                        address(auction.paymentSplits[i].recipient),
                        interimFee.feeValue
                    ),
                    "Failed"
                );
            }
        }

        // Distribute the remaining revenue to the auction owner
        if (auction.bidToken == address(0)) {
            (bool success, ) = payable(auction.auctionOwner).call{value: amountToWithdraw.sub(paymentSplitsPaid)}("");
            require(success, "Failed");
        }

        if (auction.bidToken != address(0)) {
            IERC20Upgradeable bidToken = IERC20Upgradeable(auction.bidToken);
            require(
                bidToken.transfer(auction.auctionOwner, amountToWithdraw.sub(paymentSplitsPaid)),
                "Failed"
            );
        }

    }

    function claimERC721Rewards(
        uint256 auctionId,
        uint256 slotIndex,
        uint256 amount
    ) external override nonReentrant {
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

        emit LogERC721RewardsClaim(claimer, auctionId, slotIndex);

        for (uint256 i = totalWithdrawn; i < amount.add(totalWithdrawn); i += 1) {
            DepositedERC721 memory nftForWithdrawal = winningSlot.depositedNfts[i + 1];

            auction.totalWithdrawnERC721s = auction.totalWithdrawnERC721s.add(1);
            auction.slots[slotIndex].totalWithdrawnNfts = auction
            .slots[slotIndex]
            .totalWithdrawnNfts
            .add(1);

            if (nftForWithdrawal.tokenId != 0) {
                IERC721Upgradeable(nftForWithdrawal.tokenAddress).safeTransferFrom(
                    address(this),
                    claimer,
                    nftForWithdrawal.tokenId
                );
            }
        }

    }

    function distributeSecondarySaleFees(
        uint256 auctionId,
        uint256 slotIndex,
        uint256 nftSlotIndex
    ) external override nonReentrant {
        Auction storage auction = auctions[auctionId];
        Slot storage slot = auction.slots[slotIndex];
        DepositedERC721 storage nft = slot.depositedNfts[nftSlotIndex];

        require(nft.hasSecondarySaleFees && !nft.feesPaid, "Not supported/Fees already paid");
        require(slot.revenueCaptured, "Slot revenue not captured");

        uint256 averageERC721SalePrice = slot.winningBidAmount.div(slot.totalDepositedNfts);

        LibPart.Part[] memory fees = royaltiesRegistry.getRoyalties(nft.tokenAddress, nft.tokenId);
        uint256 value = averageERC721SalePrice;
        nft.feesPaid = true;

        for (uint256 i = 0; i < fees.length && i < 5; i += 1) {
            Fee memory interimFee = subFee(value, averageERC721SalePrice.mul(fees[i].value).div(10000));
            value = interimFee.remainingValue;

            if (auction.bidToken == address(0) && interimFee.feeValue > 0) {
                (bool success, ) = (fees[i].account).call{value: interimFee.feeValue}("");
                require(success, "Failed");
            }

            if (auction.bidToken != address(0) && interimFee.feeValue > 0) {
                IERC20Upgradeable token = IERC20Upgradeable(auction.bidToken);
                require(
                    token.transfer(address(fees[i].account), interimFee.feeValue),
                    "Failed"
                );
            }
        }

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

        emit LogRoyaltiesWithdrawal(amountToWithdraw, daoAddress, token);

        if (token == address(0)) {
            (bool success, ) = payable(daoAddress).call{value: amountToWithdraw}("");
            require(success, "Failed");
        }

        if (token != address(0)) {
            IERC20Upgradeable erc20token = IERC20Upgradeable(token);
            require(erc20token.transfer(daoAddress, amountToWithdraw), "Failed");
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

    function setRoyaltiesRegistry(IRoyaltiesProvider _royaltiesRegistry) external override onlyDAO returns (IRoyaltiesProvider) {
        royaltiesRegistry = _royaltiesRegistry;
        return royaltiesRegistry;
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
        returns (DepositedERC721[] memory)
    {
        uint256 nftsInSlot = auctions[auctionId].slots[slotIndex].totalDepositedNfts;

        DepositedERC721[] memory nfts = new DepositedERC721[](nftsInSlot);

        for (uint256 i = 0; i < nftsInSlot; i += 1) {
            nfts[i] = auctions[auctionId].slots[slotIndex].depositedNfts[i + 1];
        }
        return nfts;
    }

    function getSlotInfo(uint256 auctionId, uint256 slotIndex)
        external
        view
        override
        returns (SlotInfo memory)
    {
        Slot storage slot = auctions[auctionId].slots[slotIndex];
        SlotInfo memory slotInfo = SlotInfo(
            slot.totalDepositedNfts,
            slot.totalWithdrawnNfts,
            slot.reservePrice,
            slot.winningBidAmount,
            slot.reservePriceReached,
            slot.revenueCaptured,
            slot.winner
        );
        return slotInfo;
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
        returns (uint256)
    {
        return auctions[auctionId].bidBalance[bidder];
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
        nonReentrant
        returns (uint256[] memory)
    {
        uint256[] memory nftSlotIndexes = new uint256[](tokens.length);

        require(msg.sender == auctions[auctionId].auctionOwner, "Not allowed to deposit");
        require(
            auctions[auctionId].numberOfSlots >= slotIndex && slotIndex > 0,
            "Non-existing slot"
        );
        require((tokens.length <= 40), "Can't deposit more than 40");
        require(
            (auctions[auctionId].slots[slotIndex].totalDepositedNfts + tokens.length <= nftSlotLimit),
            "Slot limit exceeded"
        );

        // Ensure previous slot has depoited NFTs, so there is no case where there is an empty slot between non-empty slots
        if (slotIndex > 1) {
            require(auctions[auctionId].slots[slotIndex - 1].totalDepositedNfts > 0, "Previous slot is empty");
        }

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
        uint256 amount
    ) public override onlyExistingAuction(auctionId) onlyAuctionCanceled(auctionId) nonReentrant {

        Auction storage auction = auctions[auctionId];
        Slot storage slot = auction.slots[slotIndex];

        uint256 totalDeposited = slot.totalDepositedNfts;
        uint256 totalWithdrawn = slot.totalWithdrawnNfts;

        require(amount <= 40, "Can't withdraw more than 40");
        require(amount <= totalDeposited.sub(totalWithdrawn), "Not enough available");

        for (uint256 i = totalWithdrawn; i < amount.add(totalWithdrawn); i += 1) {
            _withdrawDepositedERC721(auctionId, slotIndex, (i + 1));
        }

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

    function isWinningBid(uint256 auctionId, uint256 bid) public view override onlyExistingAuction(auctionId) returns (bool) {
        address[] memory bidders = getTopBidders(auctionId, auctions[auctionId].numberOfSlots);
        uint256 lowestEligibleBid = auctions[auctionId].bidBalance[bidders[bidders.length - 1]];
        return (bid > lowestEligibleBid);
    }

    function canWithdrawBid(uint256 auctionId, address bidder) public view override onlyExistingAuction(auctionId) returns (bool) {
        address[] memory bidders = getTopBidders(auctionId, auctions[auctionId].numberOfSlots);
        bool canWithdraw = true;

        for (uint256 i = 0; i < bidders.length; i+=1) {
            if (bidders[i] == bidder) {
                canWithdraw = false;
            }
        }

        return canWithdraw;
    }

    function _depositERC721(
        uint256 auctionId,
        uint256 slotIndex,
        uint256 tokenId,
        address tokenAddress
    ) internal returns (uint256) {

        DepositedERC721 memory item = DepositedERC721({
            tokenId: tokenId,
            tokenAddress: tokenAddress,
            depositor: msg.sender,
            hasSecondarySaleFees: royaltiesRegistry.getRoyalties(tokenAddress, tokenId).length > 0,
            feesPaid: false
        });

        IERC721Upgradeable(tokenAddress).safeTransferFrom(msg.sender, address(this), tokenId);

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
            nftSlotIndex
        );

        return nftSlotIndex;
    }

    function _withdrawERC721FromNonWinningSlot(
        uint256 auctionId,
        uint256 slotIndex,
        uint256 nftSlotIndex
    ) internal {
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
            nftSlotIndex
        );

        IERC721Upgradeable(nftForWithdrawal.tokenAddress).safeTransferFrom(
            address(this),
            nftForWithdrawal.depositor,
            nftForWithdrawal.tokenId
        );

    }

    function _withdrawDepositedERC721(
        uint256 auctionId,
        uint256 slotIndex,
        uint256 nftSlotIndex
    ) internal {
        Auction storage auction = auctions[auctionId];
        DepositedERC721 memory nftForWithdrawal = auction.slots[slotIndex].depositedNfts[
            nftSlotIndex
        ];

        require(msg.sender == nftForWithdrawal.depositor, "Only depositor can withdraw");

        delete auction.slots[slotIndex].depositedNfts[nftSlotIndex];

        auction.totalWithdrawnERC721s = auction.totalWithdrawnERC721s.add(1);
        auction.totalDepositedERC721s = auction.totalDepositedERC721s.sub(1);
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
            nftSlotIndex
        );

        IERC721Upgradeable(nftForWithdrawal.tokenAddress).safeTransferFrom(
            address(this),
            nftForWithdrawal.depositor,
            nftForWithdrawal.tokenId
        );

    }

    function extendAuction(uint256 auctionId) internal {
        Auction storage auction = auctions[auctionId];

        uint256 resetTimer = auction.resetTimer;
        auction.endTime = auction.endTime.add(resetTimer);

        emit LogAuctionExtended(auctionId, auction.endTime);

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
            auctions[auctionId].bidBalance[bidder]
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
        removeBid(auctionId, bidder);
        addBid(auctionId, bidder, newValue);
    }

    function calculateSecondarySaleFees(uint256 auctionId, uint256 slotIndex)
        internal
        returns (uint256)
    {
        Slot storage slot = auctions[auctionId].slots[slotIndex];

        uint256 averageERC721SalePrice = slot.winningBidAmount.div(slot.totalDepositedNfts);
        uint256 totalFeesPayableForSlot = 0;

        for (uint256 i = 0; i < slot.totalDepositedNfts; i += 1) {
            DepositedERC721 memory nft = slot.depositedNfts[i + 1];

            if (nft.hasSecondarySaleFees) {
                LibPart.Part[] memory fees = royaltiesRegistry.getRoyalties(nft.tokenAddress, nft.tokenId);
                uint256 value = averageERC721SalePrice;

                for (uint256 j = 0; j < fees.length && j < 5; j += 1) {
                    Fee memory interimFee = subFee(
                        value,
                        averageERC721SalePrice.mul(fees[j].value).div(10000)
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
