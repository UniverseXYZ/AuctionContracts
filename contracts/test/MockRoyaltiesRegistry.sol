// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../IRoyaltiesProvider.sol";
import "../HasSecondarySaleFees.sol";

contract MockRoyaltiesRegistry is IRoyaltiesProvider, Ownable{

    event RoyaltiesSetForToken(address indexed token, uint indexed tokenId, Part[] royalties);
    event RoyaltiesSetForContract(address indexed token, Part[] royalties);

    struct RoyaltiesSet {
        bool initialized;
        Part[] royalties;
    }

    mapping(bytes32 => RoyaltiesSet) public royaltiesByTokenAndTokenId;
    mapping(address => RoyaltiesSet) public royaltiesByToken;
    mapping(address => address) public royaltiesProviders;

    bytes4 private constant _INTERFACE_ID_FEES = 0xb7799584;
    bytes4 private constant _INTERFACE_ID_ERC2981 = 0x2a55205a;

    constructor(){}

    function setProviderByToken(address token, address provider) external {
        checkOwner(token);
        royaltiesProviders[token] = provider;
    }

    function setRoyaltiesByToken(address token, Part[] memory royalties) external {
        checkOwner(token);
        uint sumRoyalties = 0;
        delete royaltiesByToken[token];
        for (uint i = 0; i < royalties.length; i++) {
            require(royalties[i].account != address(0x0), "RoyaltiesByToken recipient should be present");
            require(royalties[i].value != 0, "Royalty value for RoyaltiesByToken should be > 0");
            royaltiesByToken[token].royalties.push(royalties[i]);
            sumRoyalties += royalties[i].value;
        }
        require(sumRoyalties < 10000, "Set by token royalties sum more, than 100%");
        royaltiesByToken[token].initialized = true;
        emit RoyaltiesSetForContract(token, royalties);
    }

    function setRoyaltiesByTokenAndTokenId(address token, uint tokenId, Part[] memory royalties) external {
        checkOwner(token);
        setRoyaltiesCacheByTokenAndTokenId(token, tokenId, royalties);
    }

    function checkOwner(address token) internal view {
        if ((owner() != _msgSender()) && (Ownable(token).owner() != _msgSender())) {
            revert("Token owner not detected");
        }
    }

    function getRoyalties(address token, uint tokenId) override external returns (Part[] memory) {
        RoyaltiesSet memory royaltiesSet = royaltiesByTokenAndTokenId[keccak256(abi.encode(token, tokenId))];
        if (royaltiesSet.initialized) {
            return royaltiesSet.royalties;
        }
        royaltiesSet = royaltiesByToken[token];
        if (royaltiesSet.initialized) {
            return royaltiesSet.royalties;
        }
        (bool result, Part[] memory resultRoyalties) = providerExtractor(token, tokenId);
        if (result == false) {
            resultRoyalties = royaltiesFromContract(token, tokenId);
        }
        setRoyaltiesCacheByTokenAndTokenId(token, tokenId, resultRoyalties);
        return resultRoyalties;
    }

    function setRoyaltiesCacheByTokenAndTokenId(address token, uint tokenId, Part[] memory royalties) internal {
        uint sumRoyalties = 0;
        bytes32 key = keccak256(abi.encode(token, tokenId));
        delete royaltiesByTokenAndTokenId[key].royalties;
        for (uint i = 0; i < royalties.length; i++) {
            require(royalties[i].account != address(0x0), "RoyaltiesByTokenAndTokenId recipient should be present");
            require(royalties[i].value != 0, "Royalty value for RoyaltiesByTokenAndTokenId should be > 0");
            royaltiesByTokenAndTokenId[key].royalties.push(royalties[i]);
            sumRoyalties += royalties[i].value;
        }
        require(sumRoyalties < 10000, "Set by token and tokenId royalties sum more, than 100%");
        royaltiesByTokenAndTokenId[key].initialized = true;
        emit RoyaltiesSetForToken(token, tokenId, royalties);
    }

    function royaltiesFromContract(address token, uint tokenId) internal view returns (Part[] memory) {
        if (IERC165(token).supportsInterface(_INTERFACE_ID_FEES)) {
            HasSecondarySaleFees hasFees = HasSecondarySaleFees(token);
            address payable[] memory recipients;
            try hasFees.getFeeRecipients(tokenId) returns (address payable[] memory result) {
                recipients = result;
            } catch {
                return new Part[](0);
            }
            uint[] memory values;
            try hasFees.getFeeBps(tokenId) returns (uint[] memory result) {
                values = result;
            } catch {
                return new Part[](0);
            }
            if (values.length != recipients.length) {
                return new Part[](0);
            }
            Part[] memory result = new Part[](values.length);
            for (uint256 i = 0; i < values.length; i++) {
                result[i].value = uint96(values[i]);
                result[i].account = recipients[i];
            }
            return result;
        }
        return new Part[](0);
    }

    function providerExtractor(address token, uint tokenId) internal returns (bool result, Part[] memory royalties) {
        result = false;
        address providerAddress = royaltiesProviders[token];
        if (providerAddress != address(0x0)) {
            IRoyaltiesProvider provider = IRoyaltiesProvider(providerAddress);
            try provider.getRoyalties(token, tokenId) returns (Part[] memory royaltiesByProvider) {
                royalties = royaltiesByProvider;
                result = true;
            } catch {}
        }
    }

    uint256[46] private __gap;
}
