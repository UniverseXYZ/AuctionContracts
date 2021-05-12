// SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IAuctionFactory.sol";
import "./HasSecondarySaleFees.sol";

contract UniverseERC721 is ERC721, Ownable, HasSecondarySaleFees {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIds;
    IAuctionFactory public universeAuction;

    constructor(
        address _universeAuction,
        string memory _tokenName,
        string memory _tokenSymbol
    ) ERC721(_tokenName, _tokenSymbol) {
        universeAuction = IAuctionFactory(_universeAuction);
    }

    function mint(
        address receiver,
        string memory tokenURI,
        Fee[] memory fees
    ) public returns (uint256) {
        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        _mint(receiver, newItemId);
        _setTokenURI(newItemId, tokenURI);
        _registerFees(newItemId, fees);

        return newItemId;
    }

    function updateTokenURI(uint256 _tokenId, string memory _tokenURI)
        public
        onlyOwner
        returns (string memory)
    {
        _setTokenURI(_tokenId, _tokenURI);

        return _tokenURI;
    }

    function batchMint(
        address receiver,
        string[] calldata tokenURIs,
        Fee[] memory fees
    ) public returns (uint256[] memory) {
        require(
            tokenURIs.length <= 40,
            "Cannot mint more than 40 ERC721 tokens in a single call"
        );

        uint256[] memory mintedTokenIds = new uint256[](tokenURIs.length);

        for (uint256 i = 0; i < tokenURIs.length; i++) {
            uint256 tokenId = mint(receiver, tokenURIs[i], fees);
            mintedTokenIds[i] = tokenId;
        }

        return mintedTokenIds;
    }

    function batchMintToAuction(
        uint256 auctionId,
        uint256 slotIndex,
        string[] calldata tokenURIs,
        Fee[] memory fees
    ) public returns (uint256[] memory) {
        uint256[] memory mintedTokenIds =
            batchMint(address(universeAuction), tokenURIs, fees);

        uint256[] memory nftSlotIndices = new uint256[](mintedTokenIds.length);

        for (uint256 i = 0; i < mintedTokenIds.length; i++) {
            uint256 nftSlotIndex =
                universeAuction.registerDepositERC721WithoutTransfer(
                    auctionId,
                    slotIndex,
                    mintedTokenIds[i],
                    address(this),
                    msg.sender
                );
            nftSlotIndices[i] = nftSlotIndex;
        }

        return nftSlotIndices;
    }

    function ownedTokens(address ownerAddress)
        public
        view
        returns (uint256[] memory)
    {
        uint256 tokenBalance = balanceOf(ownerAddress);
        uint256[] memory tokens = new uint256[](tokenBalance);

        for (uint256 i = 0; i < tokenBalance; i++) {
            uint256 tokenId = tokenOfOwnerByIndex(ownerAddress, i);
            tokens[i] = tokenId;
        }

        return tokens;
    }

    function _registerFees(uint256 _tokenId, Fee[] memory _fees)
        internal
        returns (bool)
    {
        address[] memory recipients = new address[](_fees.length);
        uint256[] memory bps = new uint256[](_fees.length);
        for (uint256 i = 0; i < _fees.length; i++) {
            require(
                _fees[i].recipient != address(0x0),
                "Recipient should be present"
            );
            require(_fees[i].value != 0, "Fee value should be positive");
            fees[_tokenId].push(_fees[i]);
            recipients[i] = _fees[i].recipient;
            bps[i] = _fees[i].value;
        }
        if (_fees.length > 0) {
            emit SecondarySaleFees(_tokenId, recipients, bps);
        }
    }
}
