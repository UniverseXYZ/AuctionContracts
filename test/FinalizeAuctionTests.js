const { expect } = require('chai');

const { waffle, ethers, network } = require('hardhat');
const { loadFixture } = waffle;

describe('Finalize auction ERC721 Tests', () => {
  const deployedContracts = async () => {
    const AuctionFactory = await ethers.getContractFactory('AuctionFactory');
    const MockNFT = await ethers.getContractFactory('MockNFT');
    const MockToken = await ethers.getContractFactory('MockToken');

    const auctionFactory = await AuctionFactory.deploy(2000, 100);
    const mockNFT = await MockNFT.deploy();
    const mockToken = await MockToken.deploy(1000);

    const [signer] = await ethers.getSigners();

    await mockToken.transfer(signer.address, 600);

    return { auctionFactory, mockNFT, mockToken };
  };

  it('should finalize successfully', async () => {
    const { auctionFactory, mockNFT } = await loadFixture(deployedContracts);

    const currentTime = Math.round((new Date()).getTime() / 1000);

    const startTime = currentTime + 2500;
    const endTime = startTime + 500;
    const resetTimer = 3;
    const numberOfSlots = 1;
    const supportsWhitelist = false;
    const ethAddress = '0x0000000000000000000000000000000000000000';
  
    await auctionFactory.createAuction(
      startTime,
      endTime,
      resetTimer,
      numberOfSlots,
      supportsWhitelist,
      ethAddress
    );

    const [signer] = await ethers.getSigners();

    await mockNFT.mint(signer.address, 1);

    await mockNFT.approve(auctionFactory.address, 1);

    await auctionFactory.depositERC721(1, 1, 1, mockNFT.address);

    await ethers.provider.send('evm_setNextBlockTimestamp', [startTime + 100]); 
    await ethers.provider.send('evm_mine');

    await expect(
      auctionFactory.functions['ethBid(uint256)'](1, {
        value: '200000000000000000000'
      })
    ).to.be.emit(auctionFactory, 'LogBidSubmitted');

    const bidderBalance = await auctionFactory.getBidderBalance(1, signer.address);

    const balance = Number(ethers.utils.formatEther(bidderBalance).toString());

    expect(balance).to.equal(200);

    await ethers.provider.send('evm_setNextBlockTimestamp', [endTime + 500]); 
    await ethers.provider.send('evm_mine');

    await auctionFactory.finalizeAuction(1);

    const auction = await auctionFactory.auctions(1);

    expect(auction.isFinalized).to.be.true;

    const slotWinner = await auctionFactory.getSlotWinner(1, 1);

    expect(slotWinner).to.equal(signer.address);

    await ethers.provider.send('evm_setNextBlockTimestamp', [endTime + 1000]); 
    await ethers.provider.send('evm_mine');

    await expect(auctionFactory.withdrawAuctionRevenue(1)).to.be.emit(auctionFactory, 'LogAuctionRevenueWithdrawal');

    await expect(auctionFactory.claimERC721Rewards(1, 1)).to.be.emit(auctionFactory, 'LogERC721RewardsClaim');
  });

  it('should revert invalid number of winners', async () => {
    const { auctionFactory, mockNFT } = await loadFixture(deployedContracts);

    const currentTime = Math.round((new Date()).getTime() / 1000);

    const startTime = currentTime + 2500;
    const endTime = startTime + 500;
    const resetTimer = 1;
    const numberOfSlots = 1;
    const supportsWhitelist = false;
    const tokenAddress = '0x0000000000000000000000000000000000000000';

    await auctionFactory.createAuction(
      startTime,
      endTime,
      resetTimer,
      numberOfSlots,
      supportsWhitelist,
      tokenAddress
    );

    const [signer, signer2] = await ethers.getSigners();

    await mockNFT.mint(signer.address, 1);

    await mockNFT.approve(auctionFactory.address, 1);
    await auctionFactory.depositERC721(1, 1, 1, mockNFT.address);

    await ethers.provider.send('evm_setNextBlockTimestamp', [startTime + 100]); 
    await ethers.provider.send('evm_mine')

    await expect(
      auctionFactory.functions['ethBid(uint256)'](1, {
        value: '200000000000000000000'
      })
    ).to.be.emit(auctionFactory, 'LogBidSubmitted');

    await ethers.provider.send('evm_setNextBlockTimestamp', [endTime + 500]); 
    await ethers.provider.send('evm_mine');

    await expect(auctionFactory.finalizeAuction(1, [signer.address, signer2.address])).to.be.reverted;
  });

  it('should revert if auction not finished', async () => {
    const { auctionFactory, mockNFT } = await loadFixture(deployedContracts);

    const currentTime = Math.round((new Date()).getTime() / 1000);

    const startTime = currentTime + 2500;
    const endTime = startTime + 500;
    const resetTimer = 3;
    const numberOfSlots = 1;
    const supportsWhitelist = false;
    const ethAddress = '0x0000000000000000000000000000000000000000';

    await auctionFactory.createAuction(
      startTime,
      endTime,
      resetTimer,
      numberOfSlots,
      supportsWhitelist,
      ethAddress
    );

    const [signer] = await ethers.getSigners();

    await mockNFT.mint(signer.address, 1);

    await mockNFT.approve(auctionFactory.address, 1);

    await auctionFactory.depositERC721(1, 1, 1, mockNFT.address);

    await ethers.provider.send('evm_setNextBlockTimestamp', [startTime + 200]); 
    await ethers.provider.send('evm_mine');

    await auctionFactory.functions['ethBid(uint256)'](1, {
      value: '200000000000000000000'
    });

    await expect(auctionFactory.finalizeAuction(1, [signer.address])).to.be.reverted;
  });

  it('should revert if first address do not have the highest bid', async () => {
    const { auctionFactory, mockNFT } = await loadFixture(deployedContracts);
    const currentTime = Math.round((new Date()).getTime() / 1000);
  
    const startTime = currentTime + 2500;
    const endTime = startTime + 500;
    const resetTimer = 3;
    const numberOfSlots = 1;
    const supportsWhitelist = false;
    const ethAddress = '0x0000000000000000000000000000000000000000';
  
    await auctionFactory.createAuction(
      startTime,
      endTime,
      resetTimer,
      numberOfSlots,
      supportsWhitelist,
      ethAddress
    );

    const [signer, signer2] = await ethers.getSigners();

    await mockNFT.mint(signer.address, 1);

    await mockNFT.approve(auctionFactory.address, 1);

    await auctionFactory.depositERC721(1, 1, 1, mockNFT.address);

    await ethers.provider.send('evm_setNextBlockTimestamp', [startTime + 200]); 
    await ethers.provider.send('evm_mine');

    await auctionFactory.functions['ethBid(uint256)'](1, {
      value: '200000000000000000000'
    });

    await ethers.provider.send('evm_setNextBlockTimestamp', [endTime + 500]); 
    await ethers.provider.send('evm_mine');

    await expect(auctionFactory.finalizeAuction(1, [signer2.address, signer.address])).to.be.reverted;
  });

  it('should revert if auction is not ended', async () => {
    const { auctionFactory } = await loadFixture(deployedContracts);

    await createAuction(auctionFactory);

    await expect(auctionFactory.withdrawAuctionRevenue(1)).to.be.reverted;
  });

  it("should transfer erc20 when it's supported by auction", async () => {
    const { auctionFactory, mockNFT, mockToken } = await loadFixture(deployedContracts);

    const currentTime = Math.round((new Date()).getTime() / 1000);

    const startTime = currentTime + 2500;
    const endTime = startTime + 500;
    const resetTimer = 1;
    const numberOfSlots = 1;
    const supportsWhitelist = false;
    const tokenAddress = mockToken.address;

    await auctionFactory.createAuction(
      startTime,
      endTime,
      resetTimer,
      numberOfSlots,
      supportsWhitelist,
      tokenAddress
    );

    const [signer] = await ethers.getSigners();

    await mockNFT.mint(signer.address, 1);

    await mockNFT.approve(auctionFactory.address, 1);

    await mockToken.approve(auctionFactory.address, 100);
    await auctionFactory.depositERC721(1, 1, 1, mockNFT.address);

    await ethers.provider.send('evm_setNextBlockTimestamp', [startTime + 100]); 
    await ethers.provider.send('evm_mine');

    await auctionFactory.functions['erc20Bid(uint256,uint256)'](1, '100');

    await ethers.provider.send('evm_setNextBlockTimestamp', [endTime + 500]); 
    await ethers.provider.send('evm_mine');

    await auctionFactory.finalizeAuction(1);

    await auctionFactory.withdrawAuctionRevenue(1);
  });

  it('should revert when is not finalized and user try to claim erc721', async () => {
    const { auctionFactory } = await loadFixture(deployedContracts);

    await createAuction(auctionFactory);

    await expect(auctionFactory.claimERC721Rewards(1, 1)).to.be.reverted;
  });

  it('should revert if some who is not the winner try to claim', async () => {
    const { auctionFactory, mockNFT } = await loadFixture(deployedContracts);

    const currentTime = Math.round((new Date()).getTime() / 1000);

    const startTime = currentTime + 2500;
    const endTime = startTime + 500;
    const resetTimer = 1;
    const numberOfSlots = 1;
    const supportsWhitelist = false;
    const tokenAddress = '0x0000000000000000000000000000000000000000';

    await auctionFactory.createAuction(
      startTime,
      endTime,
      resetTimer,
      numberOfSlots,
      supportsWhitelist,
      tokenAddress
    );

    const [signer, signer2] = await ethers.getSigners();

    await mockNFT.connect(signer).mint(signer.address, 1);

    await mockNFT.connect(signer).approve(auctionFactory.address, 1);
    await auctionFactory.depositERC721(1, 1, 1, mockNFT.address);

    await ethers.provider.send('evm_setNextBlockTimestamp', [startTime + 100]); 
    await ethers.provider.send('evm_mine');

    await auctionFactory.connect(signer).functions['ethBid(uint256)'](1, {
      value: '200000000000000000000'
    });

    await ethers.provider.send('evm_setNextBlockTimestamp', [endTime + 500]); 
    await ethers.provider.send('evm_mine');

    await auctionFactory.finalizeAuction(1);

    await expect(auctionFactory.connect(signer2).claimERC721Rewards(1, 1)).to.be.reverted;
  });

  it('should set isValid to false if addr1 bid is lower than addr2 bid', async () => {
    const { auctionFactory, mockNFT } = await loadFixture(deployedContracts);

    const currentTime = Math.round((new Date()).getTime() / 1000);

    const startTime = currentTime + 2500;
    const endTime = startTime + 500;
    const resetTimer = 1;
    const numberOfSlots = 4;
    const supportsWhitelist = false;
    const tokenAddress = '0x0000000000000000000000000000000000000000';

    await auctionFactory.createAuction(
      startTime,
      endTime,
      resetTimer,
      numberOfSlots,
      supportsWhitelist,
      tokenAddress
    );

    const [signer, signer2, signer3, signer4] = await ethers.getSigners();

    await mockNFT.connect(signer).mint(signer.address, 1);

    await mockNFT.connect(signer).approve(auctionFactory.address, 1);
    await auctionFactory.connect(signer).depositERC721(1, 1, 1, mockNFT.address);

    await ethers.provider.send('evm_setNextBlockTimestamp', [startTime + 100]); 
    await ethers.provider.send('evm_mine');

    await auctionFactory.connect(signer).functions['ethBid(uint256)'](1, {
      value: '200000000000000000000'
    });

    await auctionFactory.connect(signer2).functions['ethBid(uint256)'](1, {
      value: '300000000000000000000'
    });

    await auctionFactory.connect(signer3).functions['ethBid(uint256)'](1, {
      value: '400000000000000000000'
    });

    await auctionFactory.connect(signer4).functions['ethBid(uint256)'](1, {
      value: '500000000000000000000'
    });

    await ethers.provider.send('evm_setNextBlockTimestamp', [endTime + 500]); 
    await ethers.provider.send('evm_mine');

    await auctionFactory.finalizeAuction(1);
  });

  it('should have 0 id for nft', async () => {
    const { auctionFactory, mockNFT } = await loadFixture(deployedContracts);

    const currentTime = Math.round((new Date()).getTime() / 1000);

    const startTime = currentTime + 2500;
    const endTime = startTime + 500;
    const resetTimer = 1;
    const numberOfSlots = 1;
    const supportsWhitelist = false;
    const tokenAddress = '0x0000000000000000000000000000000000000000';

    await auctionFactory.createAuction(
      startTime,
      endTime,
      resetTimer,
      numberOfSlots,
      supportsWhitelist,
      tokenAddress
    );

    const [signer] = await ethers.getSigners();

    await mockNFT.connect(signer).mint(signer.address, 1);
    await mockNFT.connect(signer).mint(signer.address, 2);

    await mockNFT.connect(signer).approve(auctionFactory.address, 1);
    await mockNFT.connect(signer).approve(auctionFactory.address, 2);

    await auctionFactory.depositERC721(1, 1, 1, mockNFT.address);
    await auctionFactory.depositERC721(1, 1, 2, mockNFT.address);

    await ethers.provider.send('evm_setNextBlockTimestamp', [startTime + 100]); 
    await ethers.provider.send('evm_mine');

    await auctionFactory.connect(signer).functions['ethBid(uint256)'](1, {
      value: '500000000000000000000'
    });

    await ethers.provider.send('evm_setNextBlockTimestamp', [endTime + 200]); 
    await ethers.provider.send('evm_mine');

    await auctionFactory.finalizeAuction(1);

    await auctionFactory.connect(signer).claimERC721Rewards(1, 1);
  });

  it('should revert if last address do not have lowest bid', async () => {
    const { auctionFactory, mockNFT } = await loadFixture(deployedContracts);

    const currentTime = Math.round((new Date()).getTime() / 1000);

    const startTime = currentTime + 2500;
    const endTime = startTime + 500;
    const resetTimer = 6;
    const numberOfSlots = 2;
    const supportsWhitelist = false;
    const ethAddress = '0x0000000000000000000000000000000000000000';

    await auctionFactory.createAuction(
      startTime,
      endTime,
      resetTimer,
      numberOfSlots,
      supportsWhitelist,
      ethAddress
    );

    const [signer, signer2] = await ethers.getSigners();

    await mockNFT.connect(signer).mint(signer.address, 'TOKEN_URI');

    await mockNFT.connect(signer).approve(auctionFactory.address, 1);

    await auctionFactory.depositERC721(1, 1, 1, mockNFT.address);

    await ethers.provider.send('evm_setNextBlockTimestamp', [startTime + 100]); 
    await ethers.provider.send('evm_mine');

    await auctionFactory.connect(signer).functions['ethBid(uint256)'](1, {
      value: '100000000000000000000'
    });

    await auctionFactory.connect(signer2).functions['ethBid(uint256)'](1, {
      value: '200000000000000000000'
    });

    await auctionFactory.connect(signer2).functions['ethBid(uint256)'](1, {
      value: '300000000000000000000'
    });

    await ethers.provider.send('evm_setNextBlockTimestamp', [endTime + 500]); 
    await ethers.provider.send('evm_mine');

    await expect(auctionFactory.finalizeAuction(1)).to.be.not.reverted;
  });
});

const createAuction = async (auctionFactory) => {
  const currentTime = Math.round((new Date()).getTime() / 1000);

  const startTime = currentTime + 2500;
  const endTime = startTime + 500;
  const resetTimer = 3;
  const numberOfSlots = 1;
  const supportsWhitelist = false;
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
