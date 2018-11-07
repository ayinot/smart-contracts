require('dotenv').config();
const address = process.env.address;  // the address of the transaction sending account
const password = process.env.password; //  the password of the transaction sending account

const erc20ABI = require("../ABI/presale/IPresale.json");
const erc20Deployment = process.env.tbnerc20;

const transact = require("./transact.js");
const erc20Contract = build.getContractObject(erc20ABI, erc20Deployment);


/** 
* Contract Getters
*/

/**
* @dev totalSupply function gets the total amount of tokens minted by this contract
* @dev calls function totalSupply() public view returns (uint256);
* @returns {*Promise} allocation [a promisified BigNumber of a uint256]
*/
const totalSupply = () => {
    return new Promise((resolve, reject) => {
        try{
            erc20Contract.methods.totalSupply().call().then(function(supply) {
                resolve(supply);
            });
        } catch (e) {
            console.log(e);
            reject(e);
        } 
    });
}

/**
* @dev balanceOf function gets the amount of tokens held in an account
* @dev calls function balanceOf(address who) public view returns (uint256);
* @param account the account to check the balance of
* @returns {*Promise} allocation [a promisified BigNumber of a uint256]
*/
const balanceOf = (account) => {
    return new Promise((resolve, reject) => {
        try{
            erc20Contract.methods.balanceOf(account).call().then(function(balance) {
                resolve(balance);
            });
        } catch (e) {
            console.log(e);
            reject(e);
        } 
    });
}

/**
* @dev allowance function gets the amount of tokens owner has allowed spender to spend
* @dev calls function allowance(address owner, address spender) public view returns (uint256);
* @returns {*Promise} allocation [a promisified BigNumber of a uint256]
*/
const allowance = (owner, spender) => {
    return new Promise((resolve, reject) => {
        try{
            erc20Contract.methods.allowance(owner, spender).call().then(function(amount) {
                resolve(amount);
            });
        } catch (e) {
            console.log(e);
            reject(e);
        } 
    });
}


/**
* @dev transfer function allows an account to transfer tokens to another account
* @dev calls function function transfer(address to, uint256 value) public returns (bool);
* @param from [the account to transfer from, the transaction sending account, msg.sender]
* @param {*String} to [the account to transfer tokens to]
* @param {*String|BigNumber} amount [the amount of tokens to transfer]
* @returns {*Promise} txHash [a promisified txHash string]
*/
const transfer = (from, to, amount) => {
    return new Promise((resolve, reject) => {
        erc20Contract.methods.transfer(to, amount).encodeABI()
        .then(function(data){
            transact.buildTransaction(from, erc20Deployment, "0x", data, 15000)
            .then(function(tx){
                transact.signTx(from,tx)
                .then(function(signed){
                    transact.sendSignedTx(signed)
                    .then(function(receipt){
                        console.log("receipt: " + receipt);
                        resolve(receipt);
                    });
                });
            });
        })
        .catch(function(e){
            console.log(e);
            reject(e);
        });
    });
}

/**
* @dev approve function allows an account to transfer tokens to another account
* @dev calls function approve(address spender, uint256 value) public returns (bool);
* @param from [the account to transfer from, the transaction sending account, msg.sender]
* @param {*String} spender [the account to approve spending for]
* @param {*String|BigNumber} value [the amount of tokens to approve for the spender]
* @returns {*Promise} txHash [a promisified txHash string]
*/
const approve = (from, spender, value) => {
    return new Promise((resolve, reject) => {
        erc20Contract.methods.approve(spender, value).encodeABI()
        .then(function(data){
            transact.buildTransaction(from, erc20Deployment, "0x", data, 15000)
            .then(function(tx){
                transact.signTx(from,tx)
                .then(function(signed){
                    transact.sendSignedTx(signed)
                    .then(function(receipt){
                        console.log("receipt: " + receipt);
                        resolve(receipt);
                    });
                });
            });
        })
        .catch(function(e){
            console.log(e);
            reject(e);
        });
    });
}

/**
* @dev transferFrom function allows an account to transfer tokens to another account
* @dev calls function transferFrom(address from, address to, uint256 value) public returns (bool);
* @param {*String} spender [the approved spender, the transaction sending account, msg.sender]
* @param {*String} from [the account to transfer from, the owner account tha has approved the spender]
* @param {*String} to [the account to transfer tokens to]
* @param {*String|BigNumber} value [the amount of tokens to transfer]
* @returns {*Promise} txHash [a promisified txHash string]
*/
const transferFrom = (spender, from, to, value) => {
    return new Promise((resolve, reject) => {
        erc20Contract.methods.transferFrom(from, to, value).encodeABI()
        .then(function(data){
            transact.buildTransaction(spender, erc20Deployment, "0x", data, 15000)
            .then(function(tx){
                transact.signTx(from,tx)
                .then(function(signed){
                    transact.sendSignedTx(signed)
                    .then(function(receipt){
                        console.log("receipt: " + receipt);
                        resolve(receipt);
                    });
                });
            });
        })
        .catch(function(e){
            console.log(e);
            reject(e);
        });
    });
}