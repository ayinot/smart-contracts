const Migrations = artifacts.require("./Migrations.sol");
const TBNERC20 = artifacts.require("./ERC20/TBNERC20.sol");
const Presale = artifacts.require("./presale/Presale.sol");
const Crowdsale = artifacts.require("./presale/TBNCrowdsale.sol");

module.exports = function(deployer) {
  deployer.deploy(TBNERC20, 380000000000000000000000000, "Tubiex Network Token", "TBN", 18)
  .then(function() {
    deployer.deploy(Presale, TBNERC20.address)
    .then(function() {
      return deployer.deploy(Crowdsale, TBNERC20.address. Presale.address, 188, "0xc4dda28c5c1caa3c6cbbf1f29b9c6211ba3712deb2755442e5d37591cc55b60f");
    });
  });
}

