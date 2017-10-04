var Migrations = artifacts.require("./Migrations.sol");
var NigamCoin = artifacts.require("./NigamCoin.sol");
var NigamCrowdsale = artifacts.require("./NigamCrowdsale.sol");
var oraclizeAPI_mod = artifacts.require("./oraclizeAPI_mod.sol");

module.exports = function(deployer) {
  deployer.deploy(Migrations);
};

module.exports = function(deployer) {
  deployer.deploy(NigamCoin);
};

module.exports = function(deployer) {
  deployer.deploy(NigamCrowdsale);
};

module.exports = function(deployer) {
  deployer.deploy(oraclizeAPI_mod);
};


