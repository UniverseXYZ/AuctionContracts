const { waffle, network } = require('hardhat');
const { loadFixture } = waffle;
const { expect } = require('chai');

function chunkifyArray(
  nftsArr,
  chunkSize,
) {
  let chunkifiedArray = [];
  let tokenStartIndex = 0;
  let tokenEndIndex = nftsArr.length % chunkSize;

  do {
    if(tokenEndIndex != 0) chunkifiedArray.push(
      nftsArr.slice(tokenStartIndex, (tokenEndIndex))
    )

    tokenStartIndex = tokenEndIndex
    tokenEndIndex = tokenStartIndex + chunkSize
  } while (tokenStartIndex < nftsArr.length);

  return chunkifiedArray;
}

describe('Withdraw functionalities', () => {
  async function deployContract() {
    const AuctionFactory = await ethers.getContractFactory('AuctionFactory');
    const MockNFT = await ethers.getContractFactory('MockNFT');
    const MockToken = await ethers.getContractFactory('MockToken');

    const auctionFactory = await AuctionFactory.deploy(2000, 100);
    const mockNFT = await MockNFT.deploy();
    const mockToken = await MockToken.deploy(1000);

    return { auctionFactory, mockNFT, mockToken };
  }

  it('should withdraw ERC721 from non winning slot', async () => {
    const { auctionFactory, mockNFT } = await loadFixture(deployContract);

    const NFT_TOKEN_COUNT = 100;
    const NFT_CHUNK_SIZE = 40;

    const currentTime = Math.round((new Date()).getTime() / 1000);

    const startTime = currentTime + 10000;
    const endTime = startTime + 1500;
    const resetTimer = 1;
    const numberOfSlots = 3;
    const ethAddress = '0x0000000000000000000000000000000000000000';
    const whitelistAddresses = []
    const minimumReserveValues = ['100000000000000000000', '100000000000000000000', '100000000000000000000'];

    await auctionFactory.createAuction(
      startTime,
      endTime,
      resetTimer,
      numberOfSlots,
      ethAddress,
      whitelistAddresses,
      minimumReserveValues
    );

    const [signer, signer2, signer3] = await ethers.getSigners();

    const multipleMockNFTs = new Array(NFT_TOKEN_COUNT);

    // mint required nfts
    for (let i = 1; i <= NFT_TOKEN_COUNT; i++) {
      await mockNFT.mint(signer.address, i);
      await mockNFT.approve(auctionFactory.address, i);

      multipleMockNFTs[i - 1] = [i, mockNFT.address];
    }

    // get matrix of nft chunks [ [nft, nft], [nft, nft] ]
    const chunksOfNfts = chunkifyArray(multipleMockNFTs, NFT_CHUNK_SIZE)

    // iterate chunks and deposit each one
    for (let chunk = 0; chunk < chunksOfNfts.length; chunk++) {
      await auctionFactory.depositMultipleERC721(1, 1, chunksOfNfts[chunk]);
    }

    // const res = await auctionFactory.getDepositedNftsInSlot(1, 1);

    await ethers.provider.send('evm_setNextBlockTimestamp', [startTime + 750]); 
    await ethers.provider.send('evm_mine');

    await auctionFactory.functions['ethBid(uint256)'](1, {
      value: '10000000000000000000'
    });

    await auctionFactory.connect(signer2).functions['ethBid(uint256)'](1, {
      value: '10000000000000000000'
    });

    await auctionFactory.connect(signer3).functions['ethBid(uint256)'](1, {
      value: '10000000000000000000'
    });

    const reserveForFirstSlot = await auctionFactory.getMinimumReservePriceForSlot(1, 1);

    expect(reserveForFirstSlot.toString()).to.equal('100000000000000000000');

    await ethers.provider.send('evm_setNextBlockTimestamp', [endTime + 1200]); 
    await ethers.provider.send('evm_mine');

    await auctionFactory.finalizeAuction(1);

    await expect(auctionFactory.withdrawMultipleERC721FromNonWinningSlot(1, 1, 40)).emit(
      auctionFactory,
      "LogERC721Withdrawal"
    );
    await expect(auctionFactory.withdrawMultipleERC721FromNonWinningSlot(1, 1, 40)).emit(
      auctionFactory,
      "LogERC721Withdrawal"
    );
    await expect(auctionFactory.withdrawMultipleERC721FromNonWinningSlot(1, 1, 30)).revertedWith(
      "Cannot withdraw more than the existing available"
    );
    await expect(auctionFactory.withdrawMultipleERC721FromNonWinningSlot(1, 1, 41)).revertedWith(
      "Cannot withdraw more than 40 NFTs in one transaction"
    );
    await expect(auctionFactory.withdrawMultipleERC721FromNonWinningSlot(1, 1, 20)).emit(
      auctionFactory,
      "LogERC721Withdrawal"
    );
  });

  it('should revert with Only depositor can withdraw', async () => {
    const { auctionFactory, mockNFT } = await loadFixture(deployContract);
    const currentTime = Math.round((new Date()).getTime() / 1000);
  
    const startTime = currentTime + 10000;
    const endTime = startTime + 500;
    const resetTimer = 2;
    const numberOfSlots = 3;
    const ethAddress = '0x0000000000000000000000000000000000000000';
    const whitelistAddresses = []
    const minimumReserveValues = ['100000000000000000000', '100000000000000000000', '100000000000000000000'];
  
    await auctionFactory.createAuction(
      startTime,
      endTime,
      resetTimer,
      numberOfSlots,
      ethAddress,
      whitelistAddresses,
      minimumReserveValues
    );

    const [signer, signer2, signer3] = await ethers.getSigners();
    const auctionId = 1;
    const slotIdx = 1;
    const tokenId = 1;

    await mockNFT.mint(signer.address, 'NFT_URI');

    await mockNFT.approve(auctionFactory.address, tokenId);

    await auctionFactory.depositERC721(auctionId, slotIdx, tokenId, mockNFT.address);

    await ethers.provider.send('evm_setNextBlockTimestamp', [startTime + 400]); 
    await ethers.provider.send('evm_mine');

    await auctionFactory.functions['ethBid(uint256)'](1, {
      value: '10000000000000000000'
    });

    await auctionFactory.connect(signer2).functions['ethBid(uint256)'](1, {
      value: '10000000000000000000'
    });

    await auctionFactory.connect(signer3).functions['ethBid(uint256)'](1, {
      value: '10000000000000000000'
    });

    await ethers.provider.send('evm_setNextBlockTimestamp', [startTime + 1200]); 
    await ethers.provider.send('evm_mine');

    await auctionFactory.finalizeAuction(1);

    await expect(auctionFactory.connect(signer2).withdrawERC721FromNonWinningSlot(1, 1, 1)).revertedWith(
      'Only depositor can withdraw'
    );
  });

  it('should revert with Auction should be finalized', async () => {
    const { auctionFactory, mockNFT } = await loadFixture(deployContract);
    const currentTime = Math.round((new Date()).getTime() / 1000);
  
    const startTime = currentTime + 10000;
    const endTime = startTime + 500;
    const resetTimer = 2;
    const numberOfSlots = 3;
    const ethAddress = '0x0000000000000000000000000000000000000000';
    const whitelistAddresses = []
    const minimumReserveValues = ['100000000000000000000', '100000000000000000000', '100000000000000000000'];
  
    await auctionFactory.createAuction(
      startTime,
      endTime,
      resetTimer,
      numberOfSlots,
      ethAddress,
      whitelistAddresses,
      minimumReserveValues
    );

    const [signer, signer2, signer3] = await ethers.getSigners();
    const auctionId = 1;
    const slotIdx = 1;
    const tokenId = 1;

    await mockNFT.mint(signer.address, 'NFT_URI');

    await mockNFT.approve(auctionFactory.address, tokenId);

    await auctionFactory.depositERC721(auctionId, slotIdx, tokenId, mockNFT.address);

    await ethers.provider.send('evm_setNextBlockTimestamp', [startTime + 400]); 
    await ethers.provider.send('evm_mine');

    await auctionFactory.functions['ethBid(uint256)'](1, {
      value: '10000000000000000000'
    });

    await auctionFactory.connect(signer2).functions['ethBid(uint256)'](1, {
      value: '10000000000000000000'
    });

    await auctionFactory.connect(signer3).functions['ethBid(uint256)'](1, {
      value: '10000000000000000000'
    });

    await expect(auctionFactory.withdrawERC721FromNonWinningSlot(1, 1, 1)).revertedWith('Auction should be finalized');
  });

  it('should revert with Can withdraw only if reserve price is not met', async () => {
    const { auctionFactory, mockNFT } = await loadFixture(deployContract);
    const currentTime = Math.round((new Date()).getTime() / 1000);
  
    const startTime = currentTime + 10000;
    const endTime = startTime + 500;
    const resetTimer = 2;
    const numberOfSlots = 3;
    const ethAddress = '0x0000000000000000000000000000000000000000';
    const whitelistAddresses = []
    const minimumReserveValues = ['1000000000000000000', '1000000000000000000', '1000000000000000000'];
  
    await auctionFactory.createAuction(
      startTime,
      endTime,
      resetTimer,
      numberOfSlots,
      ethAddress,
      whitelistAddresses,
      minimumReserveValues
    );

    const [signer, signer2, signer3] = await ethers.getSigners();
    const auctionId = 1;
    const slotIdx = 1;
    const tokenId = 1;

    await mockNFT.mint(signer.address, 'NFT_URI');

    await mockNFT.approve(auctionFactory.address, tokenId);
    await auctionFactory.depositERC721(1, 1, 1, mockNFT.address);

    await ethers.provider.send('evm_setNextBlockTimestamp', [startTime + 400]); 
    await ethers.provider.send('evm_mine');

    await auctionFactory.connect(signer).functions['ethBid(uint256)'](1, {
      value: '1000000000000000000'
    });

    await auctionFactory.connect(signer2).functions['ethBid(uint256)'](1, {
      value: '1000000000000000000'
    });

    await auctionFactory.connect(signer3).functions['ethBid(uint256)'](1, {
      value: '1000000000000000000'
    });

    await ethers.provider.send('evm_setNextBlockTimestamp', [endTime + 1200]); 
    await ethers.provider.send('evm_mine');

    await auctionFactory.finalizeAuction(1);

    await expect(auctionFactory.withdrawERC721FromNonWinningSlot(1, 1, 1)).revertedWith(
      'Can withdraw only if reserve price is not met'
    );
  });

  it('should revert with You have 0 deposited', async () => {
    const { auctionFactory, mockNFT } = await loadFixture(deployContract);
    const currentTime = Math.round((new Date()).getTime() / 1000);
  
    const startTime = currentTime + 10000;
    const endTime = startTime + 500;
    const resetTimer = 2;
    const numberOfSlots = 3;
    const ethAddress = '0x0000000000000000000000000000000000000000';
    const whitelistAddresses = []
    const minimumReserveValues = ['100000000000000000000', '100000000000000000000', '100000000000000000000'];
  
    await auctionFactory.createAuction(
      startTime,
      endTime,
      resetTimer,
      numberOfSlots,
      ethAddress,
      whitelistAddresses,
      minimumReserveValues
    );

    const [signer, signer2, signer3, signer4, signer5] = await ethers.getSigners();
    const auctionId = 1;
    const slotIdx = 1;
    const tokenId = 1;

    await mockNFT.mint(signer.address, 'NFT_URI');

    await mockNFT.approve(auctionFactory.address, tokenId);

    await auctionFactory.depositERC721(auctionId, slotIdx, tokenId, mockNFT.address);

    await ethers.provider.send('evm_setNextBlockTimestamp', [startTime + 400]); 
    await ethers.provider.send('evm_mine');

    await auctionFactory.functions['ethBid(uint256)'](1, {
      value: '100000000000000000000'
    });

    await auctionFactory.connect(signer2).functions['ethBid(uint256)'](1, {
      value: '100000000000000000001'
    });

    await auctionFactory.connect(signer3).functions['ethBid(uint256)'](1, {
      value: '100000000000000000002'
    });

    await auctionFactory.connect(signer4).functions['ethBid(uint256)'](1, {
      value: '100000000000000000003'
    });

    await ethers.provider.send('evm_setNextBlockTimestamp', [endTime + 1200]); 
    await ethers.provider.send('evm_mine');

    await auctionFactory.finalizeAuction(1);

    await expect(auctionFactory.connect(signer5).withdrawEthBid(1)).revertedWith('You have 0 deposited');
  });

  it('should revert with Auction should be finalized', async () => {
    const { auctionFactory, mockNFT } = await loadFixture(deployContract);
    const currentTime = Math.round((new Date()).getTime() / 1000);
  
    const startTime = currentTime + 10000;
    const endTime = startTime + 500;
    const resetTimer = 5;
    const numberOfSlots = 4;
    const ethAddress = '0x0000000000000000000000000000000000000000';
    const whitelistAddresses = []
    const minimumReserveValues = ['100000000000000000000', '100000000000000000000', '100000000000000000000', '100000000000000000000'];
  
    await auctionFactory.createAuction(
      startTime,
      endTime,
      resetTimer,
      numberOfSlots,
      ethAddress,
      whitelistAddresses,
      minimumReserveValues
    );

    const [signer, signer2, signer3, signer4] = await ethers.getSigners();
    const auctionId = 1;
    const slotIdx = 1;
    const tokenId = 1;

    await mockNFT.mint(signer.address, 'NFT_URI');

    await mockNFT.approve(auctionFactory.address, tokenId);

    await auctionFactory.depositERC721(auctionId, slotIdx, tokenId, mockNFT.address);

    await ethers.provider.send('evm_setNextBlockTimestamp', [startTime + 400]); 
    await ethers.provider.send('evm_mine')

    await auctionFactory.functions['ethBid(uint256)'](1, {
      value: '100000000000000000000'
    });

    await auctionFactory.connect(signer2).functions['ethBid(uint256)'](1, {
      value: '200000000000000000000'
    });

    await auctionFactory.connect(signer3).functions['ethBid(uint256)'](1, {
      value: '300000000000000000000'
    });

    await auctionFactory.connect(signer4).functions['ethBid(uint256)'](1, {
      value: '500000000000000000000'
    });

    await expect(auctionFactory.withdrawEthBid(1)).revertedWith('Cannot withdraw winning bid!');
  });

  it('should withdraw erc20', async () => {
    const { auctionFactory, mockNFT, mockToken } = await loadFixture(deployContract);
    const currentTime = Math.round((new Date()).getTime() / 1000);

    const startTime = currentTime + 10000;
    const endTime = startTime + 500;
    const resetTimer = 1;
    const numberOfSlots = 2;
    const whitelistAddresses = []
    const minimumReserveValues = ['200', '200']
  
    await auctionFactory.createAuction(
      startTime,
      endTime,
      resetTimer,
      numberOfSlots,
      mockToken.address,
      whitelistAddresses,
      minimumReserveValues
    );

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

    await ethers.provider.send('evm_setNextBlockTimestamp', [startTime + 400]); 
    await ethers.provider.send('evm_mine')

    await auctionFactory.functions['erc20Bid(uint256,uint256)'](1, 100);

    await auctionFactory.connect(signer2).functions['erc20Bid(uint256,uint256)'](1, 110);

    await auctionFactory.connect(signer3).functions['erc20Bid(uint256,uint256)'](1, 120);

    await ethers.provider.send('evm_setNextBlockTimestamp', [endTime + 1200]); 
    await ethers.provider.send('evm_mine')

    await auctionFactory.finalizeAuction(1);

    await expect(auctionFactory.withdrawERC20Bid(1)).emit(auctionFactory, 'LogBidWithdrawal');

    const balance = await auctionFactory.getBidderBalance(1, signer.address);

    expect(balance.toString()).equal('0');
  });

  it('should revert with You have 0 deposited', async () => {
    const { auctionFactory, mockNFT, mockToken } = await loadFixture(deployContract);
    const currentTime = Math.round((new Date()).getTime() / 1000);

    const startTime = currentTime + 10000;
    const endTime = startTime + 500;
    const resetTimer = 1;
    const numberOfSlots = 3;
    const whitelistAddresses = []
    const minimumReserveValues = ['200', '200', '200'];
  
    await auctionFactory.createAuction(
      startTime,
      endTime,
      resetTimer,
      numberOfSlots,
      mockToken.address,
      whitelistAddresses,
      minimumReserveValues
    );

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

    await ethers.provider.send('evm_setNextBlockTimestamp', [startTime + 400]); 
    await ethers.provider.send('evm_mine')

    await auctionFactory.connect(signer).functions['erc20Bid(uint256,uint256)'](1, 100);

    await auctionFactory.connect(signer2).functions['erc20Bid(uint256,uint256)'](1, 110);

    await auctionFactory.connect(signer3).functions['erc20Bid(uint256,uint256)'](1, 120);

    await ethers.provider.send('evm_setNextBlockTimestamp', [endTime + 1200]); 
    await ethers.provider.send('evm_mine')

    await auctionFactory.finalizeAuction(1);

    await expect(auctionFactory.connect(signer4).withdrawERC20Bid(1)).revertedWith('You have 0 deposited');
  });

  it('should revert with Auction should be finalized', async () => {
    const { auctionFactory, mockNFT, mockToken } = await loadFixture(deployContract);
    const currentTime = Math.round((new Date()).getTime() / 1000);

    const startTime = currentTime + 10000;
    const endTime = startTime + 500;
    const resetTimer = 1;
    const numberOfSlots = 3;
    const whitelistAddresses = [];
    const minimumReserveValues = ['200', '200', '200'];
  
    await auctionFactory.createAuction(
      startTime,
      endTime,
      resetTimer,
      numberOfSlots,
      mockToken.address,
      whitelistAddresses,
      minimumReserveValues
    );

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

    await ethers.provider.send('evm_setNextBlockTimestamp', [startTime + 400]); 
    await ethers.provider.send('evm_mine')

    await auctionFactory.functions['erc20Bid(uint256,uint256)'](1, 100);

    await auctionFactory.connect(signer2).functions['erc20Bid(uint256,uint256)'](1, 110);

    await auctionFactory.connect(signer3).functions['erc20Bid(uint256,uint256)'](1, 120);

    await expect(auctionFactory.withdrawERC20Bid(1)).revertedWith('Cannot withdraw winning bid!');
  });
});

const createAuction = async (auctionFactory) => {
  const currentTime = Math.round((new Date()).getTime() / 1000);

  const startTime = currentTime + 10000;
  const endTime = startTime + 500;
  const resetTimer = 2;
  const numberOfSlots = 3;
  const ethAddress = '0x0000000000000000000000000000000000000000';
  const whitelistAddresses = []

  await auctionFactory.createAuction(
    startTime,
    endTime,
    resetTimer,
    numberOfSlots,
    ethAddress,
    whitelistAddresses
  );
};

const createERC20Auction = async (auctionFactory, tokenAddress) => {
  const currentTime = Math.round((new Date()).getTime() / 1000);

  const startTime = currentTime + 10000;
  const endTime = startTime + 500;
  const resetTimer = 1;
  const numberOfSlots = 3;

  await auctionFactory.createAuction(
    startTime,
    endTime,
    resetTimer,
    numberOfSlots,
    supportsWhitelist,
    tokenAddress
  );
};
