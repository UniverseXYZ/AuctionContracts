const { expect } = require('chai');
const { waffle } = require('hardhat');
const { loadFixture } = waffle;

describe('Whitelist functionality', () => {
  const deployContracts = async () => {
    const [AuctionFactory, MockNFT] = await Promise.all([
      ethers.getContractFactory('AuctionFactory'),
      ethers.getContractFactory('MockNFT')
    ]);

    const [auctionFactory, mockNft] = await Promise.all([AuctionFactory.deploy(2000, 100), MockNFT.deploy()]);

    return { auctionFactory, mockNft };
  };

  it('should whitelist multiple addresses', async () => {
    const { auctionFactory, mockNft } = await loadFixture(deployContracts);
    const [addr1, addr2] = await ethers.getSigners();

    const currentTime = Math.round((new Date()).getTime() / 1000);

    const startTime = currentTime + 10000;
    const endTime = startTime + 500;
    const resetTimer = 3;
    const numberOfSlots = 1;
    const supportsWhitelist = true;
    const ethAddress = '0x0000000000000000000000000000000000000000';
    const whitelistAddresses = [addr1.address, addr2.address];
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

    const auctionId = 1;
    const slotIdx = 1;
    const tokenId = 1;

    await mockNft.connect(addr1).mint(addr1.address, 'testNft');
    await mockNft.connect(addr1).approve(auctionFactory.address, 1);

    await expect(auctionFactory.connect(addr1).depositERC721(auctionId, slotIdx, tokenId, mockNft.address)).to.be.emit(
      auctionFactory,
      'LogERC721Deposit'
    );

    await mockNft.connect(addr2).mint(addr2.address, 'testNft2');
    await mockNft.connect(addr2).approve(auctionFactory.address, 2);

    await expect(auctionFactory.connect(addr2).depositERC721(auctionId, slotIdx, 2, mockNft.address)).to.be.emit(
      auctionFactory,
      'LogERC721Deposit'
    );

    const result = await auctionFactory.isAddressWhitelisted(1, addr1.address);

    expect(result).to.be.true;
  });

  it('should revert when address is not whitelisted', async () => {
    const { auctionFactory, mockNft } = await loadFixture(deployContracts);
    const [addr1, addr2] = await ethers.getSigners();

    const currentTime = Math.round((new Date()).getTime() / 1000);

    const startTime = currentTime + 10000;
    const endTime = startTime + 500;
    const resetTimer = 3;
    const numberOfSlots = 1;
    const supportsWhitelist = true;
    const ethAddress = '0x0000000000000000000000000000000000000000';
    const whitelistAddresses = [addr1.address];
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

    const auctionId = 1;
    const slotIdx = 1;
    const tokenId = 1;

    await mockNft.connect(addr1).mint(addr1.address, 'testNft');
    await mockNft.connect(addr1).approve(auctionFactory.address, 1);

    await expect(auctionFactory.connect(addr1).depositERC721(auctionId, slotIdx, tokenId, mockNft.address)).to.be.emit(
      auctionFactory,
      'LogERC721Deposit'
    );

    await mockNft.connect(addr2).mint(addr2.address, 'testNft2');
    await mockNft.connect(addr2).approve(auctionFactory.address, 2);

    await expect(auctionFactory.connect(addr2).depositERC721(auctionId, slotIdx, 2, mockNft.address)).to.be.reverted;
  });

});

const createAuction = async (auctionFactory) => {
  const currentTime = Math.round((new Date()).getTime() / 1000);

  const startTime = currentTime + 10000;
  const endTime = startTime + 500;
  const resetTimer = 3;
  const numberOfSlots = 1;
  const supportsWhitelist = true;
  const ethAddress = '0x0000000000000000000000000000000000000000';

  await auctionFactory.createAuction(
    startTime,
    endTime,
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
