const { expect } = require('chai');
const { waffle } = require('hardhat');
const { loadFixture } = waffle;

describe('Create Auction Tests', () => {
  async function deployContract() {
    const AuctionFactory = await ethers.getContractFactory('AuctionFactory');
    const auctionFactory = await AuctionFactory.deploy();

    return { auctionFactory };
  }

  it('Deploy the AuctionFactory and MockNFT', async function () {
    const { auctionFactory } = await loadFixture(deployContract);
    const blockNumber = await ethers.provider.getBlockNumber();

    const startBlockNumber = blockNumber + 5;
    const endBlockNumber = blockNumber + 15;
    const resetTimer = 3;
    const numberOfSlots = 1;
    const supportsWhitelist = false;
    const bidToken = '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2';
    auction = await auctionFactory.createAuction(
      startBlockNumber,
      endBlockNumber,
      resetTimer,
      numberOfSlots,
      supportsWhitelist,
      bidToken
    );
  });
  it('fail on startBlockNumber < blockNumber', async function () {
    const { auctionFactory } = await loadFixture(deployContract);
    const blockNumber = await ethers.provider.getBlockNumber();

    const startBlockNumber = blockNumber - 1;
    const endBlockNumber = blockNumber + 11;
    const resetTimer = 3;
    const numberOfSlots = 1;
    const supportsWhitelist = false;
    const bidToken = '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2';
    await expect(
      auctionFactory.createAuction(
        startBlockNumber,
        endBlockNumber,
        resetTimer,
        numberOfSlots,
        supportsWhitelist,
        bidToken
      )
    ).to.be.reverted;
  });
  it('fail on endBlockNumber < startBlockNumber', async function () {
    const { auctionFactory } = await loadFixture(deployContract);
    const blockNumber = await ethers.provider.getBlockNumber();

    const startBlockNumber = blockNumber + 15;
    const endBlockNumber = blockNumber + 10;
    const resetTimer = 3;
    const numberOfSlots = 1;
    const supportsWhitelist = false;
    const bidToken = '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2';
    await expect(
      auctionFactory.createAuction(
        startBlockNumber,
        endBlockNumber,
        resetTimer,
        numberOfSlots,
        supportsWhitelist,
        bidToken
      )
    ).to.be.reverted;
  });
});
