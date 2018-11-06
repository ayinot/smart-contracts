## TBN ERC20 Contract
A standard ERC20 token contract based on the Openzeppelin standard which mints the intial token supply and then revokes Minter access during deployment. Also includes safety functions for ETH payments and recovery of missent tokens and the addition of a Fundkeeper role which controls the intial token supply and acts as issuer. More information about the Fundkeeper Role can be found [here](https://github.com/tubiex/smart-contracts/tree/master/contracts/access/roles/README.md).

### Deployment
1. To compile properly, you must have solc version 0.4.24 or later.
```
npm install -g solc@0.4.24
```

2. Deploy from TBNERC20.sol, must include the totalSupply, name, symbol, and decimal parameters. Contract creator will be set a the Minter, Recoverer, and Fundkeepers Roles. After tokenSupply is minted, the Minter role will be revoked and minting can never occur afterwards. It is suggested to add additional Recoverer permissions and transfer the Fundkeeper role to a multisig account.

3. After deployment the contract instance address will be used to link both the Presale.sol and Crowdsale.sol deployments securely.

### ERC20
ERC-20 defines a common list of rules for Ethereum smart contract based tokens to follow within the larger Ethereum ecosystem, allowing developers to accurately predict interaction between tokens. These rules include how the tokens are transferred between addresses and how data within each token is accessed

The ERC-20 token has the following method-related functions:

The specific wording of the function is followed by a clarification of what it does, `[in brackets]`
```
totalSupply() public view returns (uint256 totalSupply) [Get the total token supply]
balanceOf(address _owner) public view returns (uint256 balance) [Get the account balance of another account with address _owner]
transfer(address _to, uint256 _value) public returns (bool success) [Send _value amount of tokens to address _to]
transferFrom(address _from, address _to, uint256 _value) public returns (bool success)[Send _value amount of tokens from address _from to address _to]
approve(address _spender, uint256 _value) public returns (bool success) [Allow _spender to withdraw from your account, multiple times, up to the _value amount. If this function is called again it overwrites the current allowance with _value]
allowance(address _owner, address _spender) public view returns (uint256 remaining) [Returns the amount which _spender is still allowed to withdraw from _owner]
Events format:

Transfer(address indexed _from, address indexed _to, uint256 _value). [Triggered when tokens are transferred.]
Approval(address indexed _owner, address indexed _spender, uint256 _value)[Triggered whenever approve(address _spender, uint256 _value) is called.]
```

### Interaction

#### Interface
The interface for the ERC20 functionality can be found [here](https://github.com/tubiex/smart-contracts/blob/master/contracts/ERC20/IERC20.sol).

#### ABI
We have provided up-to-date ABIs for the TBNERC20 contract [here](https://github.com/tubiex/smart-contracts/blob/master/ABI/ERC20/IERC20.json).

#### Scripts
You can also find sample scripts for calling these functions [here](https://github.com/tubiex/smart-contracts/tree/master/scripts/README.md).

### Solidity Dependencies

For standard smart contracts like SafeMath, and the Roles design pattern we use OpenZeppelin's library for secure implementation.

[![NPM Version][npm-image]][npm-url]

### License

All smart contracts and supplimentary code are released under [MIT](https://github.com/tubiex/smart-contracts/LICENSE).

[npm-image]: https://img.shields.io/npm/v/openzeppelin-solidity.svg
[npm-url]: https://www.npmjs.com/package/openzeppelin-solidity
