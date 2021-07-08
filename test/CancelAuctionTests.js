const { expect } = require('chai');
const { waffle } = require('hardhat');
const { loadFixture } = waffle;

describe('Test cancel functionality', () => {
  const deployContracts = async () => {
    const [AuctionFactory, MockNFT] = await Promise.all([
      ethers.getContractFactory('AuctionFactory'),
      ethers.getContractFactory('MockNFT')
    ]);

    const [auctionFactory, mockNft] = await Promise.all([AuctionFactory.deploy(2000, 100), MockNFT.deploy()]);

    return {
      auctionFactory,
      mockNft
    };
  };

  it('should be successfully canceled', async () => {
    const { auctionFactory, mockNft } = await loadFixture(deployContracts);

    await createAuction(auctionFactory);

    await auctionFactory.cancelAuction(1);

    const auction = await auctionFactory.auctions(1);

    expect(auction.isCanceled).to.be.true;
  });

  it('should not be reverted if auction has not started', async () => {
    const { auctionFactory } = await loadFixture(deployContracts);

    await createAuction(auctionFactory);

    await expect(auctionFactory.cancelAuction(1));
  });

  it('should be reverted if other than auction owner try to cancel it', async () => {
    const { auctionFactory } = await loadFixture(deployContracts);

    const currentTime = Math.round((new Date()).getTime() / 1000);

    const [signer1, signer2] = await ethers.getSigners();

    const startTime = currentTime + 1500;
    const endTime = startTime + 500;
    const resetTimer = 3;
    const numberOfSlots = 1;
    const ethAddress = '0x0000000000000000000000000000000000000000';
    const whitelistAddresses = [];
    const minimumReserveValues = [];
    const paymentSplits = [];

    await auctionFactory
      .connect(signer1)
      .createAuction([startTime, endTime, resetTimer, numberOfSlots, ethAddress, whitelistAddresses, minimumReserveValues, paymentSplits]);

    await expect(auctionFactory.connect(signer2).cancelAuction(1)).to.be.reverted;
  });
});

const createAuction = async (auctionFactory) => {
  const currentTime = Math.round((new Date()).getTime() / 1000);

  const startTime = currentTime + 1500;
  const endTime = startTime + 500;
  const resetTimer = 3;
  const numberOfSlots = 1;
  const ethAddress = '0x0000000000000000000000000000000000000000';
  const whitelistAddresses = [];
  const minimumReserveValues = [];
  const paymentSplits = [];

  await auctionFactory.createAuction([
    startTime,
    endTime,
    resetTimer,
    numberOfSlots,
    ethAddress,
    whitelistAddresses,
    minimumReserveValues,
    paymentSplits
  ]);
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
