const { expect } = require('chai');
const { waffle, ethers, network } = require('hardhat');
const { loadFixture } = waffle;

describe('Extend auction ERC721 Tests', () => {
  const deployedContracts = async () => {
    const [owner, addr1] = await ethers.getSigners();
    const AuctionFactory = await ethers.getContractFactory('AuctionFactory');
    const MockNFT = await ethers.getContractFactory('MockNFT');
    const MockToken = await ethers.getContractFactory('MockToken');
    const mockNFT = await MockNFT.deploy();
    const mockToken = await MockToken.deploy(1000);

    const auctionFactory = await AuctionFactory.deploy(2000, 100, 0, owner.address, [mockToken.address]);

    return { auctionFactory, mockNFT, mockToken };
  };

  it('should extend auction bid with ETH', async () => {
    const { auctionFactory, mockNFT } = await loadFixture(deployedContracts);

    const currentTime = Math.round((new Date()).getTime() / 1000);

    const startTime = currentTime + 1500;
    const endTime = startTime + 500;
    const resetTimer = 500;
    const numberOfSlots = 2;
    const ethAddress = '0x0000000000000000000000000000000000000000';
    const whitelistAddresses = [];
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

    const [singer, signer2] = await ethers.getSigners();

    await mockNFT.mint(singer.address, 'NFT_URI');
    await mockNFT.approve(auctionFactory.address, 1);

    await auctionFactory.depositERC721(1, 1, [[1, mockNFT.address]]);

    await ethers.provider.send('evm_setNextBlockTimestamp', [startTime + 100]); 
    await ethers.provider.send('evm_mine');

    await expect(
      auctionFactory.functions['ethBid(uint256)'](1, {
        value: '100000000000000000000'
      })
    ).to.be.emit(auctionFactory, 'LogBidSubmitted');

    await expect(
      auctionFactory.connect(signer2).functions['ethBid(uint256)'](1, {
        value: '200000000000000000000'
      })
    ).to.be.emit(auctionFactory, 'LogBidSubmitted');

    await expect(
      auctionFactory.functions['ethBid(uint256)'](1, {
        value: '300000000000000000000'
      })
    ).to.be.emit(auctionFactory, 'LogAuctionExtended');

    await expect(
      auctionFactory.connect(signer2).functions['ethBid(uint256)'](1, {
        value: '500000000000000000000'
      })
    ).to.be.emit(auctionFactory, 'LogBidSubmitted');
  });

  it('should extend auction bid with ERC20', async () => {
    const { auctionFactory, mockNFT, mockToken } = await loadFixture(deployedContracts);

    const currentTime = Math.round((new Date()).getTime() / 1000);

    const startTime = currentTime + 1500;
    const endTime = startTime + 600;
    const resetTimer = 600;
    const numberOfSlots = 2;
    const tokenAddress = mockToken.address;
    const whitelistAddresses = [];
    const minimumReserveValues = [];
    const paymentSplits = [];

    await auctionFactory.createAuction([
      startTime,
      endTime,
      resetTimer,
      numberOfSlots,
      tokenAddress,
      whitelistAddresses,
      minimumReserveValues,
      paymentSplits
    ]);

    const [singer, signer2] = await ethers.getSigners();

    await mockNFT.mint(singer.address, 'NFT_URI');
    await mockNFT.approve(auctionFactory.address, 1);
    await mockToken.transfer(signer2.address, 100);

    await mockToken.approve(auctionFactory.address, 100);

    await mockToken.connect(signer2).approve(auctionFactory.address, 100);

    await auctionFactory.depositERC721(1, 1, [[1, mockNFT.address]]);

    await ethers.provider.send('evm_setNextBlockTimestamp', [startTime + 100]); 
    await ethers.provider.send('evm_mine');

    await expect(auctionFactory.functions['erc20Bid(uint256,uint256)'](1, 1)).to.be.emit(auctionFactory, 'LogBidSubmitted');

    await expect(auctionFactory.connect(signer2).functions['erc20Bid(uint256,uint256)'](1, 2)).to.be.emit(
      auctionFactory,
      'LogBidSubmitted'
    );

    await ethers.provider.send('evm_setNextBlockTimestamp', [startTime + 500]); 
    await ethers.provider.send('evm_mine');

    await expect(auctionFactory.functions['erc20Bid(uint256,uint256)'](1, 10)).to.be.emit(
      auctionFactory,
      'LogAuctionExtended'
    );

  });

  it('should revert if auction is ended', async () => {
    const { auctionFactory, mockNFT } = await loadFixture(deployedContracts);

    const currentTime = Math.round((new Date()).getTime() / 1000);

    const startTime = currentTime + 1500;
    const endTime = startTime + 500;
    const resetTimer = 30;
    const numberOfSlots = 3;
    const ethAddress = '0x0000000000000000000000000000000000000000';
    const whitelistAddresses = [];
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

    const [singer] = await ethers.getSigners();

    await mockNFT.mint(singer.address, 'NFT_URI');
    await mockNFT.approve(auctionFactory.address, 1);

    await auctionFactory.depositERC721(1, 1, [[1, mockNFT.address]]);

    await ethers.provider.send('evm_setNextBlockTimestamp', [startTime + 100]); 
    await ethers.provider.send('evm_mine');

    await expect(
      auctionFactory.functions['ethBid(uint256)'](1, {
        value: '100000000000000000000'
      })
    ).to.be.emit(auctionFactory, 'LogBidSubmitted');

    await ethers.provider.send('evm_setNextBlockTimestamp', [endTime + 50]); 
    await ethers.provider.send('evm_mine');

    await expect(
      auctionFactory.functions['ethBid(uint256)'](1, {
        value: '200000000000000000000'
      })
    ).to.be.reverted;
  });
});

const createAuction = async (auctionFactory) => {
  const currentTime = Math.round((new Date()).getTime() / 1000);

  const startTime = currentTime + 1500;
  const endTime = startTime + 500;
  const resetTimer = 30;
  const numberOfSlots = 2;
  const ethAddress = '0x0000000000000000000000000000000000000000';
  const whitelistAddresses = [];
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
};
