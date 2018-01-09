var Migrations = artifacts.require("./Migrations.sol");
var CoderCoin = artifacts.require("./CoderCoin.sol");
var CoderCrowdsale = artifacts.require("./CoderCrowdsale.sol");
var oraclizeAPI_mod = artifacts.require("./oraclizeAPI_mod.sol");

module.exports = function(deployer) {
  deployer.deploy(Migrations);
};

module.exports = function(deployer) {
  deployer.deploy(CoderCoin);
};

module.exports = function(deployer) {
  deployer.deploy(CoderCrowdsale);
};

module.exports = function(deployer) {
  deployer.deploy(oraclizeAPI_mod);
};


