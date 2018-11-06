var Migrations = artifacts.require("./Migrations.sol");

module.exports = function(deployer) {
  deployer.deploy(A).then(function() {
    return deployer.deploy(B, A.address);
  });
};
