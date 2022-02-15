const { expect } = require('chai');

const { waffle, ethers, network, upgrades } = require('hardhat');
const { loadFixture } = waffle;

describe('Secondary Sale Fees Tests', () => {
  const deployedContracts = async () => {
    const [owner, addr1] = await ethers.getSigners();
    const UniverseAuctionHouse = await ethers.getContractFactory('UniverseAuctionHouse');
    const UniverseERC721 = await ethers.getContractFactory('UniverseERC721');

    const MockRoyaltiesRegistry =  await ethers.getContractFactory('MockRoyaltiesRegistry');
    const mockRoyaltiesRegistry = await upgrades.deployProxy(MockRoyaltiesRegistry, [], {initializer: "__RoyaltiesRegistry_init"});

    const universeAuctionHouse = await upgrades.deployProxy(UniverseAuctionHouse,
      [
        10, 100, 0, owner.address, [], mockRoyaltiesRegistry.address
      ],
      {
        initializer: "__UniverseAuctionHouse_init",
    });
    const universeERC721 = await UniverseERC721.deploy("Non Fungible Universe", "NFU");

    return { universeAuctionHouse, universeERC721, mockRoyaltiesRegistry };
  };

  it('should finalize and distribute fees successfully', async () => {
    const { universeAuctionHouse, universeERC721 } = await loadFixture(deployedContracts);

    const currentTime = Math.round((new Date()).getTime() / 1000);

    const startTime = currentTime + 8500;
    const endTime = startTime + 500;
    const resetTimer = 3;
    const numberOfSlots = 1;
    const ethAddress = '0x0000000000000000000000000000000000000000';
    const minimumReserveValues = [];
    const paymentSplits = [];

    await universeAuctionHouse.createAuction([
      startTime,
      endTime,
      resetTimer,
      numberOfSlots,
      ethAddress,
      minimumReserveValues,
      paymentSplits
    ]);

    let randomWallet1 = ethers.Wallet.createRandom();
    let randomWallet2= ethers.Wallet.createRandom();

    const [signer] = await ethers.getSigners();

    await universeERC721.mint(signer.address, "TokenURI", [[randomWallet1.address, 1000], [randomWallet2.address, 500]]);

    await universeERC721.approve(universeAuctionHouse.address, 1);

    await universeAuctionHouse.depositERC721(1, 1, [[1, universeERC721.address]]);

    await ethers.provider.send('evm_setNextBlockTimestamp', [startTime + 100]); 
    await ethers.provider.send('evm_mine');

    await expect(
      universeAuctionHouse.functions['ethBid(uint256)'](1, {
        value: '2000000000000000000'
      })
    ).to.be.emit(universeAuctionHouse, 'LogBidSubmitted');

    const bidderBalance = await universeAuctionHouse.getBidderBalance(1, signer.address);

    const balance = Number(ethers.utils.formatEther(bidderBalance).toString());

    expect(balance).to.equal(2);

    await ethers.provider.send('evm_setNextBlockTimestamp', [endTime + 500]); 
    await ethers.provider.send('evm_mine');

    await universeAuctionHouse.finalizeAuction(1);

    for (let i = 0; i < numberOfSlots; i++) {
      await universeAuctionHouse.captureSlotRevenue(1, (i + 1));
    }

    const auction = await universeAuctionHouse.auctions(1);

    expect(auction.isFinalized).to.be.true;

    const slotWinner = await universeAuctionHouse.getSlotWinner(1, 1);

    expect(slotWinner).to.equal(signer.address);

    await universeAuctionHouse.distributeSecondarySaleFees(1, 1, 1);

    const balance1 = await ethers.provider.getBalance(randomWallet1.address);
    const balance2 = await ethers.provider.getBalance(randomWallet2.address);
    
    expect(Number(ethers.utils.formatEther(balance1).toString())).to.equal(0.2);
    expect(Number(ethers.utils.formatEther(balance2).toString())).to.equal(0.1);

    await expect(universeAuctionHouse.distributeCapturedAuctionRevenue(1)).to.be.emit(universeAuctionHouse, 'LogAuctionRevenueWithdrawal');

    await expect(universeAuctionHouse.claimERC721Rewards(1, 1, 1)).to.be.emit(universeAuctionHouse, 'LogERC721RewardsClaim');
  });

  it('should distribute fees correctly', async () => {
    const { universeAuctionHouse, universeERC721 } = await loadFixture(deployedContracts);

    const currentTime = Math.round((new Date()).getTime() / 1000);

    const startTime = currentTime + 8500;
    const endTime = startTime + 500;
    const resetTimer = 3;
    const numberOfSlots = 1;
    const ethAddress = '0x0000000000000000000000000000000000000000';
    const minimumReserveValues = [];
    const paymentSplits = [];
  
    await universeAuctionHouse.createAuction([
      startTime,
      endTime,
      resetTimer,
      numberOfSlots,
      ethAddress,
      minimumReserveValues,
      paymentSplits
    ]);

    let randomWallet1 = ethers.Wallet.createRandom();
    let randomWallet2= ethers.Wallet.createRandom();

    const [signer] = await ethers.getSigners();

    await universeERC721.mint(signer.address, "TokenURI", [[randomWallet1.address, 1000], [randomWallet2.address, 999]]);

    await universeERC721.approve(universeAuctionHouse.address, 1);

    await universeAuctionHouse.depositERC721(1, 1, [[1, universeERC721.address]]);

    await ethers.provider.send('evm_setNextBlockTimestamp', [startTime + 100]); 
    await ethers.provider.send('evm_mine');

    await expect(
      universeAuctionHouse.functions['ethBid(uint256)'](1, {
        value: '9000000000000000000'
      })
    ).to.be.emit(universeAuctionHouse, 'LogBidSubmitted');

    const bidderBalance = await universeAuctionHouse.getBidderBalance(1, signer.address);

    const balance = Number(ethers.utils.formatEther(bidderBalance).toString());

    expect(balance).to.equal(9);

    await ethers.provider.send('evm_setNextBlockTimestamp', [endTime + 500]); 
    await ethers.provider.send('evm_mine');

    await universeAuctionHouse.finalizeAuction(1);

    for (let i = 0; i < numberOfSlots; i++) {
      await universeAuctionHouse.captureSlotRevenue(1, (i + 1));
    }

    const auction = await universeAuctionHouse.auctions(1);

    expect(auction.isFinalized).to.be.true;

    const slotWinner = await universeAuctionHouse.getSlotWinner(1, 1);

    expect(slotWinner).to.equal(signer.address);

    await universeAuctionHouse.distributeSecondarySaleFees(1, 1, 1);

    const balance1 = await ethers.provider.getBalance(randomWallet1.address);
    const balance2 = await ethers.provider.getBalance(randomWallet2.address);
    
    expect(Number(ethers.utils.formatEther(balance1).toString())).to.equal(0.9);
    expect(Number(ethers.utils.formatEther(balance2).toString())).to.equal(0.8991);

    await expect(universeAuctionHouse.distributeCapturedAuctionRevenue(1)).to.be.emit(universeAuctionHouse, 'LogAuctionRevenueWithdrawal');

    await expect(universeAuctionHouse.claimERC721Rewards(1, 1, 1)).to.be.emit(universeAuctionHouse, 'LogERC721RewardsClaim');
  });

  it('should distribute NFT & Collection Royalties set trough the RoyaltyRegistry', async () => {
    const { universeAuctionHouse, universeERC721, mockRoyaltiesRegistry } = await loadFixture(deployedContracts);

    const currentTime = Math.round((new Date()).getTime() / 1000);

    const startTime = currentTime + 8500;
    const endTime = startTime + 500;
    const resetTimer = 3;
    const numberOfSlots = 1;
    const ethAddress = '0x0000000000000000000000000000000000000000';
    const minimumReserveValues = [];
    const paymentSplits = [];

    await universeAuctionHouse.createAuction([
      startTime,
      endTime,
      resetTimer,
      numberOfSlots,
      ethAddress,
      minimumReserveValues,
      paymentSplits
    ]);

    let randomWallet1 = ethers.Wallet.createRandom();
    let randomWallet2= ethers.Wallet.createRandom();

    const [signer] = await ethers.getSigners();

    await universeERC721.mint(signer.address, "TokenURI", []);

    // Assign 10% Collection Royalties
    await mockRoyaltiesRegistry.setRoyaltiesByToken(universeERC721.address, [
      [randomWallet1.address, 1000],
    ]);

    // Add 10% Royalties to a specific NFT
    await mockRoyaltiesRegistry.setRoyaltiesByTokenAndTokenId(universeERC721.address, 1, [
      [randomWallet2.address, 1000],
    ]);

    await universeERC721.approve(universeAuctionHouse.address, 1);

    await universeAuctionHouse.depositERC721(1, 1, [[1, universeERC721.address]]);

    await ethers.provider.send('evm_setNextBlockTimestamp', [startTime + 100]); 
    await ethers.provider.send('evm_mine');

    await expect(
      universeAuctionHouse.functions['ethBid(uint256)'](1, {
        value: '9000000000000000000'
      })
    ).to.be.emit(universeAuctionHouse, 'LogBidSubmitted');

    const bidderBalance = await universeAuctionHouse.getBidderBalance(1, signer.address);

    const balance = Number(ethers.utils.formatEther(bidderBalance).toString());

    expect(balance).to.equal(9);

    await ethers.provider.send('evm_setNextBlockTimestamp', [endTime + 500]); 
    await ethers.provider.send('evm_mine');

    await universeAuctionHouse.finalizeAuction(1);

    for (let i = 0; i < numberOfSlots; i++) {
      await universeAuctionHouse.captureSlotRevenue(1, (i + 1));
    }

    const auction = await universeAuctionHouse.auctions(1);

    expect(auction.isFinalized).to.be.true;

    const slotWinner = await universeAuctionHouse.getSlotWinner(1, 1);

    expect(slotWinner).to.equal(signer.address);

    await universeAuctionHouse.distributeSecondarySaleFees(1, 1, 1);

    const balance1 = await ethers.provider.getBalance(randomWallet1.address);
    const balance2 = await ethers.provider.getBalance(randomWallet2.address);

    expect(Number(ethers.utils.formatEther(balance1).toString())).to.equal(0.9);
    expect(Number(ethers.utils.formatEther(balance2).toString())).to.equal(0.81);

    await expect(universeAuctionHouse.distributeCapturedAuctionRevenue(1)).to.be.emit(universeAuctionHouse, 'LogAuctionRevenueWithdrawal');

    await expect(universeAuctionHouse.claimERC721Rewards(1, 1, 1)).to.be.emit(universeAuctionHouse, 'LogERC721RewardsClaim');
  });

  it('should distribute Multiple NFT & Collection Royalties set trough the RoyaltyRegistry', async () => {
    const { universeAuctionHouse, universeERC721, mockRoyaltiesRegistry } = await loadFixture(deployedContracts);

    const currentTime = Math.round((new Date()).getTime() / 1000);

    const startTime = currentTime + 8500;
    const endTime = startTime + 500;
    const resetTimer = 3;
    const numberOfSlots = 1;
    const ethAddress = '0x0000000000000000000000000000000000000000';
    const minimumReserveValues = [];
    const paymentSplits = [];

    await universeAuctionHouse.createAuction([
      startTime,
      endTime,
      resetTimer,
      numberOfSlots,
      ethAddress,
      minimumReserveValues,
      paymentSplits
    ]);

    let randomWallet1 = ethers.Wallet.createRandom();
    let randomWallet2 = ethers.Wallet.createRandom();
    let randomWallet3 = ethers.Wallet.createRandom();
    let randomWallet4 = ethers.Wallet.createRandom();

    const [signer] = await ethers.getSigners();

    await universeERC721.mint(signer.address, "TokenURI", []);

    // Assign 10% Collection Royalties
    await mockRoyaltiesRegistry.setRoyaltiesByToken(universeERC721.address, [
      [randomWallet1.address, 1000],
      [randomWallet3.address, 1000],
    ]);

    // Add 10% Royalties to a specific NFT
    await mockRoyaltiesRegistry.setRoyaltiesByTokenAndTokenId(universeERC721.address, 1, [
      [randomWallet2.address, 1000],
      [randomWallet4.address, 1000],
    ]);

    await universeERC721.approve(universeAuctionHouse.address, 1);

    await universeAuctionHouse.depositERC721(1, 1, [[1, universeERC721.address]]);

    await ethers.provider.send('evm_setNextBlockTimestamp', [startTime + 100]); 
    await ethers.provider.send('evm_mine');

    await expect(
      universeAuctionHouse.functions['ethBid(uint256)'](1, {
        value: '10000000000000000000'
      })
    ).to.be.emit(universeAuctionHouse, 'LogBidSubmitted');

    const bidderBalance = await universeAuctionHouse.getBidderBalance(1, signer.address);

    const balance = Number(ethers.utils.formatEther(bidderBalance).toString());

    expect(balance).to.equal(10);

    await ethers.provider.send('evm_setNextBlockTimestamp', [endTime + 500]); 
    await ethers.provider.send('evm_mine');

    await universeAuctionHouse.finalizeAuction(1);

    for (let i = 0; i < numberOfSlots; i++) {
      await universeAuctionHouse.captureSlotRevenue(1, (i + 1));
    }

    const auction = await universeAuctionHouse.auctions(1);

    expect(auction.isFinalized).to.be.true;

    const slotWinner = await universeAuctionHouse.getSlotWinner(1, 1);

    expect(slotWinner).to.equal(signer.address);

    await universeAuctionHouse.distributeSecondarySaleFees(1, 1, 1);

    const balance1 = await ethers.provider.getBalance(randomWallet1.address);
    const balance2 = await ethers.provider.getBalance(randomWallet2.address);
    const balance3 = await ethers.provider.getBalance(randomWallet3.address);
    const balance4 = await ethers.provider.getBalance(randomWallet4.address);

    expect(Number(ethers.utils.formatEther(balance1).toString())).to.equal(1);
    expect(Number(ethers.utils.formatEther(balance3).toString())).to.equal(1);
    expect(Number(ethers.utils.formatEther(balance2).toString())).to.equal(0.8);
    expect(Number(ethers.utils.formatEther(balance4).toString())).to.equal(0.8);

    await expect(universeAuctionHouse.distributeCapturedAuctionRevenue(1)).to.be.emit(universeAuctionHouse, 'LogAuctionRevenueWithdrawal');

    await expect(universeAuctionHouse.claimERC721Rewards(1, 1, 1)).to.be.emit(universeAuctionHouse, 'LogERC721RewardsClaim');
  });

  it('should distribute Multiple NFT & Collection & Auction & DAO Royalties', async () => {
    const { universeAuctionHouse, universeERC721, mockRoyaltiesRegistry } = await loadFixture(deployedContracts);

    const currentTime = Math.round((new Date()).getTime() / 1000);

    const startTime = currentTime + 8500;
    const endTime = startTime + 500;
    const resetTimer = 3;
    const numberOfSlots = 1;
    const ethAddress = '0x0000000000000000000000000000000000000000';
    const minimumReserveValues = [];

    let randomWallet1 = ethers.Wallet.createRandom();
    let randomWallet2 = ethers.Wallet.createRandom();
    let randomWallet3 = ethers.Wallet.createRandom();
    let randomWallet4 = ethers.Wallet.createRandom();
    let randomWallet5 = ethers.Wallet.createRandom();
    let randomWallet6 = ethers.Wallet.createRandom();

    const paymentSplits = [[randomWallet5.address, 1000]];

    await universeAuctionHouse.createAuction([
      startTime,
      endTime,
      resetTimer,
      numberOfSlots,
      ethAddress,
      minimumReserveValues,
      paymentSplits
    ]);

    const [signer] = await ethers.getSigners();

    await universeERC721.mint(signer.address, "TokenURI", []);

    // Assign 10% Collection Royalties
    await mockRoyaltiesRegistry.setRoyaltiesByToken(universeERC721.address, [
      [randomWallet1.address, 1000],
      [randomWallet3.address, 1000],
    ]);

    // Add 10% Royalties to a specific NFT
    await mockRoyaltiesRegistry.setRoyaltiesByTokenAndTokenId(universeERC721.address, 1, [
      [randomWallet2.address, 1000],
      [randomWallet4.address, 1000],
      [randomWallet6.address, 1000],
    ]);

    // Add 10% Royalties to the DAO
    await universeAuctionHouse.setRoyaltyFeeBps('1000');

    await universeERC721.approve(universeAuctionHouse.address, 1);

    await universeAuctionHouse.depositERC721(1, 1, [[1, universeERC721.address]]);

    await ethers.provider.send('evm_setNextBlockTimestamp', [startTime + 100]);
    await ethers.provider.send('evm_mine');

    await expect(
      universeAuctionHouse.functions['ethBid(uint256)'](1, {
        value: '10000000000000000000'
      })
    ).to.be.emit(universeAuctionHouse, 'LogBidSubmitted');

    const bidderBalance = await universeAuctionHouse.getBidderBalance(1, signer.address);

    const balance = Number(ethers.utils.formatEther(bidderBalance).toString());

    expect(balance).to.equal(10);

    await ethers.provider.send('evm_setNextBlockTimestamp', [endTime + 500]);
    await ethers.provider.send('evm_mine');

    await universeAuctionHouse.finalizeAuction(1);

    for (let i = 0; i < numberOfSlots; i++) {
      await universeAuctionHouse.captureSlotRevenue(1, (i + 1));
    }

    const auction = await universeAuctionHouse.auctions(1);

    expect(auction.isFinalized).to.be.true;

    const slotWinner = await universeAuctionHouse.getSlotWinner(1, 1);

    expect(slotWinner).to.equal(signer.address);

    await universeAuctionHouse.distributeSecondarySaleFees(1, 1, 1);

    const balance1 = await ethers.provider.getBalance(randomWallet1.address);
    const balance2 = await ethers.provider.getBalance(randomWallet2.address);
    const balance3 = await ethers.provider.getBalance(randomWallet3.address);
    const balance4 = await ethers.provider.getBalance(randomWallet4.address);
    const balance6 = await ethers.provider.getBalance(randomWallet4.address);

    // Address 1 & 3 should receive 10% on Collection Royalty Level 10% from 10 ETH = 1 ETH
    expect(Number(ethers.utils.formatEther(balance1).toString())).to.equal(1);
    expect(Number(ethers.utils.formatEther(balance3).toString())).to.equal(1);

    // Address 2 & 4 & 6 should receive 10% on NFT Royalty Level 10 % from 8 ETH = 0.8 ETH
    expect(Number(ethers.utils.formatEther(balance2).toString())).to.equal(0.8);
    expect(Number(ethers.utils.formatEther(balance4).toString())).to.equal(0.8);
    expect(Number(ethers.utils.formatEther(balance6).toString())).to.equal(0.8);

    await expect(universeAuctionHouse.distributeCapturedAuctionRevenue(1)).to.be.emit(universeAuctionHouse, 'LogAuctionRevenueWithdrawal');

    // DAO should receive 10% from 5.6 = 0.56
    expect(await universeAuctionHouse.royaltiesReserve(ethAddress)).to.equal("560000000000000000");

    // Address 5 should receive 10% on Auction Royalty Level 10 % from 5.04 ETH = 0.504 ETH
    const balance5 = await ethers.provider.getBalance(randomWallet5.address);
    expect(Number(ethers.utils.formatEther(balance5).toString())).to.equal(0.504);

    // Distribute the Royalties
    await expect(universeAuctionHouse.distributeRoyalties(ethAddress)).emit(
      universeAuctionHouse,
      'LogRoyaltiesWithdrawal'
    );

    expect(await universeAuctionHouse.royaltiesReserve(ethAddress)).to.equal('0');

    await expect(universeAuctionHouse.claimERC721Rewards(1, 1, 1)).to.be.emit(universeAuctionHouse, 'LogERC721RewardsClaim');
  });


  it('should distribute Multiple NFT & Collection & Auction & DAO Royalties with Max Load', async () => {
    const { universeAuctionHouse, universeERC721, mockRoyaltiesRegistry } = await loadFixture(deployedContracts);

    const currentTime = Math.round((new Date()).getTime() / 1000);

    const startTime = currentTime + 8500;
    const endTime = startTime + 500;
    const resetTimer = 3;
    const numberOfSlots = 1;
    const ethAddress = '0x0000000000000000000000000000000000000000';
    const minimumReserveValues = [];

    let randomWallet1 = ethers.Wallet.createRandom();
    let randomWallet2 = ethers.Wallet.createRandom();
    let randomWallet3 = ethers.Wallet.createRandom();
    let randomWallet4 = ethers.Wallet.createRandom();
    let randomWallet5 = ethers.Wallet.createRandom();
    let randomWallet6 = ethers.Wallet.createRandom();
    let randomWallet7 = ethers.Wallet.createRandom();
    let randomWallet8 = ethers.Wallet.createRandom();
    let randomWallet9 = ethers.Wallet.createRandom();
    let randomWallet10 = ethers.Wallet.createRandom();
    let randomWallet11 = ethers.Wallet.createRandom();

    const paymentSplits = [[randomWallet11.address, 1000]];

    await universeAuctionHouse.createAuction([
      startTime,
      endTime,
      resetTimer,
      numberOfSlots,
      ethAddress,
      minimumReserveValues,
      paymentSplits
    ]);

    const [signer] = await ethers.getSigners();

    for(let i = 1; i <= 100; i++) {
      await universeERC721.mint(signer.address, "TokenURI", []);

      // Add 10% Royalties to all NFT
      await mockRoyaltiesRegistry.setRoyaltiesByTokenAndTokenId(universeERC721.address, i, [
        [randomWallet1.address, 1000],
        [randomWallet2.address, 1000],
        [randomWallet3.address, 1000],
        [randomWallet4.address, 1000],
        [randomWallet5.address, 1000],
      ]);
    }

    // Assign 10% Collection Royalties
    await mockRoyaltiesRegistry.setRoyaltiesByToken(universeERC721.address, [
      [randomWallet6.address, 1000],
      [randomWallet7.address, 1000],
      [randomWallet8.address, 1000],
      [randomWallet9.address, 1000],
      [randomWallet10.address, 1000],
    ]);

    // Add 10% Royalties to the DAO
    await universeAuctionHouse.setRoyaltyFeeBps('1000');

    for (let i = 1; i <= 100; i++) {
      await universeERC721.approve(universeAuctionHouse.address, i);
    }

    // Deposit 100 NFTs into the Auction
    const tokensDepositBatch = []; // 40 tokens
    const tokensDepositBatch2 = []; // 40 tokens
    const tokensDepositBatch3 = []; // 20 toknes


    for (let i = 1; i <= 40; i++) {
      tokensDepositBatch.push([i, universeERC721.address])
    }

    for (let i = 41; i <= 80; i++) {
      tokensDepositBatch2.push([i, universeERC721.address])
    }

    for (let i = 81; i <= 100; i++) {
      tokensDepositBatch3.push([i, universeERC721.address])
    }


    await universeAuctionHouse.depositERC721(1, 1, tokensDepositBatch);
    await universeAuctionHouse.depositERC721(1, 1, tokensDepositBatch2);
    await universeAuctionHouse.depositERC721(1, 1, tokensDepositBatch3);

    await ethers.provider.send('evm_setNextBlockTimestamp', [startTime + 100]);
    await ethers.provider.send('evm_mine');

    await expect(
      universeAuctionHouse.functions['ethBid(uint256)'](1, {
        value: '10000000000000000000'
      })
    ).to.be.emit(universeAuctionHouse, 'LogBidSubmitted');

    const bidderBalance = await universeAuctionHouse.getBidderBalance(1, signer.address);

    const balance = Number(ethers.utils.formatEther(bidderBalance).toString());

    expect(balance).to.equal(10);

    await ethers.provider.send('evm_setNextBlockTimestamp', [endTime + 500]);
    await ethers.provider.send('evm_mine');

    await universeAuctionHouse.finalizeAuction(1);

    for (let i = 0; i < numberOfSlots; i++) {
      await universeAuctionHouse.captureSlotRevenue(1, (i + 1));
    }

    const auction = await universeAuctionHouse.auctions(1);

    expect(auction.isFinalized).to.be.true;

    const slotWinner = await universeAuctionHouse.getSlotWinner(1, 1);

    expect(slotWinner).to.equal(signer.address);

    for (let i = 1; i <= 100; i++) {
      await universeAuctionHouse.distributeSecondarySaleFees(1, 1, i);
  }

    const balance1 = await ethers.provider.getBalance(randomWallet1.address);
    const balance2 = await ethers.provider.getBalance(randomWallet2.address);
    const balance3 = await ethers.provider.getBalance(randomWallet3.address);
    const balance4 = await ethers.provider.getBalance(randomWallet4.address);
    const balance5 = await ethers.provider.getBalance(randomWallet5.address);
    const balance6 = await ethers.provider.getBalance(randomWallet6.address);
    const balance7 = await ethers.provider.getBalance(randomWallet7.address);
    const balance8 = await ethers.provider.getBalance(randomWallet8.address);
    const balance9 = await ethers.provider.getBalance(randomWallet9.address);
    const balance10 = await ethers.provider.getBalance(randomWallet10.address);

    // Address 6 - 10 should receive 10% on Collection Royalty Level 10% from 10 ETH = 1 ETH
    // 1 slot has 100 nfts => NFT price = 10 (eth bid) / 100 = 0.1 => One address should receive 10 % from 0.1 = 0.01 => Total = 100 (NFTs) * 0.01 = 1;
    expect(Number(ethers.utils.formatEther(balance6).toString())).to.equal(1);
    expect(Number(ethers.utils.formatEther(balance7).toString())).to.equal(1);
    expect(Number(ethers.utils.formatEther(balance8).toString())).to.equal(1);
    expect(Number(ethers.utils.formatEther(balance9).toString())).to.equal(1);
    expect(Number(ethers.utils.formatEther(balance10).toString())).to.equal(1);

    // Address 1 - 5 should receive 10% on NFT Royalty Level
    expect(Number(ethers.utils.formatEther(balance1).toString())).to.equal(0.5);
    expect(Number(ethers.utils.formatEther(balance2).toString())).to.equal(0.5);
    expect(Number(ethers.utils.formatEther(balance3).toString())).to.equal(0.5);
    expect(Number(ethers.utils.formatEther(balance4).toString())).to.equal(0.5);
    expect(Number(ethers.utils.formatEther(balance5).toString())).to.equal(0.5);

    await expect(universeAuctionHouse.distributeCapturedAuctionRevenue(1)).to.be.emit(universeAuctionHouse, 'LogAuctionRevenueWithdrawal');

    // DAO should receive 10% on Auction Royalty Level 10 % from 2.5 ETH = 0.25 ETH
    expect(await universeAuctionHouse.royaltiesReserve(ethAddress)).to.equal("250000000000000000");

    // Address 5 should receive 10% from 2.25 = 0.225
    const balance11 = await ethers.provider.getBalance(randomWallet11.address);
    expect(Number(ethers.utils.formatEther(balance11).toString())).to.equal(0.225);

    // Distribute the Royalties
    await expect(universeAuctionHouse.distributeRoyalties(ethAddress)).emit(
      universeAuctionHouse,
      'LogRoyaltiesWithdrawal'
    );

    expect(await universeAuctionHouse.royaltiesReserve(ethAddress)).to.equal('0');

    await expect(universeAuctionHouse.claimERC721Rewards(1, 1, 1)).to.be.emit(universeAuctionHouse, 'LogERC721RewardsClaim');
  });
});

