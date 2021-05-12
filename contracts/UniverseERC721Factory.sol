// SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./UniverseERC721.sol";
import "./IAuctionFactory.sol";

contract UniverseERC721Factory is Ownable {
    address[] public deployedContracts;
    address public lastDeployedContractAddress;
    IAuctionFactory public universeAuction;

    constructor(address _universeAuction) {
        universeAuction = IAuctionFactory(_universeAuction);
    }

    function getDeployedContractsCount() public view returns (uint256 count) {
        return deployedContracts.length;
    }

    function deployUniverseERC721(
        string memory tokenName,
        string memory tokenSymbol
    ) public returns (address universeERC721Contract) {
        UniverseERC721 deployedContract =
            new UniverseERC721(
                address(universeAuction),
                tokenName,
                tokenSymbol
            );

        deployedContract.transferOwnership(msg.sender);
        address deployedContractAddress = address(deployedContract);
        deployedContracts.push(deployedContractAddress);
        lastDeployedContractAddress = deployedContractAddress;

        return deployedContractAddress;
    }

    function setAuctionFactory(address _universeAuction)
        external
        onlyOwner
        returns (address _universeAuctionAddress)
    {
        universeAuction = IAuctionFactory(_universeAuction);
        return address(universeAuction);
    }
}
