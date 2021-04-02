const { expect } = require('chai');
const { waffle, ethers } = require('hardhat');
const { loadFixture } = waffle;

describe('Deposit multiple ERC721 Tests', () => {
  const deployedContracts = async () => {
    const AuctionFactory = await ethers.getContractFactory('AuctionFactory');
    const MockNFT = await ethers.getContractFactory('MockNFT');

    const auctionFactory = await AuctionFactory.deploy(2000);
    const mockNFT = await MockNFT.deploy();

    return { auctionFactory, mockNFT };
  };

  it('should deposit multiple nft', async () => {
    const { auctionFactory, mockNFT } = await loadFixture(deployedContracts);

    await createAuction(auctionFactory);

    const [signer] = await ethers.getSigners();

    await mockNFT.mint(signer.address, 1);
    await mockNFT.approve(auctionFactory.address, 1);

    await auctionFactory.depositMultipleERC721(1, 1, [1], mockNFT.address);

    const res = await auctionFactory.getDepositedNftsInSlot(1, 1);

    expect(res.length).to.equal(1);
  });

  it('should be reverted if auction is started', async () => {
    const { auctionFactory, mockNFT } = await loadFixture(deployedContracts);

    await createAuction(auctionFactory);

    await createAuction(auctionFactory);

    const [signer] = await ethers.getSigners();

    await mockNFT.mint(signer.address, 1);
    await mockNFT.approve(auctionFactory.address, 1);

    await expect(auctionFactory.depositMultipleERC721(1, 1, [1], mockNFT.address)).to.be.reverted;
  });

  it('should revert if token address is 0', async () => {
    const { auctionFactory, mockNFT } = await loadFixture(deployedContracts);

    await createAuction(auctionFactory);

    const [signer] = await ethers.getSigners();

    await mockNFT.mint(signer.address, 1);
    await mockNFT.approve(auctionFactory.address, 1);

    await expect(auctionFactory.depositMultipleERC721(1, 1, [1], '0x0000000000000000000000000000000000000000')).to.be
      .reverted;
  });

  it('should revert if whitelist is supported', async () => {
    const { auctionFactory, mockNFT } = await loadFixture(deployedContracts);

    const blockNumber = await ethers.provider.getBlockNumber();

    const startBlockNumber = blockNumber + 5;
    const endBlockNumber = blockNumber + 6;
    const resetTimer = 3;
    const numberOfSlots = 1;
    const supportsWhitelist = true;
    const ethAddress = '0x0000000000000000000000000000000000000000';

    await auctionFactory.createAuction(
      startBlockNumber,
      endBlockNumber,
      resetTimer,
      numberOfSlots,
      supportsWhitelist,
      ethAddress
    );

    const [signer] = await ethers.getSigners();

    await mockNFT.mint(signer.address, 1);
    await mockNFT.approve(auctionFactory.address, 1);

    await expect(auctionFactory.depositMultipleERC721(1, 1, [1], mockNFT.address)).to.be.reverted;
  });

  it('should deposit if user is part of the whitelist', async () => {
    const { auctionFactory, mockNFT } = await loadFixture(deployedContracts);

    const blockNumber = await ethers.provider.getBlockNumber();

    const startBlockNumber = blockNumber + 5;
    const endBlockNumber = blockNumber + 6;
    const resetTimer = 3;
    const numberOfSlots = 1;
    const supportsWhitelist = true;
    const ethAddress = '0x0000000000000000000000000000000000000000';

    await auctionFactory.createAuction(
      startBlockNumber,
      endBlockNumber,
      resetTimer,
      numberOfSlots,
      supportsWhitelist,
      ethAddress
    );

    const [signer] = await ethers.getSigners();

    await mockNFT.mint(signer.address, 1);
    await mockNFT.approve(auctionFactory.address, 1);

    await auctionFactory.whitelistMultipleAddresses(1, [signer.address]);

    await auctionFactory.depositMultipleERC721(1, 1, [1], mockNFT.address);
  });

  it('should revert if try to deposit in no existing slot', async () => {
    const { auctionFactory, mockNFT } = await loadFixture(deployedContracts);

    await createAuction(auctionFactory);

    const [signer] = await ethers.getSigners();

    await mockNFT.mint(signer.address, 1);
    await mockNFT.approve(auctionFactory.address, 1);

    await expect(auctionFactory.depositMultipleERC721(1, 10, [1], mockNFT.address)).to.be.reverted;
  });
});

const createAuction = async (auctionFactory) => {
  const blockNumber = await ethers.provider.getBlockNumber();

  const startBlockNumber = blockNumber + 5;
  const endBlockNumber = blockNumber + 6;
  const resetTimer = 3;
  const numberOfSlots = 1;
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
