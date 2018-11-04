## TBN Presale Contract

A smart contract to record Pre-sale TBN token balances for later distribution during the Crowdsale. It offers the contract Manager presale balance manipulation funtionality before the Crowdsale is initialized. Once the Crowdsale has started the pre-sale records are locked and the total recorded allocation of TBN tokens is transferred to the Crowdsale contract for distribution during claiming.

### Deployment
1. To compile properly, you must have solc version 0.4.25 or later.
```
npm install -g solc@0.4.25
```

2. Must have first delpoyed TBNERC20.sol as a contract and aquired the address of that deployment to pass to the Presale.sol constructor.

3. After deployment the contract is set to the PresaleDeployed Stage awaiting intialization.

### Initialization
Initalization can only be done from a contract Manager account. This will either be the account which created this Presale contract or another account added by the contract creator to be a Manager. 

For granting and revoking Role permissions [see here](https://github.com/tubiex/smart-contracts/tree/master/contracts/access/roles/README.md).

Initializing starts the Presale Stage during which pre-sale account records can be created and updated.

Calling initialize(presaleAllocation) requires that the TBNERC20 Fundkeeper of the attached TBNECR20 contract has first approved this Presale contract for the amount of presaleAllocation.

To approve this contract for TBN tokens [see the ERC20 README.md](https://github.com/tubiex/smart-contracts/tree/master/contracts/ERC20/README.md)

### Presale
The Manger Role has several functionalities to adjust records and there are several public getters to gather information from the contract: the interface for all Presale interaction is defined [here](https://github.com/tubiex/smart-contracts/blob/master/contracts/presale/IPresale.sol).

You can also find sample scripts for calling these functions [here](https://github.com/tubiex/smart-contracts/tree/master/scripts/README.md).

### Presale End
The Presale record updating functionality will be locked once the Crowdsale is initialized.

As a prerequisite for Crowdsale initialization, the crowdsale deployment address must first be set in this Presale contract.

### Solidity Dependencies

For standard smart contracts like SafeMath, and the Roles design pattern we use OpenZeppelin's library for secure implementation.

[![NPM Version][npm-image]][npm-url]

### License

All smart contracts are released under [MIT](https://github.com/tubiex/smart-contracts/LICENSE).

[npm-image]: https://img.shields.io/npm/v/openzeppelin-solidity.svg
[npm-url]: https://www.npmjs.com/package/openzeppelin-solidity
