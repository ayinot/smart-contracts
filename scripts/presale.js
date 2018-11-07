require('dotenv').config();
const address = process.env.address;  // the address of the transaction sending account
const password = process.env.password; //  the password of the transaction sending account

const presaleABI = require("../ABI/presale/IPresale.json");
const presaleDeployment = process.env.presale;

const transact = require("./transact.js");
const presaleContract = build.getContractObject(presaleABI, presaleDeployment);


/** 
* Contract Getters
*/

/**
* @dev getPresaleAllocation function gets the amount of tokens allocated to this presale contract
* @dev calls function getPresaleAllocation() external view returns (uint256);
* @returns {*Promise} allocation [a promisified BigNumber of a uint256]
*/
const getPresaleAllocation = () => {
    return new Promise((resolve, reject) => {
        try{
            presaleContract.methods.getPresaleAllocation().call().then(function(allocation) {
                resolve(allocation);
            });
        } catch (e) {
            console.log(e);
            reject(e);
        } 
    });
}

/**
* @dev totalPresaleSupply function gets the remaining token supply not yet assigned to user accounts
* @dev calls function totalPresaleSupply() external view returns (uint256);
* @returns {*Promise} supply [a promisified BigNumber of a uint256]
*/
const totalPresaleSupply = () => {
    return new Promise((resolve, reject) => {
        try{
            presaleContract.methods.totalPresaleSupply().call().then(function(supply) {
                resolve(supply);
            });
        } catch (e) {
            console.log(e);
            reject(e);
        } 
    });
}

/**
* @dev getPresaleDistribution function gets the total number of presale tokens distributed to presale accounts
* @dev calls function getPresaleDistribution() external view returns (uint256);
* @returns {*Promise} supply [a promisified BigNumber of a uint256]
*/
const getPresaleDistribution = () => {
    return new Promise((resolve, reject) => {
        try{
            presaleContract.methods.getPresaleDistribution().call().then(function(supply) {
                resolve(supply);
            });
        } catch (e) {
            console.log(e);
            reject(e);
        } 
    });
}

/**
* @dev presaleBalanceOf function gets an account's current presale token balance
* @dev calls function presaleBalanceOf(address account) external view returns (uint256);
* @param {*String} account [the account to get presaleBalance for]
* @returns {*Promise} presaleBalance [a promisified BigNumber of a uint256]
*/
const presaleBalanceOf = (account) => {
    return new Promise((resolve, reject) => {
        try{
            presaleContract.methods.presaleBalanceOf(account).call().then(function(presaleBalance) {
                resolve(presaleBalance);
            });
        } catch (e) {
            console.log(e);
            reject(e);
        } 
    });
}

/**
* @dev getERC20 function gets the ERC20 token deployment this presale contract is attached to (the TBN token ERC20 deployment)
* @dev calls function getERC20() external view returns (address);
* @returns {*Promise} tokenAddress [a promisified address string]
*/
const getERC20 = () => {
    return new Promise((resolve, reject) => {
        try{
            presaleContract.methods.getERC20().call().then(function(tokenAddress) {
                resolve(tokenAddress);
            });
        } catch (e) {
            console.log(e);
            reject(e);
        } 
    });
}

/**
* @dev getCrowdsale function gets the TBN Crowdsale contract deployment this presale contract is attached to (the TBN Crowdsale deployment)
* @dev calls function getCrowdsale() external view returns (address);
* @returns {*Promise} tokenAddress [a promisified address string]
*/
const getCrowdsale = () => {
    return new Promise((resolve, reject) => {
        try{
            presaleContract.methods.getCrowdsale().call().then(function(tokenAddress) {
                resolve(tokenAddress);
            });
        } catch (e) {
            console.log(e);
            reject(e);
        } 
    });
}


/*** PresaleDeployed Stage functions ***/ 

/** 
* Manager Role Functionality
*/ 

