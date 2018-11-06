## TBN Smart Contracts

### Prerequisite

Nodejs v8+

NPM v6+

### Installation

1. Install Ganache (this step is unnecessary if you connect web3 to a live testnet or mainnet)

To install Ganache visit [the Ganache website](https://truffleframework.com/ganache).


2. Install truffle

```
npm i truffle -g
```

Node: If your truffle version is less then v4.1.14, you need to manually [update solidity to v0.4.25.](https://www.google.com)

```
cd /usr/local/lib/node_modules/truffle
npm install solc@0.4.25
```


3. Install all dependencies

Navigate your terminal to the root directory  and run the following:
```
npm i
```

4. Create an Ethereum account (keypair and keystore) and place the keystore file

You can use the keythereum npm module to create Ethereum accounts (or any other way you'd like)

Navigate to the /keystore directory and place your account keystore file here 

5. Setup the environment

In a terminal navigate to the root directory and create an .env file
```
touch .env
```

Choose your favorite txt editor and edit the .env file with the following
```
ADDRESS = <your account address form step 4>
PASSWORD = <the password you used to encrypt the account keystore file from step 4>
```
4. Setup Ganache

In a terminal navigate to  the /scripts subdirectory and run the setup.js script
```
node setup.js
```

#### setup.js

setup.js calls the ganache-cli to start a ganache instance and imports your newly created account for usage as a deployer and transaction creator


5. Compile, deploy and test smart contracts

```
truffle compile --all
truffle migrate --network ganache
```

#### Compile

Compiles all contracts an places ther build files in /build/contracts. You can find the ABI for each contract inside of it build file as an "abi" object. For interaction you will only nee dthe interface ABIs, e.g. IERC20, IPresale, and ICrowdsale.

#### Deploy

The deploy process will create a newly deployed TBNERC20.sol, Presale.sol, and Crowdfund.sol instances.
It will then update the .env file with the newly deployed addresses for these contracts in preparation for running contract specific scripts.

### Scripts

Example scripts for interaction can be found in the /script directory and a description of these scripts can be found [here](https://github.com/tubiex/smart-contracts/tree/master/scripts/README.md).

### License

All smart contracts and supplimentary code are released under [MIT](https://github.com/tubiex/smart-contracts/LICENSE).