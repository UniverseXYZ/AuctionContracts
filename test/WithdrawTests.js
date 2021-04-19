const { waffle, network } = require('hardhat');
const { loadFixture } = waffle;
const { expect } = require('chai');

describe('Withdraw functionalities', () => {
  async function deployContract() {
    const AuctionFactory = await ethers.getContractFactory('AuctionFactory');
    const MockNFT = await ethers.getContractFactory('MockNFT');
    const MockToken = await ethers.getContractFactory('MockToken');

    const auctionFactory = await AuctionFactory.deploy(2000);
    const mockNFT = await MockNFT.deploy();
    const mockToken = await MockToken.deploy(1000);

    return { auctionFactory, mockNFT, mockToken };
  }

  it('should withdraw ERC721 from non winning slot', async () => {
    const { auctionFactory, mockNFT } = await loadFixture(deployContract);

    await createAuction(auctionFactory);

    const [signer, signer2, signer3] = await ethers.getSigners();
    const auctionId = 1;
    const slotIdx = 1;
    const tokenId = 1;

    await mockNFT.mint(signer.address, 'NFT_URI');

    await mockNFT.approve(auctionFactory.address, tokenId);

    await auctionFactory.depositERC721(auctionId, slotIdx, tokenId, mockNFT.address);

    await auctionFactory.setMinimumReserveForAuctionSlots(1, [
      '100000000000000000000',
      '100000000000000000000',
      '100000000000000000000'
    ]);

    await network.provider.send('evm_mine');

    await auctionFactory.functions['bid(uint256)'](1, {
      value: '10000000000000000000'
    });

    await auctionFactory.connect(signer2).functions['bid(uint256)'](1, {
      value: '10000000000000000000'
    });

    await auctionFactory.connect(signer3).functions['bid(uint256)'](1, {
      value: '10000000000000000000'
    });

    const reserveForFirstSlot = await auctionFactory.getMinimumReservePriceForSlot(1, 1);

    expect(reserveForFirstSlot.toString()).to.equal('100000000000000000000');

    await auctionFactory.finalizeAuction(1, [signer.address, signer2.address, signer3.address]);

    await expect(auctionFactory.withdrawERC721FromNonWinningSlot(1, 1, 1)).emit(auctionFactory, 'LogERC721Withdrawal');
  });

  it('should revert with Only depositor can withdraw', async () => {
    const { auctionFactory, mockNFT } = await loadFixture(deployContract);

    await createAuction(auctionFactory);

    const [signer, signer2, signer3] = await ethers.getSigners();
    const auctionId = 1;
    const slotIdx = 1;
    const tokenId = 1;

    await mockNFT.mint(signer.address, 'NFT_URI');

    await mockNFT.approve(auctionFactory.address, tokenId);

    await auctionFactory.depositERC721(auctionId, slotIdx, tokenId, mockNFT.address);

    await auctionFactory.setMinimumReserveForAuctionSlots(1, [
      '100000000000000000000',
      '100000000000000000000',
      '100000000000000000000'
    ]);

    await network.provider.send('evm_mine');

    await auctionFactory.functions['bid(uint256)'](1, {
      value: '10000000000000000000'
    });

    await auctionFactory.connect(signer2).functions['bid(uint256)'](1, {
      value: '10000000000000000000'
    });

    await auctionFactory.connect(signer3).functions['bid(uint256)'](1, {
      value: '10000000000000000000'
    });

    await auctionFactory.finalizeAuction(1, [signer.address, signer2.address, signer3.address]);

    await expect(auctionFactory.connect(signer2).withdrawERC721FromNonWinningSlot(1, 1, 1)).revertedWith(
      'Only depositor can withdraw'
    );
  });

  it('should revert with Auction should be finalized', async () => {
    const { auctionFactory, mockNFT } = await loadFixture(deployContract);

    await createAuction(auctionFactory);

    const [signer, signer2, signer3] = await ethers.getSigners();
    const auctionId = 1;
    const slotIdx = 1;
    const tokenId = 1;

    await mockNFT.mint(signer.address, 'NFT_URI');

    await mockNFT.approve(auctionFactory.address, tokenId);

    await auctionFactory.depositERC721(auctionId, slotIdx, tokenId, mockNFT.address);

    await auctionFactory.setMinimumReserveForAuctionSlots(1, [
      '100000000000000000000',
      '100000000000000000000',
      '100000000000000000000'
    ]);

    await network.provider.send('evm_mine');

    await auctionFactory.functions['bid(uint256)'](1, {
      value: '10000000000000000000'
    });

    await auctionFactory.connect(signer2).functions['bid(uint256)'](1, {
      value: '10000000000000000000'
    });

    await auctionFactory.connect(signer3).functions['bid(uint256)'](1, {
      value: '10000000000000000000'
    });

    await expect(auctionFactory.withdrawERC721FromNonWinningSlot(1, 1, 1)).revertedWith('Auction should be finalized');
  });

  it('should revert with Can withdraw only if reserve price is not met', async () => {
    const { auctionFactory, mockNFT } = await loadFixture(deployContract);

    await createAuction(auctionFactory);

    const [signer, signer2, signer3] = await ethers.getSigners();
    const auctionId = 1;
    const slotIdx = 1;
    const tokenId = 1;

    await mockNFT.mint(signer.address, 'NFT_URI');

    await mockNFT.approve(auctionFactory.address, tokenId);

    await auctionFactory.depositERC721(auctionId, slotIdx, tokenId, mockNFT.address);

    await auctionFactory.setMinimumReserveForAuctionSlots(1, [
      '1000000000000000000',
      '1000000000000000000',
      '1000000000000000000'
    ]);

    await network.provider.send('evm_mine');

    await auctionFactory.connect(signer).functions['bid(uint256)'](1, {
      value: '1000000000000000000'
    });

    await auctionFactory.connect(signer2).functions['bid(uint256)'](1, {
      value: '1000000000000000000'
    });

    await auctionFactory.connect(signer3).functions['bid(uint256)'](1, {
      value: '1000000000000000000'
    });

    await auctionFactory.finalizeAuction(1, [signer.address, signer2.address, signer3.address]);

    await expect(auctionFactory.withdrawERC721FromNonWinningSlot(1, 1, 1)).revertedWith(
      'Can withdraw only if reserve price is not met'
    );
  });

  it('should withdraw ETH after auction is finalized', async () => {
    const { auctionFactory, mockNFT } = await loadFixture(deployContract);

    await createAuction(auctionFactory);

    const [signer, signer2, signer3, signer4] = await ethers.getSigners();
    const auctionId = 1;
    const slotIdx = 1;
    const tokenId = 1;

    await mockNFT.mint(signer.address, 'NFT_URI');

    await mockNFT.approve(auctionFactory.address, tokenId);

    await auctionFactory.depositERC721(auctionId, slotIdx, tokenId, mockNFT.address);

    await auctionFactory.setMinimumReserveForAuctionSlots(1, [
      '10000000000000000000',
      '10000000000000000000',
      '10000000000000000000'
    ]);

    await network.provider.send('evm_mine');

    await auctionFactory.functions['bid(uint256)'](1, {
      value: '100000000000000000000'
    });

    await auctionFactory.connect(signer2).functions['bid(uint256)'](1, {
      value: '100000000000000000001'
    });

    await auctionFactory.connect(signer3).functions['bid(uint256)'](1, {
      value: '100000000000000000002'
    });

    await auctionFactory.connect(signer4).functions['bid(uint256)'](1, {
      value: '100000000000000000003'
    });

    await network.provider.send('evm_mine');

    await auctionFactory.finalizeAuction(1, [signer4.address, signer3.address, signer2.address]);

    await expect(auctionFactory.withdrawEthBidAfterAuctionFinalized(1)).emit(auctionFactory, 'LogBidWithdrawal');

    const balance = await auctionFactory.getBidderBalance(1, signer.address);

    expect(balance.toString()).equal('0');
  });

  it('should revert with You have 0 deposited', async () => {
    const { auctionFactory, mockNFT } = await loadFixture(deployContract);

    await createAuction(auctionFactory);

    const [signer, signer2, signer3, signer4, signer5] = await ethers.getSigners();
    const auctionId = 1;
    const slotIdx = 1;
    const tokenId = 1;

    await mockNFT.mint(signer.address, 'NFT_URI');

    await mockNFT.approve(auctionFactory.address, tokenId);

    await auctionFactory.depositERC721(auctionId, slotIdx, tokenId, mockNFT.address);

    await auctionFactory.setMinimumReserveForAuctionSlots(1, [
      '10000000000000000000',
      '10000000000000000000',
      '10000000000000000000'
    ]);

    await network.provider.send('evm_mine');

    await auctionFactory.functions['bid(uint256)'](1, {
      value: '100000000000000000000'
    });

    await auctionFactory.connect(signer2).functions['bid(uint256)'](1, {
      value: '100000000000000000001'
    });

    await auctionFactory.connect(signer3).functions['bid(uint256)'](1, {
      value: '100000000000000000002'
    });

    await auctionFactory.connect(signer4).functions['bid(uint256)'](1, {
      value: '100000000000000000003'
    });

    await network.provider.send('evm_mine');

    await auctionFactory.finalizeAuction(1, [signer4.address, signer3.address, signer2.address]);

    await expect(auctionFactory.connect(signer5).withdrawEthBidAfterAuctionFinalized(1)).revertedWith(
      'You have 0 deposited'
    );
  });

  it('should revert with Auction should be finalized', async () => {
    const { auctionFactory, mockNFT } = await loadFixture(deployContract);

    await createAuction(auctionFactory);

    const [signer, signer2, signer3, signer4] = await ethers.getSigners();
    const auctionId = 1;
    const slotIdx = 1;
    const tokenId = 1;

    await mockNFT.mint(signer.address, 'NFT_URI');

    await mockNFT.approve(auctionFactory.address, tokenId);

    await auctionFactory.depositERC721(auctionId, slotIdx, tokenId, mockNFT.address);

    await auctionFactory.setMinimumReserveForAuctionSlots(1, [
      '10000000000000000000',
      '10000000000000000000',
      '10000000000000000000'
    ]);

    await network.provider.send('evm_mine');

    await auctionFactory.functions['bid(uint256)'](1, {
      value: '100000000000000000000'
    });

    await auctionFactory.connect(signer2).functions['bid(uint256)'](1, {
      value: '100000000000000000001'
    });

    await auctionFactory.connect(signer3).functions['bid(uint256)'](1, {
      value: '100000000000000000002'
    });

    await auctionFactory.connect(signer4).functions['bid(uint256)'](1, {
      value: '100000000000000000003'
    });

    await expect(auctionFactory.withdrawEthBidAfterAuctionFinalized(1)).revertedWith('Auction should be finalized');
  });

  it('should withdraw erc20', async () => {
    const { auctionFactory, mockNFT, mockToken } = await loadFixture(deployContract);

    await createERC20Auction(auctionFactory, mockToken.address);

    const [signer, signer2, signer3] = await ethers.getSigners();

    await mockToken.transfer(signer.address, 100);

    await mockToken.transfer(signer2.address, 110);

    await mockToken.transfer(signer3.address, 120);

    await mockToken.approve(auctionFactory.address, 100);

    await mockToken.connect(signer2).approve(auctionFactory.address, 110);

    await mockToken.connect(signer3).approve(auctionFactory.address, 120);

    const auctionId = 1;
    const slotIdx = 1;
    const tokenId = 1;

    await mockNFT.mint(signer.address, 'NFT_URI');

    await mockNFT.approve(auctionFactory.address, tokenId);

    await auctionFactory.depositERC721(auctionId, slotIdx, tokenId, mockNFT.address);

    await auctionFactory.setMinimumReserveForAuctionSlots(1, ['200', '200', '200']);

    await network.provider.send('evm_mine');

    await auctionFactory.functions['bid(uint256,uint256)'](1, 100);

    await auctionFactory.connect(signer2).functions['bid(uint256,uint256)'](1, 110);

    await auctionFactory.connect(signer3).functions['bid(uint256,uint256)'](1, 120);

    await network.provider.send('evm_mine');

    await auctionFactory.finalizeAuction(1, [signer3.address, signer2.address, signer.address]);

    await expect(auctionFactory.withdrawERC20Bid(1)).emit(auctionFactory, 'LogBidWithdrawal');

    const balance = await auctionFactory.getBidderBalance(1, signer.address);

    expect(balance.toString()).equal('0');
  });

  it('should revert with You have 0 deposited', async () => {
    const { auctionFactory, mockNFT, mockToken } = await loadFixture(deployContract);

    await createERC20Auction(auctionFactory, mockToken.address);

    const [signer, signer2, signer3, signer4] = await ethers.getSigners();

    await mockToken.transfer(signer.address, 100);

    await mockToken.transfer(signer2.address, 110);

    await mockToken.transfer(signer3.address, 120);

    await mockToken.approve(auctionFactory.address, 100);

    await mockToken.connect(signer2).approve(auctionFactory.address, 110);

    await mockToken.connect(signer3).approve(auctionFactory.address, 120);

    const auctionId = 1;
    const slotIdx = 1;
    const tokenId = 1;

    await mockNFT.mint(signer.address, 'NFT_URI');

    await mockNFT.approve(auctionFactory.address, tokenId);

    await auctionFactory.depositERC721(auctionId, slotIdx, tokenId, mockNFT.address);

    await auctionFactory.setMinimumReserveForAuctionSlots(1, ['200', '200', '200']);

    await network.provider.send('evm_mine');

    await auctionFactory.functions['bid(uint256,uint256)'](1, 100);

    await auctionFactory.connect(signer2).functions['bid(uint256,uint256)'](1, 110);

    await auctionFactory.connect(signer3).functions['bid(uint256,uint256)'](1, 120);

    await network.provider.send('evm_mine');

    await auctionFactory.finalizeAuction(1, [signer3.address, signer2.address, signer.address]);

    await expect(auctionFactory.connect(signer4).withdrawERC20Bid(1)).revertedWith(
      'You have 0 deposited'
    );
  });

  it('should revert with Auction should be finalized', async () => {
    const { auctionFactory, mockNFT, mockToken } = await loadFixture(deployContract);

    await createERC20Auction(auctionFactory, mockToken.address);

    const [signer, signer2, signer3, signer4] = await ethers.getSigners();

    await mockToken.transfer(signer.address, 100);

    await mockToken.transfer(signer2.address, 110);

    await mockToken.transfer(signer3.address, 120);

    await mockToken.approve(auctionFactory.address, 100);

    await mockToken.connect(signer2).approve(auctionFactory.address, 110);

    await mockToken.connect(signer3).approve(auctionFactory.address, 120);

    const auctionId = 1;
    const slotIdx = 1;
    const tokenId = 1;

    await mockNFT.mint(signer.address, 'NFT_URI');

    await mockNFT.approve(auctionFactory.address, tokenId);

    await auctionFactory.depositERC721(auctionId, slotIdx, tokenId, mockNFT.address);

    await auctionFactory.setMinimumReserveForAuctionSlots(1, ['200', '200', '200']);

    await network.provider.send('evm_mine');

    await auctionFactory.functions['bid(uint256,uint256)'](1, 100);

    await auctionFactory.connect(signer2).functions['bid(uint256,uint256)'](1, 110);

    await auctionFactory.connect(signer3).functions['bid(uint256,uint256)'](1, 120);

    await expect(auctionFactory.withdrawERC20Bid(1)).revertedWith('Auction should be finalized');
  });
});

const createAuction = async (auctionFactory) => {
  const blockNumber = await ethers.provider.getBlockNumber();

  const startBlockNumber = blockNumber + 6;
  const endBlockNumber = blockNumber + 9;
  const resetTimer = 2;
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

const createERC20Auction = async (auctionFactory, tokenAddress) => {
  const blockNumber = await ethers.provider.getBlockNumber();

  const startBlockNumber = blockNumber + 12;
  const endBlockNumber = blockNumber + 16;
  const resetTimer = 1;
  const numberOfSlots = 3;
  const supportsWhitelist = false;

  await auctionFactory.createAuction(
    startBlockNumber,
    endBlockNumber,
    resetTimer,
    numberOfSlots,
    supportsWhitelist,
    tokenAddress
  );
};
