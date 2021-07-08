const { expect } = require('chai');
const { waffle, ethers, network } = require('hardhat');
const { loadFixture } = waffle;

describe('Test royalty fee functionality', () => {
  const deployContracts = async () => {
    const AuctionFactory = await ethers.getContractFactory('AuctionFactory');
    const MockNFT = await ethers.getContractFactory('MockNFT');
    const MockToken = await ethers.getContractFactory('MockToken');

    const auctionFactory = await AuctionFactory.deploy(5, 100);
    const mockNFT = await MockNFT.deploy();
    const mockToken = await MockToken.deploy('1000000000000000000');

    return { auctionFactory, mockNFT, mockToken };
  };

  it('should revert if not the contract owner try to set it', async () => {
    const { auctionFactory } = await loadFixture(deployContracts);

    const [signer, signer2] = await ethers.getSigners();

    await expect(auctionFactory.connect(signer2).setRoyaltyFeeBps('9000')).revertedWith(
      'Ownable: caller is not the owner'
    );
  });

  it('should withdraw royaltee with eth successfully', async () => {
    const { auctionFactory, mockNFT } = await loadFixture(deployContracts);
    const currentTime = Math.round((new Date()).getTime() / 1000);

    const startTime = currentTime + 10000;
    const endTime = startTime + 1500;
    const resetTimer = 3;
    const numberOfSlots = 1;
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

    const [signer] = await ethers.getSigners();

    await mockNFT.mint(signer.address, 'tokenURI');

    await mockNFT.approve(auctionFactory.address, 1);

    await auctionFactory.depositERC721(1, 1, 1, mockNFT.address);

    await auctionFactory.setRoyaltyFeeBps('5000');

    expect(await auctionFactory.royaltyFeeBps()).to.equal('5000');

    await ethers.provider.send('evm_setNextBlockTimestamp', [startTime + 700]); 
    await ethers.provider.send('evm_mine');

    await auctionFactory.functions['ethBid(uint256)'](1, {
      value: '1000000000000000000'
    });

    await ethers.provider.send('evm_setNextBlockTimestamp', [endTime + 1000]); 
    await ethers.provider.send('evm_mine');

    await auctionFactory.finalizeAuction(1);
    await auctionFactory.captureAuctionRevenue(1);

    expect(await auctionFactory.royaltiesReserve(ethAddress)).to.equal("500000000000000000");

    await expect(auctionFactory.withdrawRoyalties(ethAddress, signer.address)).emit(
      auctionFactory,
      'LogRoyaltiesWithdrawal'
    );

    expect(await auctionFactory.royaltiesReserve(ethAddress)).to.equal('0');
  });

  it('should withdraw royaltee with ERC20 successfully', async () => {
    const { auctionFactory, mockNFT, mockToken } = await loadFixture(deployContracts);
    const currentTime = Math.round((new Date()).getTime() / 1000);

    const [signer] = await ethers.getSigners();

    const balance = await signer.getBalance();

    await mockToken.approve(auctionFactory.address, balance.toString());

    const startTime = currentTime + 10000;
    const endTime = startTime + 1500;
    const resetTimer = 1;
    const numberOfSlots = 1;
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

    await mockNFT.mint(signer.address, 'tokenURI');

    await mockNFT.approve(auctionFactory.address, 1);

    await auctionFactory.depositERC721(1, 1, 1, mockNFT.address);

    await auctionFactory.setRoyaltyFeeBps('5000');

    expect(await auctionFactory.royaltyFeeBps()).to.equal('5000');

    await ethers.provider.send('evm_setNextBlockTimestamp', [startTime + 700]); 
    await ethers.provider.send('evm_mine');

    await auctionFactory.functions['erc20Bid(uint256,uint256)'](1, '1000000000000000000');

    await ethers.provider.send('evm_setNextBlockTimestamp', [endTime + 1500]); 
    await ethers.provider.send('evm_mine');

    await auctionFactory.finalizeAuction(1);
    await auctionFactory.captureAuctionRevenue(1);

    expect(await auctionFactory.royaltiesReserve(tokenAddress)).to.equal('500000000000000000');

    await expect(auctionFactory.withdrawRoyalties(tokenAddress, signer.address)).emit(
      auctionFactory,
      'LogRoyaltiesWithdrawal'
    );

    expect(await auctionFactory.royaltiesReserve(tokenAddress)).to.equal('0');
  });

  it('should revert if amount is zero', async () => {
    const { auctionFactory } = await loadFixture(deployContracts);

    const [signer] = await ethers.getSigners();

    await expect(
      auctionFactory.withdrawRoyalties('0x0000000000000000000000000000000000000000', signer.address)
    ).revertedWith('Amount is 0');
  });
});
