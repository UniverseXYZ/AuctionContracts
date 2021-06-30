const { expect } = require('chai');
const { waffle, ethers, network } = require('hardhat');
const { loadFixture } = waffle;

describe('Test bidding with ETH', () => {
  const deployedContracts = async () => {
    const AuctionFactory = await ethers.getContractFactory('AuctionFactory');
    const MockNFT = await ethers.getContractFactory('MockNFT');

    const auctionFactory = await AuctionFactory.deploy(2000, 100);
    const mockNFT = await MockNFT.deploy();

    return { auctionFactory, mockNFT };
  };

  it('should bid, withdraw and check lowestEligibleBid with ETH successfully', async () => {
    let { auctionFactory, mockNFT } = await loadFixture(deployedContracts);

    const currentTime = Math.round((new Date()).getTime() / 1000);

    const startTime = currentTime + 1000;
    const endTime = startTime + 500;
    const resetTimer = 10;
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

    await depositNFT(auctionFactory, mockNFT);

    await ethers.provider.send('evm_setNextBlockTimestamp', [startTime + 100]); 
    await ethers.provider.send('evm_mine');

    expect(
      await auctionFactory.functions['ethBid(uint256)'](1, {
        value: '100000000000000000000'
      })
    ).to.be.emit(auctionFactory, 'LogBidSubmitted');

    const [owner, addr1] = await ethers.getSigners();

    expect(
      await auctionFactory.connect(addr1).functions['ethBid(uint256)'](1, {
        value: '200000000000000000000'
      })
    ).to.be.emit(auctionFactory, 'LogBidSubmitted');
  });

  it('should revert if auction do not exists', async () => {
    let { auctionFactory, mockNFT } = await loadFixture(deployedContracts);

    await createAuction(auctionFactory);

    await depositNFT(auctionFactory, mockNFT);

    await expect(
      auctionFactory.functions['ethBid(uint256)'](3, {
        value: '100000000000000000000'
      })
    ).to.be.reverted;
  });

  it('should revert if amount is 0', async () => {
    let { auctionFactory, mockNFT } = await loadFixture(deployedContracts);

    const currentTime = Math.round((new Date()).getTime() / 1000);

    const startTime = currentTime + 1000;
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

    await depositNFT(auctionFactory, mockNFT);

    await expect(
      auctionFactory.functions['ethBid(uint256)'](1, {
        value: '0'
      })
    ).to.be.reverted;
  });

  it('should revert if auction is not started', async () => {
    let { auctionFactory, mockNFT } = await loadFixture(deployedContracts);

    await createAuction(auctionFactory);

    await depositNFT(auctionFactory, mockNFT);

    await expect(
      auctionFactory.functions['ethBid(uint256)'](1, {
        value: '0'
      })
    ).to.be.reverted;
  });

  it('should revert if auction accept only ERC20', async () => {
    let { auctionFactory, mockNFT } = await loadFixture(deployedContracts);

    const currentTime = Math.round((new Date()).getTime() / 1000);

    const startTime = currentTime + 1000;
    const endTime = startTime + 500;
    const resetTimer = 3;
    const numberOfSlots = 1;
    const supportsWhitelist = false;
    const tokenAddress = '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2';

    await auctionFactory.createAuction(
      startTime,
      endTime,
      resetTimer,
      numberOfSlots,
      supportsWhitelist,
      tokenAddress
    );

    await depositNFT(auctionFactory, mockNFT);

    await expect(
      auctionFactory.functions['ethBid(uint256)'](1, {
        value: '100000000000000000000'
      })
    ).to.be.reverted;
  });

  it('should revert if auction canceled', async () => {
    let { auctionFactory, mockNFT } = await loadFixture(deployedContracts);

    const currentTime = Math.round((new Date()).getTime() / 1000);

    const startTime = currentTime + 1000;
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

    await depositNFT(auctionFactory, mockNFT);

    await auctionFactory.cancelAuction(1);

    await expect(
      auctionFactory.functions['ethBid(uint256)'](1, {
        value: '100000000000000000000'
      })
    ).to.be.reverted;
  });

  it('should revert if there is no bid on all slots and user try to withdrawal', async () => {
    let { auctionFactory, mockNFT } = await loadFixture(deployedContracts);

    const currentTime = Math.round((new Date()).getTime() / 1000);

    const startTime = currentTime + 1000;
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

    await depositNFT(auctionFactory, mockNFT);

    await ethers.provider.send('evm_setNextBlockTimestamp', [startTime + 10]); 
    await ethers.provider.send('evm_mine');

    await auctionFactory.functions['ethBid(uint256)'](1, {
      value: '100000000000000000000'
    });

    await expect(auctionFactory.withdrawEthBid(1)).to.be.reverted;
  });

  it('should revert if there is no bid on all slots and user try to withdrawal', async () => {
    let { auctionFactory, mockNFT } = await loadFixture(deployedContracts);

    const currentTime = Math.round((new Date()).getTime() / 1000);

    const startTime = currentTime + 1000;
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

    await depositNFT(auctionFactory, mockNFT);

    await ethers.provider.send('evm_setNextBlockTimestamp', [startTime + 10]); 
    await ethers.provider.send('evm_mine');

    await auctionFactory.functions['ethBid(uint256)'](1, {
      value: '100000000000000000000'
    });

    await auctionFactory.functions['ethBid(uint256)'](1, {
      value: '110000000000000000000'
    });

    await expect(auctionFactory.withdrawEthBid(1)).to.be.reverted;
  });

  it('should revert if sender have 0 deposited', async () => {
    let { auctionFactory, mockNFT } = await loadFixture(deployedContracts);

    const currentTime = Math.round((new Date()).getTime() / 1000);

    const startTime = currentTime + 1000;
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

    await depositNFT(auctionFactory, mockNFT);

    await ethers.provider.send('evm_setNextBlockTimestamp', [startTime + 100]); 
    await ethers.provider.send('evm_mine');

    const [signer, signer2, signer3] = await ethers.getSigners();

    auctionFactory.connect(signer2).functions['ethBid(uint256)'](1, {
      value: '100000000000000000000'
    });

    auctionFactory.connect(signer3).functions['ethBid(uint256)'](1, {
      value: '110000000000000000000'
    });

    await expect(auctionFactory.connect(signer).withdrawEthBid(1)).to.be.reverted;
  });
});

const createAuction = async (auctionFactory) => {
  const currentTime = Math.round((new Date()).getTime() / 1000);

  const startTime = currentTime + 1000;
  const endTime = startTime + 500;
  const resetTimer = 10;
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

const depositNFT = async (auctionFactory, mockNFT) => {
  const [owner] = await ethers.getSigners();

  const auctionId = 1;
  const slotIdx = 1;
  const tokenId = 1;

  await mockNFT.mint(owner.address, 'nftURI');
  await mockNFT.approve(auctionFactory.address, tokenId);

  await auctionFactory.depositERC721(auctionId, slotIdx, tokenId, mockNFT.address);
};
