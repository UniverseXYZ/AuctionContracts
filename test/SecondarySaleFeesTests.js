const { expect } = require('chai');

const { waffle, ethers, network } = require('hardhat');
const { loadFixture } = waffle;

describe('Secondary Sale Fees Tests', () => {
  const deployedContracts = async () => {
    const [owner, addr1] = await ethers.getSigners();
    const AuctionFactory = await ethers.getContractFactory('AuctionFactory');
    const UniverseERC721 = await ethers.getContractFactory('UniverseERC721');

    const auctionFactory = await AuctionFactory.deploy(10, 100, 0, owner.address, []);
    const universeERC721 = await UniverseERC721.deploy("Non Fungible Universe", "NFU");

    return { auctionFactory, universeERC721 };
  };

  it('should finalize and distribute fees successfully', async () => {
    const { auctionFactory, universeERC721 } = await loadFixture(deployedContracts);

    const currentTime = Math.round((new Date()).getTime() / 1000);

    const startTime = currentTime + 8500;
    const endTime = startTime + 500;
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

    let randomWallet1 = ethers.Wallet.createRandom();
    let randomWallet2= ethers.Wallet.createRandom();

    const [signer] = await ethers.getSigners();

    await universeERC721.mint(signer.address, "TokenURI", [[randomWallet1.address, 1000], [randomWallet2.address, 500]]);

    await universeERC721.approve(auctionFactory.address, 1);

    await auctionFactory.depositERC721(1, 1, [[1, universeERC721.address]]);

    await ethers.provider.send('evm_setNextBlockTimestamp', [startTime + 100]); 
    await ethers.provider.send('evm_mine');

    await expect(
      auctionFactory.functions['ethBid(uint256)'](1, {
        value: '2000000000000000000'
      })
    ).to.be.emit(auctionFactory, 'LogBidSubmitted');

    const bidderBalance = await auctionFactory.getBidderBalance(1, signer.address);

    const balance = Number(ethers.utils.formatEther(bidderBalance).toString());

    expect(balance).to.equal(2);

    await ethers.provider.send('evm_setNextBlockTimestamp', [endTime + 500]); 
    await ethers.provider.send('evm_mine');

    await auctionFactory.finalizeAuction(1);
    await auctionFactory.captureAuctionRevenue(1);

    const auction = await auctionFactory.auctions(1);

    expect(auction.isFinalized).to.be.true;

    const slotWinner = await auctionFactory.getSlotWinner(1, 1);

    expect(slotWinner).to.equal(signer.address);

    await auctionFactory.distributeSecondarySaleFees(1, 1, 1);

    const balance1 = await ethers.provider.getBalance(randomWallet1.address);
    const balance2 = await ethers.provider.getBalance(randomWallet2.address);
    
    expect(Number(ethers.utils.formatEther(balance1).toString())).to.equal(0.2);
    expect(Number(ethers.utils.formatEther(balance2).toString())).to.equal(0.1);

    await expect(auctionFactory.distributeAuctionRevenue(1)).to.be.emit(auctionFactory, 'LogAuctionRevenueWithdrawal');

    await expect(auctionFactory.claimERC721Rewards(1, 1, 1)).to.be.emit(auctionFactory, 'LogERC721RewardsClaim');
  });

  it('should distribute fees correctly', async () => {
    const { auctionFactory, universeERC721 } = await loadFixture(deployedContracts);

    const currentTime = Math.round((new Date()).getTime() / 1000);

    const startTime = currentTime + 8500;
    const endTime = startTime + 500;
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

    let randomWallet1 = ethers.Wallet.createRandom();
    let randomWallet2= ethers.Wallet.createRandom();

    const [signer] = await ethers.getSigners();

    await universeERC721.mint(signer.address, "TokenURI", [[randomWallet1.address, 1000], [randomWallet2.address, 9500]]);

    await universeERC721.approve(auctionFactory.address, 1);

    await auctionFactory.depositERC721(1, 1, [[1, universeERC721.address]]);

    await ethers.provider.send('evm_setNextBlockTimestamp', [startTime + 100]); 
    await ethers.provider.send('evm_mine');

    await expect(
      auctionFactory.functions['ethBid(uint256)'](1, {
        value: '9000000000000000000'
      })
    ).to.be.emit(auctionFactory, 'LogBidSubmitted');

    const bidderBalance = await auctionFactory.getBidderBalance(1, signer.address);

    const balance = Number(ethers.utils.formatEther(bidderBalance).toString());

    expect(balance).to.equal(9);

    await ethers.provider.send('evm_setNextBlockTimestamp', [endTime + 500]); 
    await ethers.provider.send('evm_mine');

    await auctionFactory.finalizeAuction(1);
    await auctionFactory.captureAuctionRevenue(1);

    const auction = await auctionFactory.auctions(1);

    expect(auction.isFinalized).to.be.true;

    const slotWinner = await auctionFactory.getSlotWinner(1, 1);

    expect(slotWinner).to.equal(signer.address);

    await auctionFactory.distributeSecondarySaleFees(1, 1, 1);

    const balance1 = await ethers.provider.getBalance(randomWallet1.address);
    const balance2 = await ethers.provider.getBalance(randomWallet2.address);
    
    expect(Number(ethers.utils.formatEther(balance1).toString())).to.equal(0.9);
    expect(Number(ethers.utils.formatEther(balance2).toString())).to.equal(8.1);

    await expect(auctionFactory.distributeAuctionRevenue(1)).to.be.emit(auctionFactory, 'LogAuctionRevenueWithdrawal');

    await expect(auctionFactory.claimERC721Rewards(1, 1, 1)).to.be.emit(auctionFactory, 'LogERC721RewardsClaim');
  });

});

