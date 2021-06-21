const { deployments, hardhatArguments } = require("hardhat");

module.exports = async function () {
  if (
    hardhatArguments.network === "ganache" ||
    hardhatArguments.network === "hardhat" ||
    hardhatArguments.network === "rinkeby"
  ) {
    const namedAccounts = await hre.getNamedAccounts();
    const Factory = await deployments.getOrNull("AuctionFactory");
    const { log } = deployments;
    const UniverseERC721Core = await deployments.getOrNull('UniverseERC721Core');

    if (!Factory) {
      const MAX_SLOT = 40;
      // We get the contract to deploy
      const auctionFactoryDeployment = await deployments.deploy("AuctionFactory", {
        from: namedAccounts.deployer,
        args: [MAX_SLOT],
      });
      console.log("AuctionFactory deployed to:", auctionFactoryDeployment.address);

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
      log("AuctionFactory already deployed");
    }

    if (!UniverseERC721Core) {
      const universeERC721CoreDeployment = await deployments.deploy("UniverseERC721Core", {
        from: namedAccounts.deployer,
        args: ["Non Fungible Universe Core", "NFUC"],
      });
      console.log("UniverseERC721Core deployed to:", universeERC721CoreDeployment.address);
    } else {
      log("UniverseERC721Core already deployed");
    }
  }
};

module.exports.tags = ["ActionFactory"];
