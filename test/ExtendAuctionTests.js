const { expect } = require('chai');
const { waffle, ethers } = require('hardhat');
const { loadFixture } = waffle;

describe('Extend auction ERC721 Tests', () => {
  const deployedContracts = async () => {
    const AuctionFactory = await ethers.getContractFactory('AuctionFactory');
    const MockNFT = await ethers.getContractFactory('MockNFT');
    const MockToken = await ethers.getContractFactory('MockToken');

    const auctionFactory = await AuctionFactory.deploy();
    const mockNFT = await MockNFT.deploy();
    const mockToken = await MockToken.deploy(1000);

    return { auctionFactory, mockNFT, mockToken };
  };

  it('should extend auction bid with ETH', async () => {
    const { auctionFactory, mockNFT } = await loadFixture(deployedContracts);

    await createAuction(auctionFactory);

    const [singer, signer2] = await ethers.getSigners();

    await mockNFT.mint(singer.address, 'NFT_URI');
    await mockNFT.approve(auctionFactory.address, 1);

    await auctionFactory.depositERC721(1, 1, 1, mockNFT.address);

    await createAuction(auctionFactory);

    await expect(
      auctionFactory.functions['bid(uint256)'](1, {
        value: '100000000000000000000'
      })
    ).to.be.emit(auctionFactory, 'LogBidSubmitted');

    await expect(
      auctionFactory.functions['bid(uint256)'](1, {
        value: '200000000000000000000'
      })
    ).to.be.emit(auctionFactory, 'LogBidSubmitted');

    await expect(
      auctionFactory.functions['bid(uint256)'](1, {
        value: '300000000000000000000'
      })
    ).to.be.emit(auctionFactory, 'LogAuctionExtended');

    await expect(
      auctionFactory.connect(signer2).functions['bid(uint256)'](1, {
        value: '400000000000000000000'
      })
    ).to.be.emit(auctionFactory, 'LogBidSubmitted');
  });

  it('should extend auction bid with ERC20', async () => {
    const { auctionFactory, mockNFT, mockToken } = await loadFixture(deployedContracts);

    const blockNumber = await ethers.provider.getBlockNumber();

    const startBlockNumber = blockNumber + 1;
    const endBlockNumber = blockNumber + 20;
    const resetTimer = 3;
    const numberOfSlots = 3;
    const supportsWhitelist = false;
    const tokenAddress = mockToken.address;

    await auctionFactory.createAuction(
      startBlockNumber,
      endBlockNumber,
      resetTimer,
      numberOfSlots,
      supportsWhitelist,
      tokenAddress
    );

    const [singer, signer2] = await ethers.getSigners();

    await mockNFT.mint(singer.address, 'NFT_URI');
    await mockNFT.approve(auctionFactory.address, 1);

    mockToken.approve(auctionFactory.address, 100);

    await auctionFactory.depositERC721(1, 1, 1, mockNFT.address);

    await expect(auctionFactory.functions['bid(uint256,uint256)'](1, 1)).to.be.emit(auctionFactory, 'LogBidSubmitted');

    await expect(auctionFactory.functions['bid(uint256,uint256)'](1, 2)).to.be.emit(auctionFactory, 'LogBidSubmitted');

    await expect(auctionFactory.functions['bid(uint256,uint256)'](1, 3)).to.be.emit(
      auctionFactory,
      'LogAuctionExtended'
    );

    await expect(auctionFactory.functions['bid(uint256,uint256)'](1, 4)).to.be.emit(auctionFactory, 'LogBidSubmitted');
  });

  it('should revert if auction is ended', async () => {
    const { auctionFactory, mockNFT } = await loadFixture(deployedContracts);

    const blockNumber = await ethers.provider.getBlockNumber();

    const startBlockNumber = blockNumber + 1;
    const endBlockNumber = blockNumber + 3;
    const resetTimer = 3;
    const numberOfSlots = 3;
    const supportsWhitelist = false;
    const ethAddress = '0x0000000000000000000000000000000000000000';

    await auctionFactory.createAuction(
      startBlockNumber,
      endBlockNumber,
      resetTimer,
      numberOfSlots,
      supportsWhitelist,
      ethAddress
    );

    const [singer] = await ethers.getSigners();

    await mockNFT.mint(singer.address, 'NFT_URI');
    await mockNFT.approve(auctionFactory.address, 1);

    await auctionFactory.depositERC721(1, 1, 1, mockNFT.address);

    await createAuction(auctionFactory);

    await expect(
      auctionFactory.functions['bid(uint256)'](1, {
        value: '100000000000000000000'
      })
    ).to.be.emit(auctionFactory, 'LogBidSubmitted');

    await expect(
      auctionFactory.functions['bid(uint256)'](1, {
        value: '200000000000000000000'
      })
    ).to.be.reverted;
  });
});

const createAuction = async (auctionFactory) => {
  const blockNumber = await ethers.provider.getBlockNumber();

  const startBlockNumber = blockNumber + 5;
  const endBlockNumber = blockNumber + 20;
  const resetTimer = 3;
  const numberOfSlots = 3;
  const supportsWhitelist = false;
  const ethAddress = '0x0000000000000000000000000000000000000000';

  await auctionFactory.createAuction(
    startBlockNumber,
    endBlockNumber,
    resetTimer,
    numberOfSlots,
    supportsWhitelist,
    ethAddress
  );
};
