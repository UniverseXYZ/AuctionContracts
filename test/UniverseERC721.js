const { expect } = require('chai');
const { waffle, upgrades } = require('hardhat');
const { loadFixture } = waffle;


describe('UniverseERC721', () => {
  const deployContracts = async () => {
    const [owner, addr1] = await ethers.getSigners();
    const UniverseAuctionHouse = await ethers.getContractFactory('UniverseAuctionHouse');

    const MockRoyaltiesRegistry =  await ethers.getContractFactory('MockRoyaltiesRegistry');
    const mockRoyaltiesRegistry = await MockRoyaltiesRegistry.deploy();

    const universeAuctionHouse = await UniverseAuctionHouse.deploy(2000, 100, 0, owner.address, [], mockRoyaltiesRegistry.address);

    const UniverseERC721 = await ethers.getContractFactory('UniverseERC721');
    const universeERC721 = await UniverseERC721.deploy("Non Fungible Universe", "NFU");

    const UniverseERC721Core = await ethers.getContractFactory('UniverseERC721Core');
    const universeERC721Core = await UniverseERC721Core.deploy("Non Fungible Universe Core", "NFUC");

    return { universeAuctionHouse, universeERC721, universeERC721Core };
  };

  it('should mint successfully', async () => {
    const { universeERC721, universeERC721Core } = await loadFixture(deployContracts);

    const [signer] = await ethers.getSigners();

    await universeERC721.mint(signer.address, 'TestURI', [["0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2", 1000]]);
    await universeERC721Core.mint(signer.address, 'TestURI', [["0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2", 1000]]);
  });

  it('should update tokenURI', async () => {
    const { universeERC721, universeERC721Core } = await loadFixture(deployContracts);

    const [signer] = await ethers.getSigners();

    await universeERC721.mint(signer.address, 'TestURI', [["0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2", 1000]]);
    await universeERC721Core.mint(signer.address, 'TestURI', [["0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2", 1000]]);

    await universeERC721.updateTokenURI(1, 'TestURI2');
    await universeERC721Core.updateTokenURI(1, 'TestURI2');
  });

  it('should revert with Ownable: caller is not the owner', async () => {
    const { universeERC721 } = await loadFixture(deployContracts);

    const [signer, signer2] = await ethers.getSigners();

    await universeERC721.mint(signer.address, 'TestURI', [["0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2", 1000]]);

    await expect(universeERC721.connect(signer2).updateTokenURI(1, 'TestURI2')).revertedWith(
      'Ownable: caller is not the owner'
    );
  });

  it('should revert with Ownable: caller is not the owner CORE', async () => {
    const { universeERC721Core } = await loadFixture(deployContracts);

    const [signer, signer2] = await ethers.getSigners();

    await universeERC721Core.mint(signer.address, 'TestURI', [["0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2", 1000]]);

    await expect(universeERC721Core.connect(signer2).updateTokenURI(1, 'TestURI2')).revertedWith(
      'Owner: Caller is not the owner of the Token'
    );
  });

  it('should batchMint successfully', async () => {
    const { universeERC721, universeERC721Core } = await loadFixture(deployContracts);

    const [signer] = await ethers.getSigners();

    await universeERC721.batchMint(signer.address, ['TestURI', 'TestURI2'], [["0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2", 1000]]);
    await universeERC721Core.batchMint(signer.address, ['TestURI', 'TestURI2'], [["0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2", 1000]]);
  });

  it('should revert with Cannot mint more than 40 ERC721 tokens in a single call', async () => {
    const { universeERC721, universeERC721Core } = await loadFixture(deployContracts);

    const [signer] = await ethers.getSigners();

    const uris = new Array(41).fill('asd');

    await expect(universeERC721.batchMint(signer.address, uris, [["0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2", 1000]])).revertedWith(
      'Cannot mint more than 40 ERC721 tokens in a single call'
    );

    await expect(universeERC721Core.batchMint(signer.address, uris, [["0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2", 1000]])).revertedWith(
      'Cannot mint more than 40 ERC721 tokens in a single call'
    );
  });
});
