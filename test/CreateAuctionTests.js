const { expect } = require('chai');
const { waffle } = require('hardhat');
const { loadFixture } = waffle;

describe('Create Auction Tests', () => {
  async function deployContract() {
    const [owner, addr1] = await ethers.getSigners();
    const UniverseAuctionHouse = await ethers.getContractFactory('UniverseAuctionHouse');
    const universeAuctionHouse = await UniverseAuctionHouse.deploy(2000, 100, 0, owner.address, ['0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2']);

    return { universeAuctionHouse };
  }

  it('should deploy contract with the correct number of nfts per slot limit', async () => {
    const { universeAuctionHouse } = await loadFixture(deployContract);

    expect(await universeAuctionHouse.nftSlotLimit()).to.equal(100);
  });

  it('set the nfts per slot limit', async () => {
    const { universeAuctionHouse } = await loadFixture(deployContract);

    await universeAuctionHouse.setNftSlotLimit(50);
    expect(await universeAuctionHouse.nftSlotLimit()).to.equal(50);
  });

  it('should Deploy the UniverseAuctionHouse and MockNFT', async function () {
    const { universeAuctionHouse } = await loadFixture(deployContract);
    const currentTime = Math.round((new Date()).getTime() / 1000);

    const startTime = currentTime + 1500;
    const endTime = startTime + 500;
    const resetTimer = 3;
    const numberOfSlots = 1;
    const bidToken = '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2';
    const whitelistAddresses = [];
    const minimumReserveValues = [];
    const paymentSplits = [];
    auction = await universeAuctionHouse.createAuction([
      startTime,
      endTime,
      resetTimer,
      numberOfSlots,
      bidToken,
      whitelistAddresses,
      minimumReserveValues,
      paymentSplits
    ]);
  });

  it('should fail on startTime < currenTime', async function () {
    const { universeAuctionHouse } = await loadFixture(deployContract);
    const currentTime = Math.round((new Date()).getTime() / 1000);

    const startTime = currentTime - 1500;
    const endTime = startTime + 100;
    const resetTimer = 3;
    const numberOfSlots = 1;
    const bidToken = '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2';
    const whitelistAddresses = [];
    const minimumReserveValues = [];
    const paymentSplits = [];
    await expect(
      universeAuctionHouse.createAuction([
        startTime,
        endTime,
        resetTimer,
        numberOfSlots,
        bidToken,
        whitelistAddresses,
        minimumReserveValues,
        paymentSplits
      ])
    ).to.be.reverted;
  });

  it('should fail on endTime < startTime', async function () {
    const { universeAuctionHouse } = await loadFixture(deployContract);
    const currentTime = Math.round((new Date()).getTime() / 1000);

    const startTime = currentTime + 1000;
    const endTime = currentTime - 1000;
    const resetTimer = 3;
    const numberOfSlots = 1;
    const bidToken = '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2';
    const whitelistAddresses = [];
    const minimumReserveValues = [];
    const paymentSplits = [];
    await expect(
      universeAuctionHouse.createAuction([
        startTime,
        endTime,
        resetTimer,
        numberOfSlots,
        bidToken,
        whitelistAddresses,
        minimumReserveValues,
        paymentSplits
      ])
    ).to.be.reverted;
  });

  it('should fail if resetTimer === 0', async function () {
    const { universeAuctionHouse } = await loadFixture(deployContract);
    const currentTime = Math.round((new Date()).getTime() / 1000);

    const startTime = currentTime + 100;
    const endTime = startTime + 100;
    const resetTimer = 0;
    const numberOfSlots = 1;
    const bidToken = '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2';
    const whitelistAddresses = [];
    const minimumReserveValues = [];
    const paymentSplits = [];
    await expect(
      universeAuctionHouse.createAuction([
        startTime,
        endTime,
        resetTimer,
        numberOfSlots,
        bidToken,
        whitelistAddresses,
        minimumReserveValues,
        paymentSplits
      ])
    ).to.be.reverted;
  });

  it('should fail if numberOfSlots === 0', async function () {
    const { universeAuctionHouse } = await loadFixture(deployContract);
    const currentTime = Math.round((new Date()).getTime() / 1000);

    const startTime = currentTime + 100;
    const endTime = startTime + 100;
    const resetTimer = 3;
    const numberOfSlots = 0;
    const bidToken = '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2';
    const whitelistAddresses = [];
    const minimumReserveValues = [];
    const paymentSplits = [];
    await expect(
      universeAuctionHouse.createAuction([
        startTime,
        endTime,
        resetTimer,
        numberOfSlots,
        bidToken,
        whitelistAddresses,
        minimumReserveValues,
        paymentSplits
      ])
    ).to.be.reverted;
  });

  it('should fail if numberOfSlots > 2000', async function () {
    const { universeAuctionHouse } = await loadFixture(deployContract);
    const currentTime = Math.round((new Date()).getTime() / 1000);

    const startTime = currentTime + 100;
    const endTime = startTime + 100;
    const resetTimer = 3;
    const numberOfSlots = 2001;
    const bidToken = '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2';
    const whitelistAddresses = [];
    const minimumReserveValues = [];
    const paymentSplits = [];
    await expect(
      universeAuctionHouse.createAuction([
        startTime,
        endTime,
        resetTimer,
        numberOfSlots,
        bidToken,
        whitelistAddresses,
        minimumReserveValues,
        paymentSplits
      ])
    ).to.be.reverted;
  });

  it('should create auction successfully and set totalAuctions to 1', async () => {
    const { universeAuctionHouse } = await loadFixture(deployContract);
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
  });
});
