// SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./UniverseERC721.sol";

contract UniverseERC721Factory is Ownable {
    address[] public deployedContracts;
    address public lastDeployedContractAddress;

    event LogUniverseERC721ContractDeployed(
        string tokenName,
        string tokenSymbol,
        address contractAddress,
        uint256 time
    );

    constructor() {}

    function getDeployedContractsCount() public view returns (uint256 count) {
        return deployedContracts.length;
    }

    function deployUniverseERC721(
        string memory tokenName,
        string memory tokenSymbol
    ) public returns (address universeERC721Contract) {
        UniverseERC721 deployedContract =
            new UniverseERC721(tokenName, tokenSymbol);

        deployedContract.transferOwnership(msg.sender);
        address deployedContractAddress = address(deployedContract);
        deployedContracts.push(deployedContractAddress);
        lastDeployedContractAddress = deployedContractAddress;

        emit LogUniverseERC721ContractDeployed(
            tokenName,
            tokenSymbol,
            deployedContractAddress,
            block.timestamp
        );

        return deployedContractAddress;
    }
}
