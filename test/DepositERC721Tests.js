const { expect } = require('chai');
const { waffle } = require('hardhat');
const { loadFixture } = waffle;

describe('DEPOSIT ERC721 Functionality', () => {
  const deployedContracts = async () => {
    const AuctionFactory = await ethers.getContractFactory('AuctionFactory');
    const MockNFT = await ethers.getContractFactory('MockNFT');

    const auctionFactory = await AuctionFactory.deploy();
    const mockNFT = await MockNFT.deploy();

    return { auctionFactory, mockNFT };
  };

  it('deposit nft successfully', async () => {
    const { auctionFactory, mockNFT } = await loadFixture(deployedContracts);

    await createAuction(deployedContracts);

    expect(await auctionFactory.totalAuctions()).to.equal(1);

    const [owner] = await ethers.getSigners();

    const auctionId = 1;
    const slotIdx = 0;
    const tokenId = 1;

    await mockNFT.mint(owner.address, 'nftURI');
    await mockNFT.approve(auctionFactory.address, tokenId);

    expect(
      await auctionFactory.depositERC721(
        auctionId,
        slotIdx,
        tokenId,
        mockNFT.address
      )
    ).to.be.emit(auctionFactory, 'LogERC721Deposit');
  });

  it('should revert if auctionId do not exists', async () => {
    const { auctionFactory, mockNFT } = await loadFixture(deployedContracts);

    await createAuction(deployedContracts);

    const [owner] = await ethers.getSigners();

    const auctionId = 2;
    const slotIdx = 0;
    const tokenId = 1;

    await mockNFT.mint(owner.address, 'nftURI');
    await mockNFT.approve(auctionFactory.address, tokenId);

    await expect(
      auctionFactory.depositERC721(auctionId, slotIdx, tokenId, mockNFT.address)
    ).to.be.reverted;
  });

  it('should revert if auctionId do not exists', async () => {
    const { auctionFactory, mockNFT } = await loadFixture(deployedContracts);

    await createAuction(deployedContracts);

    const [owner] = await ethers.getSigners();

    const auctionId = 2;
    const slotIdx = 0;
    const tokenId = 1;

    await mockNFT.mint(owner.address, 'nftURI');
    await mockNFT.approve(auctionFactory.address, tokenId);

    await expect(
      auctionFactory.depositERC721(auctionId, slotIdx, tokenId, mockNFT.address)
    ).to.be.reverted;
  });

  it('should revert if auction slot > 2000', async () => {
    const { auctionFactory, mockNFT } = await loadFixture(deployedContracts);

    await createAuction(deployedContracts);

    const [owner] = await ethers.getSigners();

    const auctionId = 2;
    const slotIdx = 2001;
    const tokenId = 1;

    await mockNFT.mint(owner.address, 'nftURI');
    await mockNFT.approve(auctionFactory.address, tokenId);

    await expect(
      auctionFactory.depositERC721(auctionId, slotIdx, tokenId, mockNFT.address)
    ).to.be.reverted;
  });

  it('should revert if tokenAddress is zero address', async () => {
    const { auctionFactory, mockNFT } = await loadFixture(deployedContracts);

    await createAuction(deployedContracts);

    const [owner] = await ethers.getSigners();

    const auctionId = 2;
    const slotIdx = 2001;
    const tokenId = 1;

    await mockNFT.mint(owner.address, 'nftURI');
    await mockNFT.approve(auctionFactory.address, tokenId);

    await expect(
      auctionFactory.depositERC721(
        auctionId,
        slotIdx,
        tokenId,
        '0x0000000000000000000000000000000000000000'
      )
    ).to.be.reverted;
  });
});

const createAuction = async (deployedContracts) => {
  const { auctionFactory, mockNft } = await loadFixture(deployedContracts);
  const blockNumber = await ethers.provider.getBlockNumber();

  const startBlockNumber = blockNumber + 5;
  const endBlockNumber = blockNumber + 15;
  const resetTimer = 3;
  const numberOfSlots = 10;
  const supportsWhitelist = false;
  const bidToken = '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2';

  await auctionFactory.createAuction(
    startBlockNumber,
    endBlockNumber,
    resetTimer,
    numberOfSlots,
    supportsWhitelist,
    bidToken
  );
};
