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

    expect(await auctionFactory.depositERC721(auctionId, slotIdx, tokenId, mockNFT.address)).to.be.emit(
      auctionFactory,
      'LogERC721Deposit'
    );
  });

  it('should withdrawDepositedERC721 deposited nft', async () => {
    const { auctionFactory, mockNFT } = await loadFixture(deployedContracts);

    const blockNumber = await ethers.provider.getBlockNumber();

    const startBlockNumber = blockNumber + 10;
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

    expect(await auctionFactory.totalAuctions()).to.equal(1);

    const [owner] = await ethers.getSigners();

    const auctionId = 1;
    const slotIdx = 0;
    const tokenId = 1;

    await mockNFT.mint(owner.address, 'nftURI');
    await mockNFT.approve(auctionFactory.address, tokenId);

    await auctionFactory.depositERC721(auctionId, slotIdx, tokenId, mockNFT.address);

    await expect(auctionFactory.withdrawDepositedERC721(1, 0, 1)).to.be.emit(auctionFactory, 'LogERC721Withdrawal');
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

    await expect(auctionFactory.depositERC721(auctionId, slotIdx, tokenId, mockNFT.address)).to.be.reverted;
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

    await expect(auctionFactory.depositERC721(auctionId, slotIdx, tokenId, mockNFT.address)).to.be.reverted;
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

    await expect(auctionFactory.depositERC721(auctionId, slotIdx, tokenId, mockNFT.address)).to.be.reverted;
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
      auctionFactory.depositERC721(auctionId, slotIdx, tokenId, '0x0000000000000000000000000000000000000000')
    ).to.be.reverted;
  });

  it('should revert if tokenAddress is 0', async () => {
    const { auctionFactory, mockNFT } = await loadFixture(deployedContracts);

    await createAuction(deployedContracts);

    const [owner] = await ethers.getSigners();

    const auctionId = 1;
    const slotIdx = 0;
    const tokenId = 1;

    await mockNFT.mint(owner.address, 'nftURI');
    await mockNFT.approve(auctionFactory.address, tokenId);

    await expect(
      auctionFactory.depositERC721(auctionId, slotIdx, tokenId, '0x0000000000000000000000000000000000000000')
    ).to.be.reverted;
  });

  it('should deposit only if part of whitelist', async () => {
    const { auctionFactory, mockNFT } = await loadFixture(deployedContracts);
    const blockNumber = await ethers.provider.getBlockNumber();

    const startBlockNumber = blockNumber + 5;
    const endBlockNumber = blockNumber + 15;
    const resetTimer = 3;
    const numberOfSlots = 10;
    const supportsWhitelist = true;
    const bidToken = '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2';

    await auctionFactory.createAuction(
      startBlockNumber,
      endBlockNumber,
      resetTimer,
      numberOfSlots,
      supportsWhitelist,
      bidToken
    );

    const [owner] = await ethers.getSigners();

    const auctionId = 1;
    const slotIdx = 0;
    const tokenId = 1;

    await mockNFT.mint(owner.address, 'nftURI');
    await mockNFT.approve(auctionFactory.address, tokenId);

    await expect(auctionFactory.depositERC721(auctionId, slotIdx, tokenId, mockNFT.address)).to.be.reverted;
  });

  it('should revert if user try to deposit in no existing slot', async () => {
    const { auctionFactory, mockNFT } = await loadFixture(deployedContracts);

    await createAuction(deployedContracts);

    expect(await auctionFactory.totalAuctions()).to.equal(1);

    const [owner] = await ethers.getSigners();

    const auctionId = 1;
    const slotIdx = 11;
    const tokenId = 1;

    await mockNFT.mint(owner.address, 'nftURI');
    await mockNFT.approve(auctionFactory.address, tokenId);

    await expect(auctionFactory.depositERC721(auctionId, slotIdx, tokenId, mockNFT.address)).to.be.reverted;
  });

  it('should revert cuz Only depositor can withdraw', async () => {
    const { auctionFactory, mockNFT } = await loadFixture(deployedContracts);

    const blockNumber = await ethers.provider.getBlockNumber();

    const startBlockNumber = blockNumber + 7;
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
    const [signer1, signer2] = await ethers.getSigners();

    const auctionId = 1;
    const slotIdx = 1;
    const tokenId = 1;

    await mockNFT.connect(signer2).mint(signer2.address, 'nftURI');
    await mockNFT.connect(signer2).approve(auctionFactory.address, tokenId);

    await auctionFactory.connect(signer2).depositERC721(auctionId, slotIdx, tokenId, mockNFT.address);

    await expect(auctionFactory.connect(signer1).withdrawDepositedERC721(1, 0, 1)).to.be.reverted;
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
