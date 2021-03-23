const { expect } = require("chai");
const { waffle } = require("hardhat");
const { loadFixture } = waffle;

describe("AuctionFactory", () => {
  async function deployContract() {
    const AuctionFactory = await ethers.getContractFactory("AuctionFactory");
    const MockNFT = await ethers.getContractFactory("MockNFT");
    const MockToken = await ethers.getContractFactory("MockToken");

    const auctionFactory = await AuctionFactory.deploy();
    const mockNFT = await MockNFT.deploy();
    const mockToken = await MockToken.deploy(1000);
    const [owner, addr1] = await ethers.getSigners();
    await mockToken.transfer(addr1.address, 600);

    return {auctionFactory, mockNFT, mockToken};
  }

  async function launchAuction() {
    const {auctionFactory, mockNFT, mockToken} = await loadFixture(deployContract);
    const blockNumber = await ethers.provider.getBlockNumber();

    const startBlockNumber = blockNumber + 1;
    const endBlockNumber = blockNumber + 11;
    const resetTimer = 3;
    const numberOfSlots = 1;
    const supportsWhitelist = false;
    const bidToken = mockToken.address;
    auction = await auctionFactory.createAuction(
                                    startBlockNumber,
                                    endBlockNumber,
                                    resetTimer,
                                    numberOfSlots,
                                    supportsWhitelist,
                                    bidToken
                                  );
    return {auctionFactory, mockNFT, mockToken};
  }
  async function depositERC721(){
    const {auctionFactory, mockNFT, mockToken} = await loadFixture(launchAuction);
    const [owner] = await ethers.getSigners();

    await mockNFT.mint(owner.address, "testURI");
    mockNFT.approve(auctionFactory.address, 1)
    depositData = await auctionFactory.depositERC721(1, 0, 1, mockNFT.address);

    return {auctionFactory, mockNFT, mockToken};
  }
  async function bid(){
    const {auctionFactory, mockNFT, mockToken} = await loadFixture(depositERC721);
    const [owner, addr1] = await ethers.getSigners();

    const balanceOwner = await mockToken.balanceOf(owner.address)
    await mockToken.approve(auctionFactory.address, balanceOwner.toString())
    await auctionFactory.functions['bid(uint256,uint256)'](1, balanceOwner.toString())

    const balanceAddr1 = await mockToken.balanceOf(addr1.address)
    await mockToken.connect(addr1).approve(auctionFactory.address, balanceAddr1.toString())
    await auctionFactory.connect(addr1).functions['bid(uint256,uint256)'](1, balanceAddr1.toString())

    return {auctionFactory, mockNFT, mockToken};
  }

  it("Deploy the AuctionFactory and MockNFT", async function() {
    const {auctionFactory, mockNFT, mockToken} = await loadFixture(deployContract);

    expect(auctionFactory.address).to.have.string('0x');
  });
  it("Launch an Auction", async function() {
    const {auctionFactory, mockNFT, mockToken} = await loadFixture(launchAuction);
    const auctionData = await auctionFactory.auctions(1);

    expect(auctionData['numberOfSlots'].toString()).to.equal("1");
  });
  it("Deposit NFT into Auction", async function() {
    const {auctionFactory, mockNFT, mockToken} = await loadFixture(depositERC721);
    const deposited = await auctionFactory.getDeposited(1, 0);

    expect(deposited[0]['tokenId'].toString()).to.equal("1")
  });
  it("Bid on Auction", async function() {
    var {auctionFactory, mockNFT, mockToken} = await loadFixture(depositERC721);
    const [owner] = await ethers.getSigners();
    const balance = await mockToken.balanceOf(owner.address)

    var {auctionFactory, mockNFT, mockToken} = await loadFixture(bid);
    const newBalance = await mockToken.balanceOf(owner.address)

    const bidderBalance = await auctionFactory.getBidderBalance(1, owner.address)
    expect(bidderBalance).to.equal(balance.toString())
    expect("0").to.equal(newBalance)
  });
  it("Withdraw Bid", async function() {
    var {auctionFactory, mockNFT, mockToken} = await loadFixture(bid);
    const auction = await auctionFactory.auctions(1);
    const [owner] = await ethers.getSigners();
    const bidderBalance = await auctionFactory.getBidderBalance(1, owner.address)
    await auctionFactory.withdrawBid(1);
    const balance = await mockToken.balanceOf(owner.address)
    expect(bidderBalance.toString()).to.equal(bidderBalance);
  });


});
