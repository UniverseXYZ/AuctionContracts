const { expect } = require('chai');
const { waffle } = require('hardhat');
const { loadFixture } = waffle;

describe('DEPOSIT ERC721 Functionality', () => {
  const deployedContracts = async () => {
    const [owner, addr1] = await ethers.getSigners();
    const UniverseAuctionHouse = await ethers.getContractFactory('UniverseAuctionHouse');
    const MockNFT = await ethers.getContractFactory('MockNFT');

    const universeAuctionHouse = await UniverseAuctionHouse.deploy(2000, 100, 0, owner.address, ['0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2']);
    const mockNFT = await MockNFT.deploy();

    return { universeAuctionHouse, mockNFT };
  };

  it('deposit nft successfully', async () => {
    const { universeAuctionHouse, mockNFT } = await loadFixture(deployedContracts);

    await createAuction(deployedContracts);

    expect(await universeAuctionHouse.totalAuctions()).to.equal(1);

    const [owner] = await ethers.getSigners();

    const auctionId = 1;
    const slotIdx = 1;
    const tokenId = 1;

    await mockNFT.mint(owner.address, 'nftURI');
    await mockNFT.approve(universeAuctionHouse.address, tokenId);

    expect(await universeAuctionHouse.depositERC721(auctionId, slotIdx, [[tokenId, mockNFT.address]])).to.be.emit(
      universeAuctionHouse,
      'LogERC721Deposit'
    );
  });

  it('should withdrawDepositedERC721 deposited nft', async () => {
    const { universeAuctionHouse, mockNFT } = await loadFixture(deployedContracts);

    const currentTime = Math.round((new Date()).getTime() / 1000);

    const startTime = currentTime + 1500;
    const endTime = startTime + 500;
    const resetTimer = 3;
    const numberOfSlots = 10;
    const bidToken = '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2';
    const whitelistAddresses = [];
    const minimumReserveValues = [];
    const paymentSplits = [];

    await universeAuctionHouse.createAuction([
      startTime,
      endTime,
      resetTimer,
      numberOfSlots,
      bidToken,
      whitelistAddresses,
      minimumReserveValues,
      paymentSplits
    ]);

    expect(await universeAuctionHouse.totalAuctions()).to.equal(1);

    const [owner] = await ethers.getSigners();

    const auctionId = 1;
    const slotIdx = 1;
    const tokenId = 1;

    await mockNFT.mint(owner.address, 'nftURI');
    await mockNFT.approve(universeAuctionHouse.address, tokenId);

    await universeAuctionHouse.depositERC721(auctionId, slotIdx, [[tokenId, mockNFT.address]]);
    await universeAuctionHouse.cancelAuction(auctionId);

    await expect(universeAuctionHouse.withdrawDepositedERC721(1, 1, 1)).to.be.emit(universeAuctionHouse, 'LogERC721Withdrawal');
  });

  it('should revert if auctionId do not exists', async () => {
    const { universeAuctionHouse, mockNFT } = await loadFixture(deployedContracts);

    await createAuction(deployedContracts);

    const [owner] = await ethers.getSigners();

    const auctionId = 2;
    const slotIdx = 0;
    const tokenId = 1;

    await mockNFT.mint(owner.address, 'nftURI');
    await mockNFT.approve(universeAuctionHouse.address, tokenId);

    await expect(universeAuctionHouse.depositERC721(auctionId, slotIdx, [[tokenId, mockNFT.address]])).to.be.reverted;
  });

  it('should revert if auctionId do not exists', async () => {
    const { universeAuctionHouse, mockNFT } = await loadFixture(deployedContracts);

    await createAuction(deployedContracts);

    const [owner] = await ethers.getSigners();

    const auctionId = 2;
    const slotIdx = 0;
    const tokenId = 1;

    await mockNFT.mint(owner.address, 'nftURI');
    await mockNFT.approve(universeAuctionHouse.address, tokenId);

    await expect(universeAuctionHouse.depositERC721(auctionId, slotIdx, [[tokenId, mockNFT.address]])).to.be.reverted;
  });

  it('should revert if auction slot > 2000', async () => {
    const { universeAuctionHouse, mockNFT } = await loadFixture(deployedContracts);

    await createAuction(deployedContracts);

    const [owner] = await ethers.getSigners();

    const auctionId = 2;
    const slotIdx = 2001;
    const tokenId = 1;

    await mockNFT.mint(owner.address, 'nftURI');
    await mockNFT.approve(universeAuctionHouse.address, tokenId);

    await expect(universeAuctionHouse.depositERC721(auctionId, slotIdx, [[tokenId, mockNFT.address]])).to.be.reverted;
  });

  it('should revert if tokenAddress is zero address', async () => {
    const { universeAuctionHouse, mockNFT } = await loadFixture(deployedContracts);

    await createAuction(deployedContracts);

    const [owner] = await ethers.getSigners();

    const auctionId = 2;
    const slotIdx = 2001;
    const tokenId = 1;

    await mockNFT.mint(owner.address, 'nftURI');
    await mockNFT.approve(universeAuctionHouse.address, tokenId);

    await expect(
      universeAuctionHouse.depositERC721(auctionId, slotIdx, [[tokenId, '0x0000000000000000000000000000000000000000']])
    ).to.be.reverted;
  });

  it('should revert if tokenAddress is 0', async () => {
    const { universeAuctionHouse, mockNFT } = await loadFixture(deployedContracts);

    await createAuction(deployedContracts);

    const [owner] = await ethers.getSigners();

    const auctionId = 1;
    const slotIdx = 0;
    const tokenId = 1;

    await mockNFT.mint(owner.address, 'nftURI');
    await mockNFT.approve(universeAuctionHouse.address, tokenId);

    await expect(
      universeAuctionHouse.depositERC721(auctionId, slotIdx, [[tokenId, '0x0000000000000000000000000000000000000000']])
    ).to.be.reverted;
  });

  it('should deposit only if part of whitelist', async () => {
    const { universeAuctionHouse, mockNFT } = await loadFixture(deployedContracts);
    const currentTime = Math.round((new Date()).getTime() / 1000);

    const startTime = currentTime + 1500;
    const endTime = startTime + 500;
    const resetTimer = 3;
    const numberOfSlots = 10;
    const supportsWhitelist = true;
    const bidToken = '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2';
    const whitelistAddresses = [];
    const minimumReserveValues = [];
    const paymentSplits = [];

    await universeAuctionHouse.createAuction([
      startTime,
      endTime,
      resetTimer,
      numberOfSlots,
      bidToken,
      whitelistAddresses,
      minimumReserveValues,
      paymentSplits
    ]);

    const [owner] = await ethers.getSigners();

    const auctionId = 1;
    const slotIdx = 0;
    const tokenId = 1;

    await mockNFT.mint(owner.address, 'nftURI');
    await mockNFT.approve(universeAuctionHouse.address, tokenId);

    await expect(universeAuctionHouse.depositERC721(auctionId, slotIdx, [[tokenId, mockNFT.address]])).to.be.reverted;
  });

  it('should revert if user try to deposit in no existing slot', async () => {
    const { universeAuctionHouse, mockNFT } = await loadFixture(deployedContracts);

    await createAuction(deployedContracts);

    expect(await universeAuctionHouse.totalAuctions()).to.equal(1);

    const [owner] = await ethers.getSigners();

    const auctionId = 1;
    const slotIdx = 11;
    const tokenId = 1;

    await mockNFT.mint(owner.address, 'nftURI');
    await mockNFT.approve(universeAuctionHouse.address, tokenId);

    await expect(universeAuctionHouse.depositERC721(auctionId, slotIdx, [[tokenId, mockNFT.address]])).to.be.reverted;
  });

  it('should revert cuz Only depositor can withdraw', async () => {
    const { universeAuctionHouse, mockNFT } = await loadFixture(deployedContracts);

    const currentTime = Math.round((new Date()).getTime() / 1000);

    const startTime = currentTime + 1500;
    const endTime = startTime + 500;
    const resetTimer = 3;
    const numberOfSlots = 10;
    const bidToken = '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2';
    const whitelistAddresses = [];
    const minimumReserveValues = [];
    const paymentSplits = [];

    await universeAuctionHouse.createAuction([
      startTime,
      endTime,
      resetTimer,
      numberOfSlots,
      bidToken,
      whitelistAddresses,
      minimumReserveValues,
      paymentSplits
    ]);
    const [signer1, signer2] = await ethers.getSigners();

    const auctionId = 1;
    const slotIdx = 1;
    const tokenId = 1;

    await mockNFT.connect(signer2).mint(signer2.address, 'nftURI');
    await mockNFT.connect(signer2).approve(universeAuctionHouse.address, tokenId);

    await universeAuctionHouse.connect(signer2).depositERC721(auctionId, slotIdx, [[tokenId, mockNFT.address]]);

    await expect(universeAuctionHouse.connect(signer1).withdrawDepositedERC721(1, 0, 1)).to.be.reverted;
  });
});

const createAuction = async (deployedContracts) => {
  const { universeAuctionHouse, mockNft } = await loadFixture(deployedContracts);
  const currentTime = Math.round((new Date()).getTime() / 1000);

  const startTime = currentTime + 1500;
  const endTime = startTime + 500;
  const resetTimer = 3;
  const numberOfSlots = 10;
  const bidToken = '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2';
  const whitelistAddresses = [];
  const minimumReserveValues = [];
  const paymentSplits = [];

  await universeAuctionHouse.createAuction([
    startTime,
    endTime,
    resetTimer,
    numberOfSlots,
    bidToken,
    whitelistAddresses,
    minimumReserveValues,
    paymentSplits
  ]);
};
