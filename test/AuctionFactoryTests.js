const { expect } = require('chai');
const { waffle, ethers } = require('hardhat');
const { loadFixture } = waffle;

describe('AuctionFactory', () => {
  async function deployContract() {
    const AuctionFactory = await ethers.getContractFactory('AuctionFactory');
    const MockNFT = await ethers.getContractFactory('MockNFT');
    const MockToken = await ethers.getContractFactory('MockToken');

    const auctionFactory = await AuctionFactory.deploy(2000, 100);
    const mockNFT = await MockNFT.deploy();
    const mockToken = await MockToken.deploy(1000);
    const [owner, addr1] = await ethers.getSigners();
    await mockToken.transfer(addr1.address, 600);

    return { auctionFactory, mockNFT, mockToken };
  }

  async function launchAuction() {
    const { auctionFactory, mockNFT, mockToken } = await loadFixture(deployContract);

    const currentTime = Math.round((new Date()).getTime() / 1000);

    const startTime = currentTime + 10;
    const endTime = currentTime + 50;
    const resetTimer = 3;
    const numberOfSlots = 1;
    const bidToken = mockToken.address;
    const whitelistAddresses = [];

    auction = await auctionFactory.createAuction(
      startTime,
      endTime,
      resetTimer,
      numberOfSlots,
      bidToken,
      whitelistAddresses
    );
    return { auctionFactory, mockNFT, mockToken };
  }
  async function depositERC721() {
    const { auctionFactory, mockNFT, mockToken } = await loadFixture(launchAuction);
    const [owner] = await ethers.getSigners();

    await mockNFT.mint(owner.address, 'testURI');
    mockNFT.approve(auctionFactory.address, 1);
    depositData = await auctionFactory.depositERC721(1, 1, 1, mockNFT.address);

    return { auctionFactory, mockNFT, mockToken };
  }
  async function bid() {
    const { auctionFactory, mockNFT, mockToken } = await loadFixture(depositERC721);
    const [owner, addr1] = await ethers.getSigners();

    const currentTime = Math.round((new Date()).getTime() / 1000);
    await ethers.provider.send('evm_setNextBlockTimestamp', [currentTime + 20]); 
    await ethers.provider.send('evm_mine');

    const balanceOwner = await mockToken.balanceOf(owner.address);
    await mockToken.approve(auctionFactory.address, balanceOwner.toString());
    await auctionFactory.functions['erc20Bid(uint256,uint256)'](1, balanceOwner.toString());

    const balanceAddr1 = await mockToken.balanceOf(addr1.address);
    await mockToken.connect(addr1).approve(auctionFactory.address, balanceAddr1.toString());
    await auctionFactory.connect(addr1).functions['erc20Bid(uint256,uint256)'](1, balanceAddr1.toString());

    return { auctionFactory, mockNFT, mockToken };
  }

  it('Deploy the AuctionFactory and MockNFT', async function () {
    const { auctionFactory, mockNFT, mockToken } = await loadFixture(deployContract);

    expect(auctionFactory.address).to.have.string('0x');
  });
  it('Launch an Auction', async function () {
    const { auctionFactory, mockNFT, mockToken } = await loadFixture(launchAuction);
    const auctionData = await auctionFactory.auctions(1);

    expect(auctionData['numberOfSlots'].toString()).to.equal('1');
  });
  it('Deposit NFT into Auction', async function () {
    const { auctionFactory, mockNFT, mockToken } = await loadFixture(depositERC721);
    const deposited = await auctionFactory.getDepositedNftsInSlot(1, 1);

    expect(deposited[0]['tokenId'].toString()).to.equal('1');
  });
  it('Bid on Auction', async function () {
    var { auctionFactory, mockNFT, mockToken } = await loadFixture(depositERC721);
    const [owner] = await ethers.getSigners();
    const balance = await mockToken.balanceOf(owner.address);

    var { auctionFactory, mockNFT, mockToken } = await loadFixture(bid);
    const newBalance = await mockToken.balanceOf(owner.address);

    const bidderBalance = await auctionFactory.getBidderBalance(1, owner.address);
    expect(bidderBalance).to.equal(balance.toString());
    expect('0').to.equal(newBalance);
  });

  it('should revert if allowance is too small', async () => {
    const { auctionFactory, mockNFT, mockToken } = await loadFixture(deployContract);

    const currentTime = Math.round((new Date()).getTime() / 1000);

    const startTime = currentTime + 10;
    const endTime = currentTime + 15;
    const resetTimer = 3;
    const numberOfSlots = 1;
    const tokenAddress = mockToken.address;
    const whitelistAddresses = [];

    await auctionFactory.createAuction(
      startTime,
      endTime,
      resetTimer,
      numberOfSlots,
      tokenAddress,
      whitelistAddresses
    );

    const [signer] = await ethers.getSigners();

    const auctionId = 1;
    const slotIdx = 1;
    const tokenId = 1;

    await mockNFT.mint(signer.address, 'nftURI');
    await mockNFT.approve(auctionFactory.address, tokenId);

    await auctionFactory.depositERC721(auctionId, slotIdx, tokenId, mockNFT.address);

    mockToken.connect(signer).approve(auctionFactory.address, 100);

    await expect(auctionFactory.connect(signer).functions['erc20Bid(uint256,uint256)'](1, '101')).to.be.reverted;
  });

  it('should revert if some one try to bid with ETH', async () => {
    const { auctionFactory, mockNFT, mockToken } = await loadFixture(deployContract);

    const currentTime = Math.round((new Date()).getTime() / 1000);

    const startTime = currentTime + 10;
    const endTime = startTime + 500;
    const resetTimer = 3;
    const numberOfSlots = 1;
    const tokenAddress = '0x0000000000000000000000000000000000000000';
    const whitelistAddresses = [];

    await auctionFactory.createAuction(
      startTime,
      endTime,
      resetTimer,
      numberOfSlots,
      tokenAddress,
      whitelistAddresses
    );

    const [signer] = await ethers.getSigners();

    const auctionId = 1;
    const slotIdx = 1;
    const tokenId = 1;

    await mockNFT.mint(signer.address, 'nftURI');
    await mockNFT.approve(auctionFactory.address, tokenId);

    await auctionFactory.depositERC721(auctionId, slotIdx, tokenId, mockNFT.address);

    mockToken.connect(signer).approve(auctionFactory.address, 100);

    await expect(auctionFactory.connect(signer).functions['erc20Bid(uint256,uint256)'](1, 10)).to.be.reverted;
  });
});
