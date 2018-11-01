var web3 = new Web3(new Web3.providers.HttpProvider('http://localhost:7545')); // uses Ganache for local testing 
const presaleABI = require("../ABI/presale/IPresale.json");
const presaleDeployment = "0xde0B295669a9FD93d5F28D9Ec85E40f4cb697BAe"; //just a test address on Ganache
const presaleContract = new web3.eth.Contract(presaleABI, presaleDeployment);

//Custom Error message
const NOT_ENOUGH_ETHER = "Account doesn't have enough ether to make this transaction";

/**
*  for web embedding use window.web3 instead of web3 module. this gives access to the MetaMask web3 object, MetaMask will handle the provider
* alternatively you can provide the contract address and ABI.json to users so they can access the functionality through https://www.myetherwallet.com/#contracts

const isMetaMaskEnabled = () => !!window.web3;

if (!isMetaMaskEnabled()) {
  alert('MetaMask is not enabled.');
  return;
}
*/

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
* @dev getPresaleAllocation function gets an account's static total vesting balance
* @dev Note: returns 0 until user has called the vest() function for the first time or manager has called approveVest() the first time
* @dev Note: will be reverted if called before stages has been set to Stages.Vesting
* @dev calls function getVestingBalance(address account) external view returns (uint256);
* @param {*String} account [the account to get vestingBalance for]
* @returns {*Promise} vestingBalance [a promisified BigNumber of a uint256]
*/
const getVestingBalance = (account) => {
    return new Promise((resolve, reject) => {
        try{
            presaleContract.methods.getVestingBalance(account).call().then(function(vestingBalance) {
                resolve(vestingBalance);
            });
        } catch (e) {
            console.log(e);
            reject(e);
        } 
    });
}

/**
* @dev getVestingPeriod function gets an account's vesting period (in blocks)
* @dev Note: returns 0 until user has called the vest() function for the first time or manager has called approveVest() the first time
* @dev Note: will be reverted if called before stages has been set to Stages.Vesting
* @dev calls function getVestingPeriod(address account) external view returns (uint256);
* @param {*String} account [the account to get vesting period for]
* @returns {*Promise} duration [a promisified BigNumber of a uint256]
*/
const getVestingPeriod = (account) => {
    return new Promise((resolve, reject) => {
        try{
            presaleContract.methods.getVestingPeriod(account).call().then(function(duration) {
                resolve(duration);
            });
        } catch (e) {
            console.log(e);
            reject(e);
        } 
    });
}

/**
* @dev getVestingSchedule function gets an account's vesting schedule 
* @dev Note: vest percentages are integers at 4 decimal precision e.g. 16.6667% = 166667
* @dev Note: will be reverted if called before stages has been set to Stages.Vesting
* @dev calls function getVestingSchedule(address account) external view returns (uint256, uint256, uint256);
* @param {*String} account [the account to get vesting schedule for]
* @returns {*Promise} schedule [a promisified tuple of (number of vesting months, initial vest percentage, monthly vest percentage)]
*/
const getVestingSchedule = (account) => {
    return new Promise((resolve, reject) => {
        try{
            presaleContract.methods.getVestingSchedule(account).call().then(function(schedule) {
                resolve(schedule);
            });
        } catch (e) {
            console.log(e);
            reject(e);
        } 
    });
}

/**
* @dev getVestedAmount function gets an account's total amount of tokens already vested and transferred out of this contract 
* @dev Note: will be reverted if called before stages has been set to Stages.Vesting
* @dev calls function getVestedAmount(address account) external view returns (uint256);
* @param {*String} account [the account to get vested amount for]
* @returns {*Promise} vested [a promisified BigNumber of a uint256]
*/
const getVestedAmount = (account) => {
    return new Promise((resolve, reject) => {
        try{
            presaleContract.methods.getVestedAmount(account).call().then(function(vested) {
                resolve(vested);
            });
        } catch (e) {
            console.log(e);
            reject(e);
        } 
    });
}

