const { expect } = require('chai');
const { waffle, ethers } = require('hardhat');
const { loadFixture } = waffle;

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

describe('Deposit multiple ERC721 Tests', () => {
  const deployedContracts = async () => {
    const [owner, addr1] = await ethers.getSigners();
    const AuctionFactory = await ethers.getContractFactory('AuctionFactory');
    const MockNFT = await ethers.getContractFactory('MockNFT');

    const auctionFactory = await AuctionFactory.deploy(2000, 100, 0, owner.address, []);
    const mockNFT = await MockNFT.deploy();

    return { auctionFactory, mockNFT };
  };

  it('should deposit multiple nft', async () => {
    const NFT_TOKEN_COUNT = 100;
    const NFT_CHUNK_SIZE = 20;

    const { auctionFactory, mockNFT } = await loadFixture(deployedContracts);

    await createAuction(auctionFactory);

    const [signer] = await ethers.getSigners();

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

    const res = await auctionFactory.getDepositedNftsInSlot(1, 1);

    expect(res.length).to.equal(NFT_TOKEN_COUNT);
  });

  it('should not be reverted if auction has not started', async () => {
    const { auctionFactory, mockNFT } = await loadFixture(deployedContracts);

    await createAuction(auctionFactory);

    const [signer] = await ethers.getSigners();

    await mockNFT.mint(signer.address, 1);
    await mockNFT.approve(auctionFactory.address, 1);

    await auctionFactory.depositMultipleERC721(1, 1, [[1, mockNFT.address]]);
  });

  it('should revert if token address is 0', async () => {
    const { auctionFactory, mockNFT } = await loadFixture(deployedContracts);

    await createAuction(auctionFactory);

    const [signer] = await ethers.getSigners();

    await mockNFT.mint(signer.address, 1);
    await mockNFT.approve(auctionFactory.address, 1);

    await expect(auctionFactory.depositMultipleERC721(1, 1, [[1, '0x0000000000000000000000000000000000000000']])).to.be
      .reverted;
  });

  it('should revert if whitelist is supported', async () => {
    const { auctionFactory, mockNFT } = await loadFixture(deployedContracts);
    const [signer, signer2] = await ethers.getSigners();

    const currentTime = Math.round((new Date()).getTime() / 1000);

    const startTime = currentTime + 1500;
    const endTime = startTime + 500;
    const resetTimer = 3;
    const numberOfSlots = 1;
    const supportsWhitelist = true;
    const ethAddress = '0x0000000000000000000000000000000000000000';
    const whitelistAddresses = [signer2.address];
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

    await mockNFT.mint(signer.address, 1);
    await mockNFT.approve(auctionFactory.address, 1);

    await expect(auctionFactory.depositMultipleERC721(1, 1, [[1, mockNFT.address]])).to.be.reverted;
  });

  it('should deposit if user is part of the whitelist', async () => {
    const { auctionFactory, mockNFT } = await loadFixture(deployedContracts);    
    const [signer] = await ethers.getSigners();

    const currentTime = Math.round((new Date()).getTime() / 1000);

    const startTime = currentTime + 1500;
    const endTime = startTime + 500;
    const resetTimer = 3;
    const numberOfSlots = 1;
    const supportsWhitelist = true;
    const ethAddress = '0x0000000000000000000000000000000000000000';
    const whitelistAddresses = [signer.address]
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

    await mockNFT.mint(signer.address, 1);
    await mockNFT.approve(auctionFactory.address, 1);

    await auctionFactory.depositMultipleERC721(1, 1, [[1, mockNFT.address]]);
  });

  it('should revert if try to deposit in no existing slot', async () => {
    const { auctionFactory, mockNFT } = await loadFixture(deployedContracts);

    await createAuction(auctionFactory);

    const [signer] = await ethers.getSigners();

    await mockNFT.mint(signer.address, 1);
    await mockNFT.approve(auctionFactory.address, 1);

    await expect(auctionFactory.depositMultipleERC721(1, 2, [[1, mockNFT.address]])).to.be.reverted;
  });
});

const createAuction = async (auctionFactory) => {
  const currentTime = Math.round((new Date()).getTime() / 1000);

  const startTime = currentTime + 1500;
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
};
