const { expect } = require('chai');
const { waffle } = require('hardhat');
const { loadFixture } = waffle;

const { createAuction, depositNFT } = require('./utils');

describe('Test bidding with ETH', () => {
  const deployedContracts = async () => {
    const AuctionFactory = await ethers.getContractFactory('AuctionFactory');
    const MockNFT = await ethers.getContractFactory('MockNFT');

    const auctionFactory = await AuctionFactory.deploy();
    const mockNFT = await MockNFT.deploy();

    return { auctionFactory, mockNFT };
  };

  beforeEach(async () => {
    await createAuction(deployedContracts);
    await depositNFT(deployedContracts);
  });
});
