var Web3 = require('web3');
const fs = require('fs');
const keythereum = require("keythereum");
const Tx = require('ethereumjs-tx');
const BigNumber = require('bignumber.js');
const solc = require('solc');
const host = require("../truffle.js").networks.ganache.host;
const port = require("../truffle.js").networks.ganache.port;
const web3 = new Web3(new Web3.providers.HttpProvider(host+":"+port));

const dataDir = "./"; // this points to /scripts/keystore... you should put the signing account's keystore in that folder

//Custom Error message
const NOT_ENOUGH_ETHER = "Account doesn't have enough ether to make this transaction";

/**
* @dev buildTransaction function builds a transaction for the Ethereum network
* @param {*String} from [the signer and sender of the transaction]
* @param {*String} to [the account or contract recieving the transaction]
* @param {*String} data payload of the transaction in hex string format]
* @param {*String} gas_buffer extra gas to assign to ther transaction to ensure processing]
* @returns {*Promise} a promisified raw transaction object to sign and send to the network
*/
const buildTransaction = (from, to, value, data, gas_buffer) => {
    return new Promise((resolve, reject) => {
        const gasBuffer = new BigNumber(gas_buffer);
        try {
            const gasObj = {
                to: to,
                from: from,
                data: data
            };
    
            try {
                const nonce = getNonce(from);

                const gasPrice = getGasPrice();
                gasPrice = new BigNumber(gasPrice);

                const gasEstimate = estimateGas(gasObj);
                gasEstimate = new BigNumber(gasEstimate);
                gasEstimate = gasEstimate.plus(gasBuffer);

                const balance = getBalance(from);
                balance = new BigNumber(balance);

                if (balance.isLessThan(gasEstimate.times(gasPrice))) {
                    reject(NOT_ENOUGH_ETHER);
                } else {
                    const tx = new Tx({
                        to: to,
                        nonce: nonce,
                        value: value,
                        gasPrice: web3.utils.toHex(gasPrice.toString()),
                        gasLimit: web3.utils.toHex(gasEstimate).toString(),
                        data: data
                    });
                    resolve(tx);
                }
            } catch (e) {
                console.log(e);
                reject(e);
            }
        } catch (e) {
            console.log(e);
            reject(e);
        }
    });
}

const signTx = (msgSender, tx) => {
    return new Promise((resolve, reject) => {
        const senderAddressForKeystore = msgSender.slice(2); // without the initial '0x'
        try{
            getPrivateKey(senderAddressForKeystore, dataDir, senderPassword)
            .then(function(privateKey){
                resolve(tx.sign(privateKey));
            });
        } catch (e) {
            console.log(e);
            reject(e);
        } 
    });
}

const sendSignedTx = (tx) => {
    return new Promise((resolve, reject) => {
        try{
            web3.eth.sendSignedTransaction('0x' + tx.serialize().toString('hex'))
            .on('transactionHash', function (hash) {
                console.log("transaction hash: " + hash);
                resolve(hash);
            })                
            .on('receipt', function (receipt) {
                console.log("receipt: " + receipt);
            })
            .on('error', function (error) {
                try {
                    console.log(error);
                    var data = error.message.split(':\n', 2);
                    if (data.length == 2) {
                        var transaction = JSON.parse(data[1]);
                        transaction.messesge = data[0];
                        console.log(transaction);
                    }
                    reject(error);
                } catch (e) {
                    reject(e);
                }
            });
        } catch (e) {
            console.log(e);
            reject(e);
        } 
    });
}

const getPrivateKey = (account, datadir, password) => {
    return new Promise((resolve, reject) => {
        try{
            keythereum.importFromFile(account, datadir, password)
            .then(function(keyObject){
                const privateKey = keythereum.recover(_password, keyObject);
                resolve('0x'+privateKey.toString('hex'));
            });
        } catch (e) {
            console.log(e);
            reject(e);
        } 
    });
}

const getNonce = (account) => {
    return new Promise((resolve, reject) => {
        try{
            web3.eth.getTransactionCount(account).then(function(nonce) {
                resolve(nonce);
            });
        } catch (e) {
            console.log(e);
            reject(e);
        } 
    });
}

const getGasPrice = () => {
    return new Promise((resolve, reject) => {
        try{
            web3.eth.getGasPrice().then(function(price) {
                resolve(price);
            });
        } catch (e) {
            console.log(e);
            reject(e);
        } 
    });
}

const estimateGas = (gasObj) => {
    return new Promise((resolve, reject) => {
        try{
            web3.eth.estimateGas({gasObj}).then(function(estimate) {
                resolve(estimate);
            });
        } catch (e) {
            console.log(e);
            reject(e);
        } 
    });
}

const getBalance = (account) => {
    return new Promise((resolve, reject) => {
        try{
            web3.eth.getBalance(account).then(function(balance) {
                resolve(balance);
            });
        } catch (e) {
            console.log(e);
            reject(e);
        } 
    });
}

const getContractObject = (abi, deployedAddress) => {
    return new Promise((resolve, reject) => {
        try{
            const obj = new web3.eth.Contract(abi, deployedAddress);
            resolve(obj);
        } catch (e) {
            console.log(e);
            reject(e);
        } 
    });
}


module.exports = { 
    buildTransaction: buildTransaction,
    signTx: signTx,
    sendSignedTx: sendSignedTx,
    getPrivateKey: getPrivateKey,
    getNonce: getNonce,
    getGasPrice: getGasPrice,
    estimateGas: estimateGas,
    getBalance: getBalance,
    getContractObject: getContractObject
}