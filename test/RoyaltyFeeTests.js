const { expect } = require('chai');
const { waffle, ethers, network } = require('hardhat');
const { loadFixture } = waffle;

describe('Test royalty fee functionality', () => {
  const deployContracts = async () => {
    const AuctionFactory = await ethers.getContractFactory('AuctionFactory');
    const MockNFT = await ethers.getContractFactory('MockNFT');
    const MockToken = await ethers.getContractFactory('MockToken');

    const auctionFactory = await AuctionFactory.deploy(5);
    const mockNFT = await MockNFT.deploy();
    const mockToken = await MockToken.deploy(1000);

    return { auctionFactory, mockNFT, mockToken };
  };

  it('should set royalty fee if is set by the owner and is less than 10%', async () => {
    const { auctionFactory } = await loadFixture(deployContracts);

    await auctionFactory.setRoyaltyFeeMantissa('90000000000000000');
  });

  it('should revert if not the contract owner try to set it', async () => {
    const { auctionFactory } = await loadFixture(deployContracts);

    const [signer, signer2] = await ethers.getSigners();

    await expect(auctionFactory.connect(signer2).setRoyaltyFeeMantissa('90000000000000000')).revertedWith(
      'Ownable: caller is not the owner'
    );
  });

  it('should revert if fee is equal or higher than 10%', async () => {
    const { auctionFactory } = await loadFixture(deployContracts);

    await expect(auctionFactory.setRoyaltyFeeMantissa('100000000000000000')).revertedWith('Should be less than 10%');
  });

  it('should withdraw royaltee with eth successfully', async () => {
    const { auctionFactory, mockNFT } = await loadFixture(deployContracts);
    const blockNumber = await ethers.provider.getBlockNumber();

    const startBlockNumber = blockNumber + 5;
    const endBlockNumber = blockNumber + 6;
    const resetTimer = 3;
    const numberOfSlots = 1;
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

    const [signer] = await ethers.getSigners();

    await mockNFT.mint(signer.address, 'tokenURI');

    await mockNFT.approve(auctionFactory.address, 1);

    await auctionFactory.depositERC721(1, 1, 1, mockNFT.address);

    await auctionFactory.setRoyaltyFeeMantissa('90000000000000000');

    await auctionFactory.functions['bid(uint256)'](1, {
      value: '100000000000000000000'
    });

    await auctionFactory.finalizeAuction(1, [signer.address]);

    await expect(auctionFactory.withdrawRoyalties(ethAddress, signer.address)).emit(
      auctionFactory,
      'LogRoyaltiesWithdrawal'
    );

     expect(await auctionFactory.royaltiesReserve(signer.address)).to.equal('0')
  });

  it('should withdraw royaltee with ERC20 successfully', async () => {
    const { auctionFactory, mockNFT, mockToken } = await loadFixture(deployContracts);
    const blockNumber = await ethers.provider.getBlockNumber();

    const [signer] = await ethers.getSigners();

    const balance = await signer.getBalance();

    await mockToken.approve(auctionFactory.address, balance.toString());

    const startBlockNumber = blockNumber + 6;
    const endBlockNumber = blockNumber + 7;
    const resetTimer = 3;
    const numberOfSlots = 1;
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

    await mockNFT.mint(signer.address, 'tokenURI');

    await mockNFT.approve(auctionFactory.address, 1);

    await auctionFactory.depositERC721(1, 1, 1, mockNFT.address);

    await auctionFactory.setRoyaltyFeeMantissa('90000000000000000');

    await auctionFactory.functions['bid(uint256,uint256)'](1, 50);

    await auctionFactory.finalizeAuction(1, [signer.address]);

    await expect(auctionFactory.withdrawRoyalties(tokenAddress, signer.address)).emit(
      auctionFactory,
      'LogRoyaltiesWithdrawal'
    );

    expect(await auctionFactory.royaltiesReserve(signer.address)).to.equal('0')
  });

  it('should revert if amount is zero', async () => {
    const { auctionFactory } = await loadFixture(deployContracts);

    const [signer] = await ethers.getSigners();

    await expect(
      auctionFactory.withdrawRoyalties('0x0000000000000000000000000000000000000000', signer.address)
    ).revertedWith('Amount is 0');
  });
});
