require('dotenv').config();
const ganache = require("ganache-cli");
const Web3 = require('web3');
const BigNumber = require('bignumber.js');
const transact = require('./transact.js');
const address = process.env.address;
const password = process.env.password;
const startETH = new BigNumber("1000000000000000000000000");
const value = Web3.utils.stringToHex(startETH.toString());

transact.getPrivateKey(address, './', password)
.then(function(privKey){
    const options = {
        accounts: [
            {
                secretKey: privKey,
                balance: value
            }
        ]
    }
    const instance = new Web3(ganache.provider(options)); // uses Ganache for local testing and import our keystore account
    return instance;
});