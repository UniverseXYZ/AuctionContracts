const { expect } = require('chai');
const { waffle } = require('hardhat');
const { loadFixture } = waffle;

describe('Test bidding with ETH', () => {
  const deployedContracts = async () => {
    const AuctionFactory = await ethers.getContractFactory('AuctionFactory');
    const MockNFT = await ethers.getContractFactory('MockNFT');

    const auctionFactory = await AuctionFactory.deploy();
    const mockNFT = await MockNFT.deploy();

    return { auctionFactory, mockNFT };
  };

  it('should bid with ETH successfully', async () => {
    const { auctionFactory, mockNFT } = await loadFixture(depositERC721);

    await createAuction(auctionFactory);

    const totalAuctions = await auctionFactory.totalAuctions();

    console.log(totalAuctions.toString());

    await depositNFT(auctionFactory, mockNFT);
  });
});

const createAuction = async (auctionFactory) => {
  const blockNumber = await ethers.provider.getBlockNumber();

  const startBlockNumber = blockNumber + 5;
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
};

const depositNFT = async (auctionFactory, mockNFT) => {
  const [owner] = await ethers.getSigners();

  const auctionId = 1;
  const slotIdx = 0;
  const tokenId = 1;

  await mockNFT.mint(owner.address, 'nftURI');
  await mockNFT.approve(auctionFactory.address, tokenId);

  console.log('Auction', auctionFactory);

  await auctionFactory.depositERC721(
    auctionId,
    slotIdx,
    tokenId,
    mockNFT.address
  );
};