/**
* @dev getVestApproved function gets an account's vesting approval status (approval given by contract Manager or autmatically)
* @dev Note: will be reverted if called before stages has been set to Stages.Vesting
* @dev calls function getVestApproved(address account) external view returns (bool);
* @param {*String} account [the account to get vested amount for]
* @returns {*Promise} vestStatus [a promisified boolean]
*/
const getVestApproved = (account) => {
    return new Promise((resolve, reject) => {
        try{
            presaleContract.methods.getVestApproved(account).call().then(function(vestStatus) {
                resolve(vestStatus);
            });
        } catch (e) {
            console.log(e);
            reject(e);
        } 
    });
}

/**
* @dev getVestApproved function gets the ERC20 token deployment this presale contract is attached to (the TBN token ERC20 deployment)
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
* @dev readyToVest function gets the status of this contract to see if it has been set as ready to vest
* @dev Note: this is primarily for the Crowdsale contract to see if it can change this stage to Stages.Vesting
* @dev calls function readyToVest() external view returns (bool);
* @returns {*Promise} ready [a promisified boolean]
*/
const readyToVest = () => {
    return new Promise((resolve, reject) => {
        try{
            presaleContract.methods.readyToVest().call().then(function(ready) {
                resolve(ready);
            });
        } catch (e) {
            console.log(e);
            reject(e);
        } 
    });
}

/** 
* Account Based Functionality
*/

// Presale Stage functions
/**
* @dev presaleTransfer function allows an account to transfer presale tokens to another account
* @dev Note: will be reverted if called outside of Stages.Presale
* @dev calls function presaleTransfer(address to, uint256 value) external returns (bool);
* @param {*String} from [the account to transfer from, the transaction sending account, msg.sender]
* @param {*String} to [the account to transfer presale tokens to]
* @param {*String|BigNumber} amount [the amount of tokens to transfer]
* @returns {*Promise} txHash [a promisified txHash string]
*/
const presaleTransfer = (from, to, amount) => {
    return new Promise((resolve, reject) => {
        presaleContract.methods.presaleTransfer(to,amount).encodeABI()
        .then(function(data){
            buildTransaction(from, presaleDeployment, "", data, 15000)
            .then(function(tx){
                web3.eth.sendTransaction(tx, (error, hash) => {
                    if (error) {
                        reject(error);
                        return;
                    }
                    resolve(hash);
                })
            });
        })
    });
}

// Vesting Stage functions
/**
* @dev presaleTransfer function allows an account to transfer presale tokens to another account
* @dev Note: will be reverted if called outside of Stages.Presale
* @dev calls function function vest() external returns (bool);
* @param {*String} account [the account to vest and transfer tokens for, the transaction sending account, msg.sender]
* @returns {*Promise} txHash [a promisified txHash string]
*/

const vest = (account) => {
    return new Promise((resolve, reject) => {
        presaleContract.methods.vest().encodeABI()
        .then(function(data){
            buildTransaction(account, presaleDeployment, "", data, 15000)
            .then(function(tx){
                web3.eth.sendTransaction(tx, (error, hash) => {
                    if (error) {
                        reject(error);
                        return;
                    }
                    resolve(hash);
                })
            });
        })
    });
}

////////////////////// TODO - make scripts for Manager/Recover Role functionality as well //////////////////////////

/** 
* Manager Role Functionality


// PresaleDeployed Stage functions
function initilize (uint256 presaleAllocation) external  returns (bool);

// Presale Stage functions
function setupVest (uint256[5] vestThresholds, uint256[3][5] vestSchedules) external returns (bool);
function setCrowdsale(ICrowdsale TBNCrowdsale) external returns (bool);
function addPresaleBalance(address[] presaleAccounts, uint256[] values) external returns (bool);

// Vesting Stage functions
function approveVest(address account) external returns (bool);
function moveBalance(address account, address to) external returns (bool);

/** 
* Recoverer Role Functionality

// Vesting Stage functions
function recoverLost(IERC20 token_) external returns (bool);
*/

/**
* @dev buildTransaction function builds a transaction for the blockchain network
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
                    const tx = {
                        to: to,
                        nonce: nonce,
                        value: value,
                        gasPrice: web3.utils.toHex(gasPrice.toString()),
                        gasLimit: web3.utils.toHex(gasEstimate).toString(),
                        data: data
                    };
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

web3.eth.accounts.signTransaction(tx, privateKey).then(signed => {
    web3.eth.sendSignedTransaction(signed.rawTransaction).on('receipt', console.log)
});