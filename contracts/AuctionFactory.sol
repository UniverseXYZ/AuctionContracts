//SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721Holder.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./IAuctionFactory.sol";

contract AuctionFactory is IAuctionFactory, ERC721Holder {
    using SafeMath for uint256;

    uint256 public totalAuctions;
    mapping(uint256 => Auction) public auctions;

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
        uint256 auction,
        uint256 amount,
        uint256 time
    );

    event LogAuctionExtended(
        uint256 auctionId,
        uint256 endBlockNumber,
        uint256 time
    );

    modifier onlyExistingAuction(uint256 _auctionId) {
        require(
            _auctionId > 0 && _auctionId <= totalAuctions,
            "Auction do not exists"
        );
        _;
    }

    modifier onlyAuctionStarted(uint256 _auctionId) {
        require(
            auctions[_auctionId].startBlockNumber <= block.number,
            "Auction is not started yet"
        );
        _;
    }

    modifier onlyAuctionNotStarted(uint256 _auctionId) {
        console.log(auctions[_auctionId].startBlockNumber, block.number);
        require(
            auctions[_auctionId].startBlockNumber > block.number,
            "Auction is started"
        );
        _;
    }

    modifier onlyAuctionNotCanceled(uint256 _auctionId) {
        // TODO: Uncomment when isCanceled functionality is merged

        // require(auctions[_auctionId].isCanceled == false, "Auction is canceled");
        _;
    }

    modifier onlyValidBidAmount(uint256 _bid) {
        require(_bid > 0, "Bid amount must be higher than 0");
        _;
    }

    modifier onlyETH(uint256 _auctionId) {
        require(
            auctions[_auctionId].bidToken == address(0),
            "Token contract address provided"
        );
        _;
    }

    modifier onlyERC20(uint256 _auctionId) {
        require(
            auctions[_auctionId].bidToken != address(0),
            "No token contract address provided"
        );
        _;
    }

    modifier onlyWhenBidOnAllSlots(uint256 _auctionId) {
        require(
            auctions[_auctionId].numberOfBids >
                auctions[_auctionId].numberOfSlots,
            "All slots must have bids before a withdrawl can occur"
        );
        _;
    }

    modifier onlyWhenBidNotEligible(uint256 _auctionId) {
        require(
            auctions[_auctionId].balanceOf[msg.sender] <
                auctions[_auctionId].lowestEligibleBid,
            "Bid is still eligbile"
        );
        _;
    }

    modifier onlyIfWhitelistSupported(uint256 _auctionId) {
        require(
            auctions[_auctionId].supportsWhitelist,
            "The auction should support whitelisting!"
        );
        _;
    }

    modifier onlyAuctionOwner(uint256 _auctionId) {
        require(
            auctions[_auctionId].auctionOwner == msg.sender,
            "Only the auction owner can whitelist addresses!"
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
            "Auction cannot begin before the current block"
        );

        require(
            _startBlockNumber < _endBlockNumber,
            "Auction cannot end before it is launched"
        );

        require(_resetTimer > 0, "Reset timer must be higher than 0seconds");

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

        totalAuctions = totalAuctions.add(1);

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
        external
        override
        onlyExistingAuction(_auctionId)
        onlyAuctionNotStarted(_auctionId)
        onlyAuctionNotCanceled(_auctionId)
        returns (uint256)
    {
        address _depositor = msg.sender;

        require(
            _tokenAddress != address(0),
            "Zero address was provided for token address"
        );

        if (auctions[_auctionId].supportsWhitelist) {
            require(
                auctions[_auctionId].whitelistAddresses[_depositor] == true,
                "You are not allowed to deposit in this auction"
            );
        }

        require(
            auctions[_auctionId].numberOfSlots >= _slotIndex,
            "You are trying to deposit to a non-existing slot"
        );

        DepositedERC721 memory item =
            DepositedERC721({
                auctionId: _auctionId,
                slotIndex: _slotIndex,
                tokenId: _tokenId,
                tokenAddress: _tokenAddress,
                depositor: _depositor
            });

        auctions[_auctionId].slots[_slotIndex].auctionId = _auctionId;
        auctions[_auctionId].slots[_slotIndex].slotIndex = _slotIndex;

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

        require(
            (auctions[_auctionId].numberOfBids <
                auctions[_auctionId].numberOfSlots ||
                _bid > auctions[_auctionId].lowestEligibleBid),
            "Bid amount must be greater than the lowest eligble bid when all auction slots are filled"
        );

        Auction storage auction = auctions[_auctionId];

        if (_bid < auction.lowestEligibleBid) {
            auction.lowestEligibleBid = _bid;
        }
        if (
            auctions[_auctionId].numberOfSlots <=
            auctions[_auctionId].numberOfBids
        ) {
            auction.lowestEligibleBid = _bid;
        }

        if (_bid > auctions[_auctionId].lowestEligibleBid) {
            extendAuction(_auctionId);
        }

        auction.balanceOf[_bidder] = auction.balanceOf[_bidder].add(_bid);
        auction.numberOfBids = auction.numberOfBids.add(1);

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

        require(
            (auctions[_auctionId].numberOfBids <
                auctions[_auctionId].numberOfSlots ||
                _bid > auctions[_auctionId].lowestEligibleBid),
            "Bid amount must be greater than the lowest eligble bid when all auction slots are filled"
        );

        IERC20 bidToken = IERC20(auctions[_auctionId].bidToken);
        uint256 allowance = bidToken.allowance(msg.sender, address(this));

        require(allowance >= _bid, "Token allowance too small");

        Auction storage auction = auctions[_auctionId];
        if (_bid < auction.lowestEligibleBid) {
            auction.lowestEligibleBid = _bid;
        }
        if (
            auctions[_auctionId].numberOfSlots <=
            auctions[_auctionId].numberOfBids
        ) {
            auction.lowestEligibleBid = _bid;
        }
        auction.balanceOf[_bidder] = auction.balanceOf[_bidder].add(_bid);
        auction.numberOfBids = auction.numberOfBids.add(1);

        if (_bid > auctions[_auctionId].lowestEligibleBid) {
            extendAuction(_auctionId);
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
        uint256 totalWithdrawnNftsInSlot =
            auctions[auctionId].slots[slotIndex].totalWithdrawnNfts;

        DepositedERC721 memory nftForWithdrawal =
            auctions[auctionId].slots[slotIndex].depositedNfts[nftSlotIndex];

        require(
            msg.sender == nftForWithdrawal.depositor,
            "Only a depositor can withdraw"
        );

        auctions[auctionId].slots[slotIndex]
            .totalWithdrawnNfts = totalWithdrawnNftsInSlot.add(1);

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

    function finalize(uint256 _auctionId)
        external
        override
        onlyExistingAuction(_auctionId)
        onlyAuctionNotCanceled(_auctionId)
        returns (bool)
    {}

    function cancelAuction(uint256 auctionId)
        external
        override
        onlyExistingAuction(auctionId)
        onlyAuctionNotStarted(auctionId)
        onlyAuctionNotCanceled(auctionId)
        onlyAuctionOwner(auctionId)
        returns (bool)
    {}

    function whitelistAddress(uint256 auctionId, address addressToWhitelist)
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

        auction.whitelistAddresses[addressToWhitelist] = true;

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
        Auction storage auction = auctions[auctionId];
        return auction.whitelistAddresses[addressToCheck];
    }

    function extendAuction(uint256 auctionId)
        internal
        onlyExistingAuction(auctionId)
        returns (bool)
    {
        Auction storage auction = auctions[auctionId];

        require(
            block.number < auction.endBlockNumber,
            "Cannot extend the auction if it has already ended!"
        );

        uint256 resetTimer = auction.resetTimer;
        auctions[auctionId].endBlockNumber = auction.endBlockNumber.add(
            resetTimer
        );

        emit LogAuctionExtended(
            auctionId,
            auction.endBlockNumber,
            block.timestamp
        );

        return true;
    }
}
