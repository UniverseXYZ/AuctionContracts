const { expect } = require('chai');
const { waffle } = require('hardhat');
const { loadFixture } = waffle;

describe('UniverseERC721', () => {
  const deployContracts = async () => {
    const AuctionFactory = await ethers.getContractFactory('AuctionFactory');
    const auctionFactory = await AuctionFactory.deploy(2000);

    const UniverseERC721 = await ethers.getContractFactory('UniverseERC721');
    const universeERC721 = await UniverseERC721.deploy(auctionFactory.address);

    return { auctionFactory, universeERC721 };
  };

  it('should mint successfully', async () => {
    const { universeERC721 } = await loadFixture(deployContracts);

    const [signer] = await ethers.getSigners();

    await universeERC721.mint(signer.address, 'TestURI');
  });

  it('should update tokenURI', async () => {
    const { universeERC721 } = await loadFixture(deployContracts);

    const [signer] = await ethers.getSigners();

    await universeERC721.mint(signer.address, 'TestURI');

    await universeERC721.updateTokenURI(1, 'TestURI2');
  });

  it('should revert with Ownable: caller is not the owner', async () => {
    const { universeERC721 } = await loadFixture(deployContracts);

    const [signer, signer2] = await ethers.getSigners();

    await universeERC721.mint(signer.address, 'TestURI');

    await expect(universeERC721.connect(signer2).updateTokenURI(1, 'TestURI2')).revertedWith(
      'Ownable: caller is not the owner'
    );
  });

  it('should batchMint successfully', async () => {
    const { universeERC721 } = await loadFixture(deployContracts);

    const [signer] = await ethers.getSigners();

    await universeERC721.batchMint(signer.address, ['TestURI', 'TestURI2']);
  });

  it('should revert with Cannot mint more than 40 ERC721 tokens in a single call', async () => {
    const { universeERC721 } = await loadFixture(deployContracts);

    const [signer] = await ethers.getSigners();

    const uris = new Array(41).fill('asd');

    await expect(universeERC721.batchMint(signer.address, uris)).revertedWith(
      'Cannot mint more than 40 ERC721 tokens in a single call'
    );
  });

  it('should batchMint successfully', async () => {
    const { universeERC721, auctionFactory } = await loadFixture(deployContracts);

    const blockNumber = await ethers.provider.getBlockNumber();

    const startBlockNumber = blockNumber + 3;
    const endBlockNumber = blockNumber + 15;
    const resetTimer = 3;
    const numberOfSlots = 10;
    const supportsWhitelist = false;
    const bidToken = '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2';

    await auctionFactory.createAuction(
      startBlockNumber,
      endBlockNumber,
      resetTimer,
      numberOfSlots,
      supportsWhitelist,
      bidToken
    );

    await expect(universeERC721.batchMintToAuction(1, 1, ['TestURI', 'TestURI2'])).emit(
      auctionFactory,
      'LogERC721Deposit'
    );
  });
});
