const { deployments, hardhatArguments } = require('hardhat');

module.exports = async function () {
    if (
        hardhatArguments.network === "ganache" ||
        hardhatArguments.network === "hardhat"
    ) { 
        const namedAccounts = await hre.getNamedAccounts();   
        const Factory = await deployments.getOrNull("AuctionFactory");
        const { log } = deployments;
        if (!Factory) {
            const MAX_SLOT = process.env.MAX_SLOT;
            // We get the contract to deploy
            const auctionFactoryDeployment = await deployments.deploy("AuctionFactory",{
                from: namedAccounts.deployer,
                args: [MAX_SLOT]
            }); 
            console.log("AuctionFactory deployed to:", auctionFactoryDeployment.address);
        } else {
            log("AuctionFactory already deployed");
        }
    }
};

module.exports.tags = ['ActionFactory'];