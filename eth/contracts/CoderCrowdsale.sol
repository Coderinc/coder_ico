pragma solidity ^0.4.18;

import './zeppelin/lifecycle/Destructible.sol';
import './zeppelin/ownership/Ownable.sol';
import './CoderCoin.sol';
import './TokenTimelockMod.sol';

contract CoderCrowdsale is Ownable, Destructible, HasNoTokens {
    using SafeMath for uint256;
    
    uint8 private constant PERCENT_DIVIDER = 100;              


    uint256   public preSale_startTimestamp;        //when Presale started
    uint256   public preSale_baseRate;              //how many CDR one will get for 1 ETH during Presale without bonus
    uint256   public preSale_hardCap;               //hard cap for Presale in wei
    uint256   public preSale_collected;             //how much wei already collected at pre-sale

    uint256   public ICO_startTimestamp;            //when ICO sale started uint256 public
    uint256   public ICO_baseRate;                  //how many CDR one will get for 1 ETH during main sale without bonus
    uint256   public ICO_hardCap;                   //hard cap for the main sale round in wei
    uint256   public ICO_collected;                 //how much wei already collected at main sale

    uint8     public ICO_bonusStartPercent;         //Start bonus (in percents  of contribution)
    uint32    public ICO_bonusDecreaseInterval;     //Interval when bonus decreases during ICO
    uint8     public ICO_bonusDecreasePercent;      //Bonus decrease (in percents of contribution)
    uint256   public ICO_intervalContributionLimit; //How much wei we can accept during one interval  

    uint256   public minContribution;                //Do not accept contributions lower than this value
    uint8     public foundersPercent;                //Percent of tokens that will be minted to founders (including timelocks)
    uint256   public goal;                           //Minimal amount of collected Ether (if not reached - ETH may be refunded)


    struct PreSaleBonus {
        uint256 threshold;                          //Maximum amount collected, to receiv this bonus (if collected more - look for next bonus)
        uint32 bonusPercent;                        //F bonus percent, so that bonus = amount.mul(bonusPercent).div(PERCENT_DIVIDER)
    }
    PreSaleBonus[] public preSaleBonuses;           //Array of Presale bonuses sorted from min threshold to max threshold. Last threshold SHOULD be equal to preSale_hardCap

    enum State { Paused, PreSale, ICO, Finished }
    State public state;                                     //current state of the contracts
    CoderCoin public token;                                 //token for crowdsale
    mapping(address => bool) public whitelist;              //who is allowed to do purshases
    mapping(uint256 => uint256) public intervalCollected;   //mapping of intervals to weis collected during this interval
    mapping(address => uint256) contributions;              //amount of ether (in wei)received from a buyer


    /**
    * event for token purchase logging
    * @param purchaser who paid for the tokens
    * @param value weis paid for purchase
    * @param amount amount of tokens purchased
    */
    event TokenPurchase(address indexed purchaser, uint256 value, uint256 amount);

    /**
    * Stores addresses of beneficiaries in constructor timelocks
    */
    event TokenTimelockCreated(address TokenTimelock, uint64 releaseTimestamp, address beneficiary, uint256 amount);


    function CoderCrowdsale (
        uint256[] preSaleBonusThresholds, uint32[] preSaleBonusPercents, 
        uint256 _preSale_baseRate, uint256 _preSale_hardCap, uint256 _ICO_baseRate, uint256 _ICO_hardCap,
        uint8 _ICO_bonusStartPercent, uint32 _ICO_bonusDecreaseInterval, uint8 _ICO_bonusDecreasePercent, uint256 _ICO_intervalContributionLimit,
        uint8 _foundersPercent, uint256 _minContribution, uint256 _goal
        ) public {

        require(_preSale_baseRate > 0);
        require(_preSale_hardCap > 0);
        require(_ICO_baseRate > 0);
        require(_ICO_hardCap > 0);
        require(_ICO_bonusDecreaseInterval > 0);
        require(_ICO_bonusStartPercent > 0 && _ICO_bonusStartPercent <= PERCENT_DIVIDER);
        require(_ICO_bonusDecreasePercent > 0 && _ICO_bonusDecreasePercent < _ICO_bonusStartPercent);
        require(_ICO_intervalContributionLimit <= _ICO_hardCap);
        require(_minContribution < _preSale_hardCap);
        require(_minContribution < _ICO_intervalContributionLimit);
        
        state = State.Paused;

        initPreSale(preSaleBonusThresholds, preSaleBonusPercents, _preSale_baseRate, _preSale_hardCap);

        ICO_baseRate = _ICO_baseRate;
        ICO_hardCap = _ICO_hardCap;
        ICO_bonusDecreaseInterval = _ICO_bonusDecreaseInterval;
        ICO_bonusStartPercent = _ICO_bonusStartPercent;
        ICO_bonusDecreasePercent = _ICO_bonusDecreasePercent;
        ICO_intervalContributionLimit = _ICO_intervalContributionLimit;

        foundersPercent = _foundersPercent;
        minContribution = _minContribution;
        goal = _goal;

        token = new CoderCoin();                    //creating token in constructor
    }
    function initPreSale(uint256[] preSaleBonusThresholds, uint32[] preSaleBonusPercents, uint256 _preSale_baseRate, uint256 _preSale_hardCap) internal {
        preSale_baseRate = _preSale_baseRate;
        preSale_hardCap = _preSale_hardCap;

        uint256 prevMaxCollected = 0;
        require(preSaleBonusThresholds.length == preSaleBonusPercents.length);
        preSaleBonuses.length = preSaleBonusThresholds.length;
        for(uint8 i=0; i < preSaleBonuses.length; i++){
            preSaleBonuses[i] = PreSaleBonus({threshold:preSaleBonusThresholds[i], bonusPercent:preSaleBonusPercents[i]});
            PreSaleBonus storage psb = preSaleBonuses[i];
            require(prevMaxCollected < psb.threshold);
            prevMaxCollected = psb.threshold;
        }

        require(preSaleBonuses[preSaleBonuses.length - 1].threshold == _preSale_hardCap);
    }

    /**
    * @notice To buy tokens just send ether here
    */
    function() payable public {
        require(msg.value >= minContribution);
        require(whitelist[msg.sender]);
        require(crowdsaleOpen());
        uint256 rate = currentRate();
        assert(rate > 0);
        uint256 buyerTokens = rate.mul(msg.value);

        if (state == State.PreSale) {
            preSale_collected = preSale_collected.add(msg.value);
            require(preSale_collected <= preSale_hardCap);
        }else if (state == State.ICO) {
            ICO_collected = ICO_collected.add(msg.value);
            require(ICO_collected <= ICO_hardCap);

            uint256 currentInterval = calculateCurrentInterval();
            intervalCollected[currentInterval] = intervalCollected[currentInterval].add(msg.value);
            require(intervalCollected[currentInterval] <= ICO_intervalContributionLimit);
        }

        contributions[msg.sender] = contributions[msg.sender].add(msg.value);
        token.mint(msg.sender, buyerTokens);
        TokenPurchase(msg.sender, msg.value, buyerTokens);              //event for TokenPurchase
    }

    /**
    * @notice Check if crowdsale is open or not
    */
    function crowdsaleOpen() constant public returns(bool){
        return  (state != State.Paused) &&
                (state != State.Finished) &&
                !hardCapReached(state) &&
                !currentIntervalCapReached();
    }
    /**
    * @notice How many tokens you receive for 1 ETH
    * @return conversion rate
    */
    function currentRate() public constant returns(uint256){
        if(state == State.Paused || state == State.Finished) {
            return 0;
        } else if(state == State.PreSale) {
            return calculatePreSaleRate();
        } else if(state == State.ICO){
            return calculateICOrate();
        } else {
            revert();   //state is wrong
        }
    }

    function calculatePreSaleRate() constant public returns(uint256) {
        uint256 totalWeiCollected = totalCollected();
        uint32 bonus = 0;
        for(uint8 i=0; i < preSaleBonuses.length; i++){
            PreSaleBonus storage psb = preSaleBonuses[i];
            if(totalWeiCollected < psb.threshold) break;
            bonus = psb.bonusPercent;
        }
        uint256 rate = preSale_baseRate;
        uint256 bonusRate = rate.mul(bonus).div(PERCENT_DIVIDER); //divide by 100 to convert bonusPercentage to percent
        rate = rate.add(bonusRate);                               //add bonus tokens to base rate
        return rate;
    }

    function calculateICOrate() constant public returns(uint256){
        if(ICO_startTimestamp == 0) return 0;

        uint256 currentInterval = calculateCurrentInterval();
        uint256 decreaseBonusPercent = ICO_bonusDecreasePercent * currentInterval;
        assert(decreaseBonusPercent / currentInterval == ICO_bonusDecreasePercent); //SafeMath doesn't work with uint8 so check this manualy
        uint256 bonusPercentage = (ICO_bonusStartPercent > decreaseBonusPercent) ? (ICO_bonusStartPercent - decreaseBonusPercent) : 0;
        assert(bonusPercentage <= PERCENT_DIVIDER);

        uint256 rate = ICO_baseRate;
        uint256 bonusRate = rate.mul(bonusPercentage).div(PERCENT_DIVIDER);
        rate = rate.add(bonusRate);                                         //add bonus tokens to base rate
        return rate;
    }

    function hardCapReached(State _state) constant public returns(bool){
        if(_state == State.PreSale) {
            return preSale_collected >= preSale_hardCap;
        }else if(_state == State.ICO){
            return ICO_collected >= ICO_hardCap;
        }else {
            return false;
        }
    }

    function calculateCurrentInterval() constant public returns(uint256){
        if(ICO_startTimestamp == 0) return 0;
        assert(now >= ICO_startTimestamp);
        uint256 saleRunningSeconds = now - ICO_startTimestamp;
        return saleRunningSeconds.div(ICO_bonusDecreaseInterval); //remainder will be discarded
    }

    function currentIntervalCollected() constant public returns(uint256){
        if(state != State.ICO) return 0;
        uint256 currentInterval = calculateCurrentInterval();
        return intervalCollected[currentInterval];
    }
    function currentIntervalCapReached() constant public returns(bool){
        return currentIntervalCollected() >= ICO_intervalContributionLimit;
    }

    /**
    * @notice Allow/Deny to make purshases from specified address
    * @param who Address which is allowed to make purshase
    * @param allow True if address "who" allowed to purshase. False for revoke previous allowance
    */
    function whitelistAddress(address who, bool allow) public onlyOwner {
        whitelist[who] = allow;
    }

    /**
    * @notice Owner can change state
    * @param newState New state of the crowdsale
    */
    function setState(State newState) public onlyOwner {
        require(state != State.Finished); //if Finished, no state change possible
        if(newState == State.Finished){
            //token.finishMinting();
            //token.transferOwnership(owner);
            require(false);
        }else if(newState == State.PreSale && preSale_startTimestamp == 0) {
            preSale_startTimestamp = now;
        }else if(newState == State.ICO && ICO_startTimestamp == 0) {
            ICO_startTimestamp = now;
        }
        state = newState;
    }

    function totalCollected() constant public returns(uint256){
        return preSale_collected.add(ICO_collected);   //total wei raised in each round
    }

    /**
    * @notice Owner can claim collected ether
    */
    function claimCollectedEther() onlyOwner public {
        require(totalCollected() >= goal);
        if(this.balance > 0){
            owner.transfer(this.balance);    
        }
    }

    function finishCrowdsale(address[] reserveBeneficiaries, uint64[] reserveReleases, uint8[] reservePercents) onlyOwner public {
        require(reserveBeneficiaries.length == reserveReleases.length);
        require(reserveBeneficiaries.length == reservePercents.length);

        uint8 beneficiaryPercent = 0;
        for(uint8 i=0; i < reservePercents.length; i++){
            require(reservePercents[i] > 0);
            require(reservePercents[i] <= PERCENT_DIVIDER);
            beneficiaryPercent += reservePercents[i];
            require(beneficiaryPercent <= PERCENT_DIVIDER);
        }
        uint8 ownerPercent = PERCENT_DIVIDER - beneficiaryPercent;

        uint256 totalTokens = token.totalSupply().mul(foundersPercent).div(PERCENT_DIVIDER);
        for(i=0; i < reserveBeneficiaries.length; i++){
            uint256 amount = totalTokens.mul(reservePercents[i]).div(PERCENT_DIVIDER);
            require(reserveReleases[i] > now);
            require(reserveBeneficiaries[i] != address(0));
            //TokenTimelock tt = new TokenTimelock(token, reserveBeneficiaries[i], reserveReleases[i]);
            TokenTimelockMod tt = new TokenTimelockMod(reserveReleases[i]);
            tt.transferOwnership(reserveBeneficiaries[i]);
            assert(token.mint(tt, amount));
            TokenTimelockCreated(tt, reserveReleases[i], reserveBeneficiaries[i], amount);
        }

        amount = totalTokens.mul(ownerPercent).div(PERCENT_DIVIDER);
        token.mint(owner, amount);

        token.finishMinting();
        token.transferOwnership(owner);
        state = State.Finished;
    }


    /**
    * @notice Sends all contributed ether back if minimum cap is not reached by the end of crowdsale
    */
    function refund() public returns(bool){
        return refundTo(msg.sender);
    }
    function refundTo(address beneficiary) public returns(bool) {
        require(state == State.Finished);
        require(contributions[beneficiary] > 0);
        require(totalCollected() < goal);

        uint256 value = contributions[beneficiary];
        contributions[beneficiary] = 0;
        beneficiary.transfer(value);
        return true;
    }
    function refundAvailable(address beneficiary) constant public returns(uint256){
        if(state != State.Finished) return 0;
        if(totalCollected() >= goal) return 0;
        return contributions[beneficiary];
    }

}


