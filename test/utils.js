const ethers = require('ethers');

const createAuction = async (deployedContracts) => {
  const { auctionFactory } = await loadFixture(deployedContracts);
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

const depositNFT = async (deployedContracts) => {
  const { auctionFactory } = await loadFixture(deployedContracts);

  const [owner] = await ethers.getSigners();

  const auctionId = 1;
  const slotIdx = 0;
  const tokenId = 1;

  await mockNFT.mint(owner.address, 'nftURI');
  await mockNFT.approve(auctionFactory.address, tokenId);

  await auctionFactory.depositERC721(
    auctionId,
    slotIdx,
    tokenId,
    mockNFT.address
  );
};

module.exports = {
  createAuction,
  depositNFT,
};
