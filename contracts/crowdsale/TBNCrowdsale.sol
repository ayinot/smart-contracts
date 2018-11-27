// (C) block.one all rights reserved

pragma solidity ^0.4.24;

import "../math/SafeMath.sol";
import "../ERC20/IERC20.sol";
import "../presale/IPresale.sol";
import "./ICrowdsale.sol";
import "../access/roles/ManagerRole.sol";
import "../access/roles/RecoverRole.sol";

contract TBNCrowdSale is ICrowdsale, ManagerRole, RecoverRole, FundkeeperRole {
    using SafeMath for uint256;

    uint256 private _numberOfIntervals;             // number of intervals in the sale (188)
    bytes32 private _hiddenCap;                     // a hash of <the hidden hard cap(in WEI)>+<a secret number> to be revealed if/when the hard cap is reached - does not rebase so choose wisely

    IERC20 private _erc20;                          // the TBN ERC20 token deployment
    IPresale private _presale;                      // the presale contract deployment
                                                    // Note: 18 decimal precision accomodates ETH prices up to 10**5
    uint256 private _ETHPrice;                      // ETH price in USD with 18 decimal precision for calculating reserve pricing
    uint256 private _reserveFloor;                  // the minimum possible reserve price in USD @ 18 decimal precision (set @ 0.0975 USD)
    uint256 private _reserveCeiling;                // the maximum possible reserve price in USD @ 18 decimal precision (set @ 0.15 USD)
    uint256 private _reserveStep;                   // the base amount to step down the price if reserve is not met @ 18 decimals of precision (0.15-.0975/188 = .0000279255)

    uint256 private _crowdsaleAllocation;           // total amount of TBN allocated to the crowdsale contract for distribution
    uint256 private _presaleDistribution;           // total amount of TBN distributed to accounts in the presale contract

    uint256 private WEI_FACTOR = 10**18;            // ETH base in WEI

    uint256 private INTERVAL_BLOCKS = 5520;         // number of block per interval - 23 hours @ 15 sec per block

    uint256 private _rebaseNewPrice;                // holds the rebase ETH price until rebasing in the next active interval @ decimal 18
    uint256 private _rebased;                       // the interval the last rebase was set in, 0 if no rebasing has been done
    
    uint256 private _startBlock;                    // block number of the start of interval 0
    
    uint256 private _tokensPerInterval;             // number of tokens available for distribution each interval
    
    uint256 private _lastAdjustedInterval;          // the most recent reserve adjusted interval

    mapping (uint256 => uint256) public intervalTotals; // total ETH contributed per interval

    
    struct Interval {
        uint256 reservePrice;  // the reservePrice for this interval @ 18 decimals of precision
        uint256 ETHReserveAmount;
    }

    mapping (uint256 => Interval) public intervals;

    struct PresaleData {
        uint256 balance;
        uint256 remaining;
        bool setup;
    }

    mapping (address => PresaleData) public presaleData;

    mapping (uint256 => mapping (address => uint256)) public participationAmount;
    mapping (uint256 => mapping (address => bool)) public claimed;
    
    Stages public stages;

    /*
     *  Enums
     */
    enum Stages {
        CrowdsaleDeployed,
        Crowdsale,
        CrowdsaleEnded
    }

    /*
     *  Modifiers
     */
    modifier atStage(Stages _stage) {
        require(stages == _stage, "functionality not allowed at current stage");
        _;
    }

    // update reserve adjustment and execute rebasing if ETH price was rebased last interval
    modifier update() {
        uint256 interval = getInterval(block.number);
        if(_lastAdjustedInterval != interval){ // check that the current interval was reserve adjusted
            for (uint i = _lastAdjustedInterval.add(1); i <= interval; i++) { // if not catch up adjustment until current interval
                _adjustReserve(i);
            }
            _lastAdjustedInterval = interval;
        }
        // we can rebase only if reserve ETH ajdustment is current (done above)
        if(_rebased == interval.sub(1)){ // check if the ETH price was rebased last interval
            _rebase(_rebaseNewPrice);
            _;
        } else {
            _;
        }
    }

    constructor(
        IERC20 token,
        IPresale presale,
        uint256 numberOfIntervals,
        bytes32 hiddenCap
        
    ) public {
        require(address(token) != 0x0, "token address cannot be 0x0");
        require(address(presale) != 0x0, "presale address cannot be 0x0");
        require(presale.getERC20() == address(token), "Presale contract must be assigned to the same ERC20 instance as this contract");
        require(numberOfIntervals > 0, "numberOfIntervals must be larger than zero");

        _numberOfIntervals = numberOfIntervals;
        _hiddenCap = hiddenCap;
        _erc20 = token;
        _presale = presale;

        stages = Stages.CrowdsaleDeployed;
    }

    /**
    * @dev Fallback participates with any ETH payment 
    */
    function () public payable {
        participate(0);
    }

    function getInterval(uint256 blockNumber) public view returns (uint256) {
        return _intervalFor(blockNumber);
    }

    function getERC20() public view returns (address) {
        return address(_erc20);
    }

    function getPresale() public view returns (address) {
        return address(_presale);
    }

    // rebase ETH participation depending on ETH and reserve pricing
    function getMin() public view atStage(Stages.Crowdsale) returns (uint256) {
        uint256 interval = getInterval(block.number);
        uint256 minETH;
        if (_ETHPrice < intervals[interval].reservePrice) {
            minETH = 10 ether;
        } else if (_ETHPrice < intervals[interval].reservePrice.mul(10)) {
            minETH = 1 ether;
        } else if (_ETHPrice < intervals[interval].reservePrice.mul(100)) {
            minETH = .1 ether;
        } else if (_ETHPrice < intervals[interval].reservePrice.mul(1000)) {
            minETH = .01 ether;
        } else {
            minETH = .001 ether;
        }
        return minETH;
    }

    // This method provides the participant some protections regarding the maximum price prior to
    // applying this payment that will be allowed. (price is in TBN per ETH)
    function participate(uint256 limit) public payable reChecks atStage(Stages.Crowdsale) returns (bool) {
        uint256 interval = getInterval(block.number);
        require(interval <= _numberOfIntervals, "interval of current block number must be less than or equal to the number of intervals");
        require(msg.value >= getMin(), "minimum participation amount, enforced to prevent rounding errors in ");

        participationAmount[interval][msg.sender] = participationAmount[interval][msg.sender].add(msg.value);
        intervalTotals[interval] = intervalTotals[interval].add(msg.value);

        if (limit != 0) {
            require(_tokensPerInterval.div(intervalTotals[interval]) <= limit, "");
        }

        emit Participated(interval, msg.sender, msg.value);

        return true;
    }

    function claim(uint256 interval) public reChecks atStage(Stages.Crowdsale) {
        require(stages == Stages.Crowdsale || stages == Stages.CrowdsaleEnded, "must be in the last two stages to call");
        require(getInterval(block.number) > interval, "the given interval must be less than the current interval");
        
        uint256 intervalClaim;
        
        if (_presale.presaleBalanceOf(account) == 0){
            if (claimed[interval][msg.sender] || intervalTotals[interval] == 0) {
                return;
            }
        }

        uint256 contributorProportion = participationAmount[interval][msg.sender].mul(WEI_FACTOR).div(intervalTotals[interval]);
        uint256 reserveMultiplier;
        if (intervalTotals[interval] >= intervals[interval].ETHReserveAmount){
            reserveMultiplier = WEI_FACTOR;
        } else {
            reserveMultiplier = intervalTotals[interval].mul(WEI_FACTOR).div(intervals[interval].ETHReserveAmount);
        }

        intervalClaim = _tokensPerInterval.mul(contributorProportion).mul(reserveMultiplier).div(WEI_FACTOR.mul(3));

        // presale vesting
        intervalClaim = intervalClaim.add(_presaleVesting(msg.sender));

        claimed[interval][msg.sender] = true;
        _erc20.transfer(msg.sender, intervalClaim);

        emit Claimed(interval, msg.sender, intervalClaim);
    }

    function _presaleVesting(address account) internal returns (uint256) {

        if(!presaleData[account].setup){ // intial assignment of an account's presale data
            uint256 totalPresaleAmount = _presale.presaleBalanceOf(account);
            presaleData[account].balance = totalPresaleAmount;
            presaleData[account].remaining = totalPresaleAmount;
            presaleData[account].setup = true;
        }
        
        uint256 vestRate;
        if(presaleData[account].balance <= _numberOfIntervals.mul(10**20)){
            vestRate = 10**20; // this is 100 TBN (100 TBN is the minimum vesting amount per interval - except on last vest for account, vesting all remaining could be smaller)
        } else {
            vestRate = presaleData[account].balance.div(_numberOfIntervals);
        }

        assert(vestRate >= 10**20); // the above guarantees this

        if (presaleData[account].remaining > 0){ // check if there is any remaining balance to vest
            if (vestRate <= presaleData[account].remaining) { // check if set vest rate is <= remaining
                presaleData[account].remaining = presaleData[account].remaining.sub(vestRate);
                emit PresaleVest(account, vestRate);
                return vestRate;
            } else {
                vestRate = presaleData[account].remaining; // vest all remaining, as it is less than this accounts interval vest amount
                presaleData[account].remaining = presaleData[account].remaining.sub(vestRate);
                emit PresaleVest(account, vestRate);
                return vestRate;
            }
        } else { // no remaining balance to vest
            return 0;
        }
        
    }

    function claimAll() public atStage(Stages.Crowdsale) {
        for (uint i = 0; i < getInterval(block.number); i++) {
            claim(i);
        }
    }

    function initialize(
        uint256 ETHPrice,
        uint256 reserveFloor, 
        uint256 reserveCeiling,
        uint256 crowdsaleAllocation
    ) 
        external 
        onlyManager 
        atStage(Stages.CrowdsaleDeployed) 
        returns (bool) 
    {
        require(ETHPrice > 0, "ETH basis price must be greater than 0"); 
        require(reserveFloor > 0, "the reserve floor must be greater than 0");
        require(reserveCeiling > reserveFloor.add(_numberOfIntervals), "the reserve ceiling must be _numberOfIntervals WEI greater than the reserve floor");
        require(crowdsaleAllocation > 0, "crowdsale allocation must be assigned a number greater than 0");
        
        address fundkeeper = _erc20.fundkeeper();
        require(_erc20.allowance(address(fundkeeper), address(this)) == crowdsaleAllocation, "crowdsale allocation must be equal to the amount of tokens approved for this contract");
        require(_presale.getCrowdsale() == address(this), " crowdsale contract address has not been set in the presale contract yet");

        _ETHPrice = ETHPrice;
        _crowdsaleAllocation = crowdsaleAllocation;
        _reserveFloor = reserveFloor;
        _reserveCeiling = reserveCeiling;
        _reserveStep = (_reserveCeiling.sub(_reserveFloor)).div(_numberOfIntervals);
        
        // calc initial intervalReserve
        uint256 interval = getInterval(block.number);
        intervals[interval].reservePrice = (_reserveCeiling.mul(WEI_FACTOR)).div(_ETHPrice);
        intervals[interval].ETHReserveAmount = _tokensPerInterval.mul(intervals[interval].reservePrice);

        // place crowdsale allocation in this contract
        _erc20.transferFrom(fundkeeper, address(this), crowdsaleAllocation);

        // end the Presale Stage of the presale contract (therby locking any presale account updates and transferring the distributed presale tokens to this contract for vested claiming)
        _presale.presaleEnd();
        uint256 presaleDistribution = _presale.getPresaleDistribution(); // this can no longer change and is the amount sent to this contract form the presale contract
        _presaleDistribution = presaleDistribution;
        //create variables
        _startBlock = block.number;
        _tokensPerInterval = crowdsaleAllocation.div(_numberOfIntervals);
       
        stages = Stages.Crowdsale;

        return true;
    }

    /**
    * @dev Safety function for recovering missent ERC20 tokens
    * @param token address of the ERC20 contract
    */
    function recoverToken(IERC20 token) external onlyRecoverer atStage(Stages.CrowdsaleEnded) returns (bool) {
        token.transfer(msg.sender, token.balanceOf(address(this)));
        return true;
    }

    // crowdsale manager can rebase the ETH price (rebase will be applied to the next interval)
    function setRebase(uint256 newETHPrice) external onlyManager atStage(Stages.Crowdsale) returns (bool) {
        uint256 interval = getInterval(block.number);
        require(interval > 0, "cannot rebase in the initial interval");
        _rebaseNewPrice = newETHPrice;
        _rebased = interval;
        return true;
    }

    // reveal hidden cap (and end sale early)
    function revealCap(uint256 cap, uint256 secret) external onlyManager atStage(Stages.Crowdsale) returns (bool) {
        bytes32 hashed = keccak256(abi.encode(cap, secret));
        if (hashed == _hiddenCap) {
            stages = Stages.CrowdsaleEnded;
            return true;
        }
        return false;
    }

    // Fundkeeper can collect ETH any number of times
    function collect() external onlyFundkeeper returns (bool) {
        msg.sender.transfer(address(this).balance);
        emit Collected(msg.sender, address(this).balance);
    }

    function _rebase(uint256 newETHPrice) internal onlyManager atStage(Stages.Crowdsale) {
        uint256 interval = getInterval(block.number);

        // new ETH base price
        _ETHPrice = newETHPrice;

        // recalc ETH reserve Price
        intervals[interval].reservePrice = (_reserveCeiling.mul(WEI_FACTOR)).div(_ETHPrice);
        // recalc ETH reserve amount
        intervals[interval].ETHReserveAmount = _tokensPerInterval.mul(intervals[interval].reservePrice);

        // reset _rebaseNewPrice to 0
        _rebaseNewPrice = 0;

        emit Rebased(
            _ETHPrice,
            intervals[interval].ETHReserveAmount
        );
    } 

    // Each window is 23 hours long so that end-of-window rotates
    // around the clock for all timezones.
    function _intervalFor(uint256 blockNumber) internal view returns (uint256) {
        return blockNumber < _startBlock
            ? 0
            : blockNumber.sub(_startBlock).div(INTERVAL_BLOCKS);
    }

    function _adjustReserve(uint256 interval) internal {
        require(interval > 0, "cannot adjust the intial interval reserve");
        // get last reserve info
        uint256 lastReserveAmount = intervals[interval.sub(1)].ETHReserveAmount;
        uint256 lastIntervalPrice = intervals[interval.sub(1)].reservePrice;

        // check if last reserve was met
        uint256 adjustment;
        // adjust reservePrice accordingly
        if (intervalTotals[interval.sub(1)] >= lastReserveAmount){ // reserve ETH was met last interval
            uint ceiling = (_reserveCeiling.mul(WEI_FACTOR)).div(_ETHPrice);
            if(lastReserveAmount == _tokensPerInterval.mul(ceiling)){ // lastReserveAmount was equal to the max reserve ETH
                intervals[interval].reservePrice = ceiling; // reserve price cannot go above ceiling
            } else { // reserve met but lastReserveAmount was less than max reserve
                intervals[interval].reservePrice = intervalTotals[interval.sub(1)].mul(_ETHPrice).div(_tokensPerInterval);
                intervals[interval].ETHReserveAmount = _tokensPerInterval.mul(intervals[interval].reservePrice);
            }
        } else {
            uint256 offset = WEI_FACTOR.sub(intervalTotals[_lastAdjustedInterval].mul(WEI_FACTOR).div(intervals[_lastAdjustedInterval].ETHReserveAmount));
            if (offset < 10**17) {
                adjustment = 1;
            } else if(offset != WEI_FACTOR) {
                adjustment = (offset.div(10**17)).add(1);
            } else {
                adjustment = 10;
            }

            uint256 newReservePrice = intervals[interval].reservePrice.sub(_reserveStep.mul(adjustment));
            if(newReservePrice <= _reserveFloor){
                intervals[interval].reservePrice = _reserveFloor;
            } else {
                intervals[interval].reservePrice = newReservePrice;
            } 
        }
        // calculate reserveAmount
        intervals[interval].ETHReserveAmount = _tokensPerInterval.mul(intervals[interval].reservePrice.mul(WEI_FACTOR).div(_ETHPrice));
    }

}