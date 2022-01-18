//const { deployments, hardhatArguments } = require("hardhat");
require('dotenv').config()

module.exports = async ({ getNamedAccounts, deployments, getChainId }) => {
  const { deploy, execute } = deployments;
  const { deployer, proxyAdmin } = await getNamedAccounts();
  if (
    hardhatArguments.network === "ganache" ||
    hardhatArguments.network === "hardhat" ||
    hardhatArguments.network === "rinkeby" ||
    hardhatArguments.network === "ropsten" ||
    hardhatArguments.network === "mainnet"
  ) {
    const { log } = deployments;
    const namedAccounts = await hre.getNamedAccounts();
    const Factory = await deployments.getOrNull("UniverseAuctionHouse");
    const UniverseERC721Core = await deployments.getOrNull('UniverseERC721Core');

    if (!Factory) {
      const MAX_SLOT = process.env.MAX_SLOT;
      const MAX_NFTS_PER_SLOT = process.env.MAX_NFTS_PER_SLOT;
      const ROYALTY_FEE_BPS = process.env.ROYALTY_FEE_BPS;
      const DAO_ADDRESS = process.env.DAO_ADDRESS;
      const SUPPORTED_BID_TOKENS = process.env.SUPPORTED_BID_TOKENS.split(",");
      const ROYALTIES_REGISTRY = process.env.ROYALTIES_REGISTRY;

      const universeAuctionHouseDeployment = await deploy("UniverseAuctionHouse", {
        from: deployer,
        log: true,
        proxy: {
          owner: proxyAdmin,
          proxyContract: "OpenZeppelinTransparentProxy",
          execute: {
            methodName: "__UniverseAuctionHouse_init",
            args: [MAX_SLOT, MAX_NFTS_PER_SLOT, ROYALTY_FEE_BPS, DAO_ADDRESS, SUPPORTED_BID_TOKENS, ROYALTIES_REGISTRY],
          },
        },
      });
      console.log("UniverseAuctionHouse deployed to:", universeAuctionHouseDeployment.address);

      const universeERC721FactoryDeployment = await deployments.deploy("UniverseERC721Factory", {
        from: namedAccounts.deployer,
        args: [],
      });
      console.log("UniverseERC721Factory deployed to:", universeERC721FactoryDeployment.address);

      const universeERC721Deployment = await deployments.deploy("UniverseERC721", {
        from: namedAccounts.deployer,
        args: ["Non Fungible Universe", "NFU"],
      });
      console.log("UniverseERC721 deployed to:", universeERC721Deployment.address);
    } else {
      log("UniverseAuctionHouse already deployed");
    }

    if (!UniverseERC721Core) {
      const universeERC721CoreDeployment = await deployments.deploy("UniverseERC721Core", {
        from: namedAccounts.deployer,
        args: ["Universe Singularity Collection", "USC"],
      });
      console.log("UniverseERC721Core deployed to:", universeERC721CoreDeployment.address);
    } else {
      log("UniverseERC721Core already deployed");
    }
  }
};

module.exports.tags = ["ActionFactory"];
