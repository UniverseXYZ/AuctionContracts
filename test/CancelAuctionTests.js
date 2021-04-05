const { expect } = require('chai');
const { waffle } = require('hardhat');
const { loadFixture } = waffle;

describe('Test cancel functionality', () => {
  const deployContracts = async () => {
    const [AuctionFactory, MockNFT] = await Promise.all([
      ethers.getContractFactory('AuctionFactory'),
      ethers.getContractFactory('MockNFT'),
    ]);

    const [auctionFactory, mockNft] = await Promise.all([AuctionFactory.deploy(2000), MockNFT.deploy()]);

    return {
      auctionFactory,
      mockNft,
    };
  };

  it('should be successfully canceled', async () => {
    const { auctionFactory, mockNft } = await loadFixture(deployContracts);

    await createAuction(auctionFactory);

    await auctionFactory.cancelAuction(1);

    const auction = await auctionFactory.auctions(1);

    expect(auction.isCanceled).to.be.true;
  });

  it('should be reverted if auction is started', async () => {
    const { auctionFactory } = await loadFixture(deployContracts);

    await createAuction(auctionFactory);

    await createAuction(auctionFactory);

    await createAuction(auctionFactory);

    await expect(auctionFactory.cancelAuction(1)).to.be.reverted;
  });

  it('should be reverted if other than auction owner try to cancel it', async () => {
    const { auctionFactory } = await loadFixture(deployContracts);

    const blockNumber = await ethers.provider.getBlockNumber();

    const [signer1, signer2] = await ethers.getSigners();

    const startBlockNumber = blockNumber + 3;
    const endBlockNumber = blockNumber + 4;
    const resetTimer = 3;
    const numberOfSlots = 1;
    const supportsWhitelist = false;
    const ethAddress = '0x0000000000000000000000000000000000000000';

    await auctionFactory
      .connect(signer1)
      .createAuction(startBlockNumber, endBlockNumber, resetTimer, numberOfSlots, supportsWhitelist, ethAddress);

    await expect(auctionFactory.connect(signer2).cancelAuction(1)).to.be.reverted;
  });
});

const createAuction = async (auctionFactory) => {
  const blockNumber = await ethers.provider.getBlockNumber();

  const startBlockNumber = blockNumber + 3;
  const endBlockNumber = blockNumber + 4;
  const resetTimer = 3;
  const numberOfSlots = 1;
  const supportsWhitelist = false;
  const ethAddress = '0x0000000000000000000000000000000000000000';

  await auctionFactory.createAuction(
    startBlockNumber,
    endBlockNumber,
    resetTimer,
    numberOfSlots,
    supportsWhitelist,
    ethAddress
  );
};

const depositNFT = async (auctionFactory, mockNFT) => {
  const [owner] = await ethers.getSigners();

  const auctionId = 1;
  const slotIdx = 0;
  const tokenId = 1;

  await mockNFT.mint(owner.address, 'nftURI');
  await mockNFT.approve(auctionFactory.address, tokenId);

  await auctionFactory.depositERC721(auctionId, slotIdx, tokenId, mockNFT.address);
};
