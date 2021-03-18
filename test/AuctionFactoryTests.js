const { expect } = require("chai");
const { waffle } = require("hardhat");
const { loadFixture } = waffle;

describe("AuctionFactory", () => {
  async function deployContract() {
    const AuctionFactory = await ethers.getContractFactory("AuctionFactory");
    const MockNFT = await ethers.getContractFactory("MockNFT");

    const auctionFactory = await AuctionFactory.deploy();
    const mockNFT = await MockNFT.deploy();

    return {auctionFactory, mockNFT};
  }

  async function launchAuction() {
    const {auctionFactory, mockNFT} = await loadFixture(deployContract);
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
    return {auctionFactory, mockNFT, auction};
  }
  async function depositERC721(){
    const {auctionFactory, mockNFT, auction} = await loadFixture(launchAuction);
    const [owner] = await ethers.getSigners();

    await mockNFT.mint(owner.address, "testURI");
    mockNFT.approve(auctionFactory.address, 1)
    depositData = await auctionFactory.depositERC721(1, 0, 1, mockNFT.address);

    return {auctionFactory, mockNFT, auction};
  }


  it("Deploy the AuctionFactory and MockNFT", async function() {
    const {auctionFactory, mockNFT} = await loadFixture(deployContract);

    expect(auctionFactory.address).to.have.string('0x');
  });
  it("Launch an Auction", async function() {
    const {auctionFactory, mockNFT, auction} = await loadFixture(launchAuction);
    const auctionData = await auctionFactory.auctions(1);

    expect(auctionData['numberOfSlots'].toString()).to.equal("1");
  });
  it("Deposit NFT into Auction", async function() {
    const {auctionFactory, mockNFT, auction} = await loadFixture(depositERC721);
    const deposited = await auctionFactory.getDeposited(1, 0);

    expect(deposited[0]['tokenId'].toString()).to.equal("1")
  });


});