/**
* @dev initilize function allows the contract Manager to start the presale stage and accept and confirm the presale allocation of tokens
* @dev Note: will be reverted if called outside of Stages.PresaleDeployed
* @dev calls function initilize (uint256 presaleAllocation) external  returns (bool);
* @param {*String} manager [a pre-approved manager account of this contract, the transaction sending account, msg.sender]
* @param {*String} presaleAllocation [the pre-approved amount of tokens allocated to this presale contract, allocation uses the approve/transferFrom pattern of ERC20]
* @returns {*Promise} txHash [a promisified txHash string]
*/
const initilize = (manager, presaleAllocation) => {
    return new Promise((resolve, reject) => {
        presaleContract.methods.initilize(presaleAllocation).encodeABI()
        .then(function(data){
            transact.buildTransaction(manager, presaleDeployment, "0x", data, 15000)
            .then(function(tx){
                transact.signTx(manager,tx)
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
* @dev addPresaleBalance function for the contract Manager to distribute presale tokens to accounts (presale tokens can be traded freely until the Presale Stage ends, after which an account's presale balance is becomes part of their actual token amount under vesting)
* @dev Note: will be reverted if called outside of Stages.Presale
* @dev calls function addPresaleBalance(address[] presaleAccounts, uint256[] values) external returns (bool);
* @param {*Address} manager [a pre-approved manager account of this contract, the transaction sending account, msg.sender]
* @param {*Array Address} presaleAccounts [the accounts to distribute presale tokens]
* @param {*Array uint256} values [the corrolary values to distribute to these accounts]
* @returns {*Promise} txHash [a promisified txHash string]
*/
const addPresaleBalance = (manager, presaleAccounts, values) => {
    return new Promise((resolve, reject) => {
        presaleContract.methods.addPresaleBalance(presaleAccounts, values).encodeABI()
        .then(function(data){
            transact.buildTransaction(manager, presaleDeployment, "0x", data, 15000)
            .then(function(tx){
                transact.signTx(manager,tx)
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
* @dev subPresaleBalance function for the contract Manager to subtract presale tokens from accounts 
* @dev Note: will be reverted if called outside of Stages.Presale
* @dev calls function subPresaleBalance(address[] presaleAccounts, uint256[] values) external returns (bool);
* @param {*Address} manager [a pre-approved manager account of this contract, the transaction sending account, msg.sender]
* @param {*Array Address} presaleAccounts [the accounts to subtract presale tokens from]
* @param {*Array uint256} values [the corrolary values to subtract from these accounts]
* @returns {*Promise} txHash [a promisified txHash string]
*/
const subPresaleBalance = (manager, presaleAccounts, values) => {
    return new Promise((resolve, reject) => {
        presaleContract.methods.subPresaleBalance(presaleAccounts, values).encodeABI()
        .then(function(data){
            transact.buildTransaction(manager, presaleDeployment, "0x", data, 15000)
            .then(function(tx){
                transact.signTx(manager,tx)
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
* @dev presaleTransfer function allows an account to transfer presale tokens to another account
* @dev Note: will be reverted if called outside of Stages.Presale
* @dev calls function presaleTransfer(address from, address to, uint256 value) external returns (bool);
* @param {*Address} manager [a pre-approved manager account of this contract, the transaction sending account, msg.sender]
* @param {*String} from [the account to transfer from, the transaction sending account, msg.sender]
* @param {*String} to [the account to transfer presale tokens to]
* @param {*String|BigNumber} amount [the amount of tokens to transfer]
* @returns {*Promise} txHash [a promisified txHash string]
*/
const presaleTransfer = (manager, from, to, amount) => {
    return new Promise((resolve, reject) => {
        presaleContract.methods.presaleTransfer(from, to, amount).encodeABI()
        .then(function(data){
            transact.buildTransaction(manager, presaleDeployment, "0x", data, 15000)
            .then(function(tx){
                transact.signTx(manager,tx)
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
* @dev setCrowdsale function sets the Crowdsale address of the deployed crowdsale address to attach to this presale contract
* @dev Note: will be reverted if called outside of Stages.Presale
* @dev calls function setCrowdsale(ICrowdsale TBNCrowdsale) external returns (bool);
* @param {*String} manager [a pre-approved manager account of this contract, the transaction sending account, msg.sender]
* @param {*String/Address} TBNCrowdsale [the address of the deployed TBN Crowdsale contract]
* @returns {*Promise} txHash [a promisified txHash string]
*/
const setCrowdsale = (manager, TBNCrowdsale) => {
    return new Promise((resolve, reject) => {
        presaleContract.methods.setCrowdsale(TBNCrowdsale).encodeABI()
        .then(function(data){
            transact.buildTransaction(manager, presaleDeployment, "", data, 15000)
            .then(function(tx){
                transact.signTx(manager,tx)
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
* Recoverer Role Functionality
*/

/**
* @dev recoverTokens function for the contract Recoverer to recover missent ERC20 tokens
* @dev Note: will be reverted if called outside of Stages.Vesting
* @dev calls function recoverTokens(IERC20 token) external returns (bool);
* @param {*Address} recoverer [a pre-approved recover account of this contract, the transaction sending account, msg.sender]
* @param {*Address} token [the address of the ERC20 tokens to recover]
* @returns {*Promise} txHash [a promisified txHash string]
*/
//
const recoverTokens = (recoverer, accounts, to) => {
    return new Promise((resolve, reject) => {
        presaleContract.methods.recoverTokens(token).encodeABI()
        .then(function(data){
            transact.buildTransaction(recoverer, presaleDeployment, "0x", data, 15000)
            .then(function(tx){
                transact.signTx(manager,tx)
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