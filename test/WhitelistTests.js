const { expect } = require('chai');
const { waffle } = require('hardhat');
const { loadFixture } = waffle;


describe('Whitelist functionality', () => {
  const deployContracts = async() => {
    const [AuctionFactory, MockNFT] = await Promise.all([
      ethers.getContractFactory('AuctionFactory'),
      ethers.getContractFactory('MockNFT')
    ])

    const [auctionFactory, mockNft] = await Promise.all([AuctionFactory.deploy(), MockNFT.deploy()]);

    return {auctionFactory, mockNft};
  }

  it('should add to whitelist successfully', async () => {
    const {auctionFactory, mockNft} = await loadFixture(deployContracts);

    await createAuction(auctionFactory)

    const [addr1] = await ethers.getSigners();

    await auctionFactory.whitelistAddress(1, addr1.address);
  
    await mockNft.mint(addr1.address, "tokenURI")
    await mockNft.approve(auctionFactory.address, 1);

    await expect(auctionFactory.depositERC721(1, 1, 1, mockNft.address))
      .to.be.emit(auctionFactory, 'LogERC721Deposit');
  });

  it('should revert when address which is not whitelisted is trying to deposit', async () => {
    const {auctionFactory, mockNft} = await loadFixture(deployContracts);

    await createAuction(auctionFactory)

    await auctionFactory.whitelistAddress(1, '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2');
  
    await expect(depositNFT(auctionFactory, mockNft)).to.be.reverted;
  })

  it('should whitelist multiple addresses', async () => {
    const {auctionFactory, mockNft} = await loadFixture(deployContracts);

    await createAuction(auctionFactory);

    const [addr1, addr2] = await ethers.getSigners();

    await auctionFactory.whitelistMultipleAddresses(1, [
      addr1.address,
      addr2.address
    ]);
  
    const auctionId = 1;
    const slotIdx = 1;
    const tokenId = 1;
    
    await mockNft.connect(addr1).mint(addr1.address, 'testNft')
    await mockNft.connect(addr1).approve(auctionFactory.address, 1);

    await expect(auctionFactory.connect(addr1).depositERC721(auctionId, slotIdx, tokenId, mockNft.address))
      .to.be.emit(auctionFactory, 'LogERC721Deposit');
 
    await mockNft.connect(addr2).mint(addr2.address, 'testNft2')
    await mockNft.connect(addr2).approve(auctionFactory.address, 2);

    await expect(auctionFactory.connect(addr2).depositERC721(auctionId, slotIdx, 2, mockNft.address))
      .to.be.emit(auctionFactory, 'LogERC721Deposit');
  });
})

const createAuction = async (auctionFactory) => {
  const blockNumber = await ethers.provider.getBlockNumber();

  const startBlockNumber = blockNumber + 10;
  const endBlockNumber = blockNumber + 15;
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
};

const depositNFT = async (auctionFactory, mockNFT) => {
  const [owner] = await ethers.getSigners();

  const auctionId = 1;
  const slotIdx = 0;
  const tokenId = 1;

  await mockNFT.mint(owner.address, 'nftURI');
  await mockNFT.approve(auctionFactory.address, tokenId);

  await auctionFactory.depositERC721(auctionId, slotIdx, tokenId, mockNFT.address);
};
