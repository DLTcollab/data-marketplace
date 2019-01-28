var Marketplace = artifacts.require("Marketplace");

module.exports = async function(deployer, network, accounts) {
  deployer.deploy(Marketplace);
};
