// (C) block.one all rights reserved

pragma solidity ^0.4.11;

import "../math/SafeMath.sol";
import "../ERC20/IERC20.sol";
import "../presale/IPresale.sol";
import "./ICrowdsale.sol";
import "../access/roles/ManagerRole.sol";
import "../access/roles/RecoverRole.sol";

contract TBNCrowdSale is ICrowdsale, ManagerRole, RecoverRole, FundkeeperRole {
    using SafeMath for uint256;

    uint256 public numberOfIntervals;   // number of intervals in the sale
    bytes32 public hiddenCap;           // a hash of <the hidden hard cap(in WEI)>+"SECRET"+<a secret number> to be revealed if/when the hard cap is reached - does not rebase so choose wisely

    IERC20 public ERC20;                // the TBN ERC20 token deployment
    IPresale public presale;            // the presale contract deployment
                                                    // Note: 18 decimal precision accomodates ETH prices up to 10**5
    uint256 public ETHPrice;                        // ETH price in USD with 18 decimal precision for calculating reserve pricing
    uint256 public reserveFloor;                    // the minimum possible reserve price in USD @ 18 decimal precision
    uint256 public reserveCeiling;                  // the maximum possible reserve price in USD @ 18 decimal precision
    uint256 private reserveStep = 29166 * 10**10;   // the base amount to step down the price if reserve is not met @ 18 decimals of precision

    uint256 public crowdsaleAllocation;     // total amount of TBN allocated to the crowdsale contract for distribution
    
    uint256 public startBlock;              // block number of the start of interval 0
    
    uint256 public tokensPerInterval;       // number of tokens available for distribution each interval
    
    uint256 private _rebaseNewPrice;        // temporarily holds the rebase ETH price until the next active interval @ decimal 18
    uint256 private _rebaseSet;                // the interval the rebase is set in, set back to 0 after rebasing

    uint256 private WEI_FACTOR = 10**18;    // ETH base in WEI

    uint256 private INTERVAL_BLOCKS = 5520; // number of block per interval - 23 hours @ 15 sec per block
    uint256 private REBASE_BLOCKS = 69120;  // number of blocks per rebase period - 12 days @ 15 sec per block


    mapping (uint256 => uint256) public dailyTotals;
    mapping (uint256 => bool) public rebased;

    uint256 private _lastAdjustedInterval; 
    struct Interval {
        uint256 reservePrice;  // the reservePrice for this interval @ 18 decimals of precision
        uint256 ETHReserveAmount;
        
    }
    mapping (uint256 => Interval) public intervals;


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

    // check that re-serve adjustment is current and all are re-based 
    modifier reChecks() {
        uint256 interval = getInterval(block.number);
        if(_lastAdjustedInterval != interval){
            for (uint i = _lastAdjustedInterval.add(1); i <= interval; i++) {
                _adjustReserve(i);
            }
            _lastAdjustedInterval = interval;
        }

        if(_rebaseSet != 0){
            require(_rebaseNewPrice != 0, "_rebaseNewPrice cannot equal zero");
            // only after ajdustment is current can we rebase
            _rebase(_rebaseNewPrice);
            _;
            _rebaseSet = 0;
        } else {
            _;
        }
    }

    constructor(
        IERC20 ERC20_,
        IPresale presale_,
        uint256 numberOfIntervals_,
        bytes32 hiddenCap_
        
    ) public {
        require(address(ERC20_) != 0x0, "token address cannot be 0x0");
        require(address(presale_) != 0x0, "presale address cannot be 0x0");
        require(presale_.getERC20() == address(ERC20_), "Presale contract must be assigned to the same ERC20 instance as this contract");
        require(numberOfIntervals_ > 0, "numberOfIntervals must be larger than zero");

        numberOfIntervals = numberOfIntervals_;
        hiddenCap = hiddenCap_;
        stages = Stages.CrowdsaleDeployed;
        ERC20 = ERC20_;
        presale = presale_;
        
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
        return address(ERC20);
    }

    // rebase ETH participation depending on ETH and reserve pricing
    function getMin() public view atStage(Stages.Crowdsale) returns (uint256) {
        uint256 interval = getInterval(block.number);
        uint256 minETH;
        if (ETHPrice < intervals[interval].reservePrice) {
            minETH = 10 ether;
        } else if (ETHPrice < intervals[interval].reservePrice.mul(uint256(10))) {
            minETH = 1 ether;
        } else if (ETHPrice < intervals[interval].reservePrice.mul(uint256(100))) {
            minETH = .1 ether;
        } else if (ETHPrice < intervals[interval].reservePrice.mul(uint256(1000))) {
            minETH = .01 ether;
        } else {
            minETH = .001 ether;
        }
    }

    // This method provides the participant some protections regarding which
    // day the participation is submitted and the maximum price prior to
    // applying this payment that will be allowed. (price is in TBN per ETH)
    function participate(uint256 limit) public payable reChecks atStage(Stages.Crowdsale) returns (bool) {
        uint256 interval = getInterval(block.number);
        require(interval <= numberOfIntervals, "interval of current block number must be less than or equal to the number of intervals");
        require(msg.value >= getMin(), "minimum participation amount, enforced to prevent rounding errors in ");

        participationAmount[interval][msg.sender] = participationAmount[interval][msg.sender].add(msg.value);
        dailyTotals[interval] = dailyTotals[interval].add(msg.value);

        if (limit != 0) {
            require(tokensPerInterval.div(dailyTotals[interval]) <= limit, "");
        }

        emit Participated(interval, msg.sender, msg.value);

        return true;
    }

    function claim(uint256 interval) public reChecks atStage(Stages.Crowdsale) {
        require(stages == Stages.Crowdsale || stages == Stages.CrowdsaleEnded, "must be in the last two stages to call");
        require(getInterval(block.number) > interval, "the given interval must be less than the current interval");

        if (claimed[interval][msg.sender] || dailyTotals[interval] == 0) {
            return;
        }

        //uint256 claiming = dailyTotals[interval].mul(WEI_FACTOR).div(tokensPerInterval).mul(participationAmount[interval][msg.sender]);
        
        uint256 contributorProportion = participationAmount[interval][msg.sender].mul(WEI_FACTOR).div(dailyTotals[interval]);
        uint256 reserveMultiplier;
        if (dailyTotals[interval] >= intervals[interval].ETHReserveAmount){
            reserveMultiplier = WEI_FACTOR;
        } else {
            reserveMultiplier = dailyTotals[interval].mul(WEI_FACTOR).div(intervals[interval].ETHReserveAmount);
        }
        uint256 intervalClaim = tokensPerInterval.mul(contributorProportion).mul(reserveMultiplier).div(WEI_FACTOR.mul(3));

        claimed[interval][msg.sender] = true;
        ERC20.transfer(msg.sender, intervalClaim);

        emit Claimed(interval, msg.sender, intervalClaim);
    }

    function claimAll() public atStage(Stages.Crowdsale) {
        for (uint i = 0; i < getInterval(block.number); i++) {
            claim(i);
        }
    }

    function initialize(
        uint256 basisPrice_,
        uint256 reserveFloor_, 
        uint256 reserveCeiling_,
        uint256 crowdsaleAllocation_
    ) 
        external 
        onlyManager 
        atStage(Stages.CrowdsaleDeployed) 
        returns (bool) 
    {
        require(crowdsaleAllocation_ > 0, "crowdsale allocation must be assigned a number greater than 0");
        
        address fundkeeper = ERC20.fundkeeper();
        require(ERC20.allowance(address(fundkeeper), address(this)) == crowdsaleAllocation_, "crowdsale allocation must be equal to the amount of tokens approved for this contract");
        require(basisPrice_ > 0, "ETH basis price must be greater than 0"); 
        require(reserveFloor_ > 0, "the reserve floor must be greater than 0");
        require(reserveCeiling_ > reserveFloor_, "the reserve ceiling must be greater than the reserve floor");
        require(presale.readyToVest(), "presale contract not ready to vest yet");

        ETHPrice = basisPrice_;
        crowdsaleAllocation = crowdsaleAllocation_;
        reserveFloor = reserveFloor_;
        reserveCeiling = reserveCeiling_;
        
        // calc initial intervalReserve
        uint256 interval = getInterval(block.number);
        intervals[interval].reservePrice = reserveCeiling;
        intervals[interval].ETHReserveAmount = tokensPerInterval.mul(intervals[interval].reservePrice.mul(WEI_FACTOR).div(ETHPrice));
        
        
        rebased[_rebaseFor(block.number)] = true;

        // place crowdsale allocation in this contract
        ERC20.transferFrom(fundkeeper, address(this), crowdsaleAllocation);

        // start the presale vesting stage
        presale.startVestingStage();

        //create variables
        startBlock = block.number;
        tokensPerInterval = crowdsaleAllocation.div(numberOfIntervals);
       
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

    // crowdsale manager can rebase the ETH price once ever 12 days
    function setRebase(uint256 newETHPrice) external onlyManager atStage(Stages.Crowdsale) returns (bool) {
        uint256 rebasePeriod = _rebaseFor(block.number);
        require(!rebased[rebasePeriod], "rebase has been successfully run for this period, cannot rebase again");
        _rebaseNewPrice = newETHPrice;
        _rebaseSet = block.number;
        return true;
    }

    // reveal hidden cap (and end sale early)
    function revealCap(uint256 cap, uint256 secret) external onlyManager atStage(Stages.Crowdsale) returns (bool) {
        bytes32 hashed = keccak256(abi.encode(cap, secret));
        if (hashed == hiddenCap) {
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
        uint256 setRebasePeriod = _rebaseFor(_rebaseSet);
        uint256 rebasePeriod = _rebaseFor(block.number);
        uint256 interval = getInterval(block.number);
        require(setRebasePeriod == rebasePeriod, "current rebase period must match the period when this rebase was initiated");
        
        // new ETH base price
        ETHPrice = newETHPrice;

        // recalc intervals reserve amount
        intervals[interval].ETHReserveAmount = tokensPerInterval.mul(intervals[interval].reservePrice.mul(WEI_FACTOR).div(ETHPrice));

        rebased[rebasePeriod] = true;   // rebase has been successfully run
        _rebaseSet = 0;                 // _rebaseSet block number back to 0
        
        emit Rebased(
            ETHPrice,
            intervals[interval].ETHReserveAmount
        );
    } 

    // Each rebase cycle is 12 days long (total of 15 rebase periods during the sale)
    //
    function _rebaseFor(uint256 blockNumber) internal view returns (uint256) {
        return blockNumber < startBlock
            ? 0
            : blockNumber.sub(startBlock).div(REBASE_BLOCKS);
    }


    // Each window is 23 hours long so that end-of-window rotates
    // around the clock for all timezones.
    function _intervalFor(uint256 blockNumber) internal view returns (uint256) {
        return blockNumber < startBlock
            ? 0
            : blockNumber.sub(startBlock).div(INTERVAL_BLOCKS);
    }

    function _adjustReserve(uint256 interval) internal {
        require(_lastAdjustedInterval.add(uint256(1)) == interval, "must adjust exactly the next interval");
        // get last reserve info
        uint256 lastIntervalPrice = dailyTotals[_lastAdjustedInterval].mul(WEI_FACTOR).div(tokensPerInterval); // token price in ETH
        uint256 lastAmount = intervals[_lastAdjustedInterval].ETHReserveAmount;

        // check if last reserve was met
        uint256 adjustment;
        // adjust reservePrice accordingly
        if (dailyTotals[_lastAdjustedInterval] >= lastAmount){
            if(lastIntervalPrice >= reserveCeiling){
                intervals[interval].reservePrice = reserveCeiling;
            } else {
                intervals[interval].reservePrice = dailyTotals[_lastAdjustedInterval].mul(ETHPrice).div(tokensPerInterval);
            }
        } else {
            uint256 offset = WEI_FACTOR.sub(dailyTotals[_lastAdjustedInterval].mul(WEI_FACTOR).div(intervals[_lastAdjustedInterval].ETHReserveAmount));
            if (offset < 10**17) {
                adjustment = uint256(1);
            } else if(offset != WEI_FACTOR) {
                adjustment = (offset.div(10**17)).add(uint256(1));
            } else {
                adjustment = uint256(10);
            }

            uint256 newReservePrice = intervals[interval].reservePrice.sub(reserveStep.mul(adjustment));
            if(newReservePrice <= reserveFloor){
                intervals[interval].reservePrice = reserveFloor;
            } else {
                intervals[interval].reservePrice = newReservePrice;
            } 
        }
        // calculate reserveAmount
        intervals[interval].ETHReserveAmount = tokensPerInterval.mul(intervals[interval].reservePrice.mul(WEI_FACTOR).div(ETHPrice));
    }

}