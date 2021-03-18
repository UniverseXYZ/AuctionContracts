const { expect } = require("chai");
const { waffle } = require("hardhat");
const { loadFixture } = waffle;

describe("AuctionFactory", () => {
  async function deployContract() {
    const AuctionFactory = await ethers.getContractFactory("AuctionFactory");
    const auctionFactory = await AuctionFactory.deploy();

    return auctionFactory;
  }

  async function launchAuction() {
    const auctionFactory = await loadFixture(deployContract);
    const blockNumber = await ethers.provider.getBlockNumber();

    const startBlockNumber = blockNumber + 1;
    const endBlockNumber = blockNumber + 11;
    const resetTimer = 3;
    const numberOfSlots = 1;
    const supportsWhitelist = false;
    const bidToken = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
    auction = await auctionFactory.createAuction(
                                    startBlockNumber,
                                    endBlockNumber,
                                    resetTimer,
                                    numberOfSlots,
                                    supportsWhitelist,
                                    bidToken
                                  );
    return {auctionFactory, auction};
  }

  it("Deploy the AuctionFactory", async function() {
    const auctionFactory = await loadFixture(deployContract);

    expect(auctionFactory.address).to.have.string('0x');
  });
  it("Launch an Auction", async function() {
    const {auctionFactory, auction} = await loadFixture(launchAuction);
    auctionData = await auctionFactory.auctions(1)
    expect(auctionData['startBlockNumber'].toString()).to.equal("2")
    expect(auctionData['endBlockNumber'].toString()).to.equal("12")
  });
});
