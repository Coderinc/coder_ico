pragma solidity ^0.4.18;

import './zeppelin/ownership/Ownable.sol';
import './CoderCoin.sol';
import './TokenTimelockMod.sol';

contract CoderCrowdsale is Ownable, HasNoTokens {
    using SafeMath for uint256;
    
    uint8 private constant PERCENT_DIVIDER = 100;    

    //Hard-coded values
    uint256 public constant baseRate = 1000;                 //1 ETH = 1000 CDR, both for PreSale and ICO rounds      
    uint256 public constant goal = 500 ether;                //Minimal amount of collected Ether (if not reached - ETH may be refunded)
    uint8   public constant foundersPercent = 100;           //Percent of tokens that will be minted to founders (including timelocks). 100 means that Founders will receive same amount as minted during crowdsale. So they'll have 50% of a token totalSupply
    uint256 public constant preSale_hardCap = 5000 ether;    //hard cap for Presale in wei
    uint256 public constant preSale_maxDuration = 90 days;
    uint256 public constant ICO_maxDuration     = 30 days;

    uint256   public preSale_startTimestamp;        //when Presale started
    uint256   public preSale_collected;             //how much wei already collected at pre-sale

    uint256   public ICO_startTimestamp;            //when ICO sale started uint256 public
    uint256   public ICO_hardCap;                   //hard cap for the main sale round in wei
    uint256   public ICO_collected;                 //how much wei already collected at main sale

    uint256   public minContribution;               //Do not accept contributions lower than this value


    struct Bonus {
        uint256 threshold;                          //Maximum amount collected, to receiv this bonus (if collected more - look for next bonus)
        uint32 percent;                             //Bonus percent, so that bonus = amount.mul(percent).div(PERCENT_DIVIDER)
    }
    Bonus[] public preSaleBonuses;                  //Array of Presale bonuses sorted from min threshold to max threshold. Last threshold SHOULD be equal to preSale_hardCap
    Bonus[] public icoBonuses;                      //Array of Presale bonuses sorted from min threshold to max threshold. Last threshold SHOULD be equal to preSale_hardCap

    enum State { Paused, PreSale, ICO, Finished }
    State public state;                             //current state of the contracts
    CoderCoin public token;                         //token for crowdsale
    mapping(address => bool) public whitelist;      //who is allowed to do purshases
    mapping(address => uint256) contributions;      //amount of ether (in wei)received from a buyer

    address public manager;                         //Address which can do whitelisting

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


    /**
    * @dev Throws if called by any account other than the owner.
    */
    modifier onlyOwnerOrManager() {
        require(msg.sender == owner || msg.sender == manager);
        _;
    }

    /**
    * @notice Constructor of Crowdsale
    */
    function CoderCrowdsale (
        uint256[] preSaleBonusThresholds, uint32[] preSaleBonusPercents, 
        uint256[] icoBonusThresholds, uint32[] icoBonusPercents, 
        uint256 _ICO_hardCap,
        uint256 _minContribution
        ) public {

        require(_ICO_hardCap > 0);
        require(_minContribution < _ICO_hardCap);
        
        state = State.Paused;

        initBonusArray(preSaleBonuses, preSaleBonusThresholds, preSaleBonusPercents);
        require(preSaleBonuses[preSaleBonuses.length - 1].threshold <= preSale_hardCap);

        ICO_hardCap = _ICO_hardCap;
        initBonusArray(icoBonuses, icoBonusThresholds, icoBonusPercents);
        require(icoBonuses[icoBonuses.length - 1].threshold <= preSale_hardCap.add(_ICO_hardCap));

        minContribution = _minContribution;

        token = new CoderCoin();                    //creating token in constructor
        manager = owner;
    }

    /**
    * @dev Initialize bonus levels
    * @param bonuses Where to store bonus levels
    * @param thresholds Array of bonuls level thresholds
    * @param percents Array of bonus percents
    */
    function initBonusArray(Bonus[] storage bonuses, uint256[] thresholds, uint32[] percents) internal {
        require(thresholds.length == percents.length);
        uint256 prevThreshold = 0;
        bonuses.length = thresholds.length;
        for(uint8 i=0; i < bonuses.length; i++){
            bonuses[i] = Bonus({threshold:thresholds[i], percent:percents[i]});
            Bonus storage b = bonuses[i];
            require(prevThreshold < b.threshold);
            prevThreshold = b.threshold;
        }
    }

    /**
    * @notice To buy tokens just send ether here
    */
    function() payable public {
        require(msg.value >= minContribution);
        require(whitelist[msg.sender]);
        require(crowdsaleOpen());

        uint256 change = 0; 
        uint256 amount = msg.value; 
        uint256 collected;

        if (state == State.PreSale) {
            collected = preSale_collected.add(msg.value);
            if(collected > preSale_hardCap){
                change = collected.sub(preSale_hardCap);
                amount = amount.sub(change);
            }
            preSale_collected = preSale_collected.add(amount);
            assert(preSale_collected <= preSale_hardCap);
        }else if (state == State.ICO) {
            collected = ICO_collected.add(msg.value);
            if(collected > ICO_hardCap){
                change = collected.sub(ICO_hardCap);
                amount = amount.sub(change);
            }
            ICO_collected = ICO_collected.add(amount);
            assert(ICO_collected <= ICO_hardCap);
        }

        uint256 buyerTokens = calculateTokenAmount(amount);

        contributions[msg.sender] = contributions[msg.sender].add(amount);
        token.mint(msg.sender, buyerTokens);
        TokenPurchase(msg.sender, amount, buyerTokens);              //event for TokenPurchase
        if(change > 0) {
            msg.sender.transfer(change);    
        }
    }

    /**
    * @notice Check if crowdsale is open or not
    */
    function crowdsaleOpen() view public returns(bool){
        return  (state != State.Paused) &&
                (state != State.Finished) &&
                !hardCapReached(state) &&
                !maxDurationReached(state);
    }

    /**
    * @notice Calculates current rate
    * @return rate (which how much tokens will be sent for 1 ETH)
    */
    function currentRate() view public returns(uint256){
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

    /**
    * @notice Calculates current rate for Pre-Sale
    * @return rate (which how much tokens will be sent for 1 ETH)
    */
    function calculatePreSaleRate() view public returns(uint256) {
        uint256 totalWeiCollected = totalCollected();

        uint32 bonusPercent = findCurrentBonusPercent(preSaleBonuses, totalWeiCollected);
        if(bonusPercent > 0){
            return baseRate.add( baseRate.mul(bonusPercent).div(PERCENT_DIVIDER) );
        }else{
            return baseRate;
        }
    }

    /**
    * @notice Calculates current rate for ICO
    * @return rate (which how much tokens will be sent for 1 ETH)
    */
    function calculateICOrate() view public returns(uint256){
        if(ICO_startTimestamp == 0) return 0;
        uint256 totalWeiCollected = totalCollected();

        uint32 bonusPercent = findCurrentBonusPercent(icoBonuses, totalWeiCollected);
        if(bonusPercent > 0){
            return baseRate.add( baseRate.mul(bonusPercent).div(PERCENT_DIVIDER) );
        }else{
            return baseRate;
        }
    }

    /**
    * @notice Calculate amount of tokens to send to investor for specified contribution
    * @dev This is an alias for calculateTokenAmount(uint256) which can be called externally
    * @param contribution Amount of ether received
    * @return Amount of tokens for contribution
    */
    function getTokensForContribution(uint256 contribution) view public returns(uint256) {
        return calculateTokenAmount(contribution);
    }

    /**
    * @dev Calculate amount of tokens to send to investor for specified contribution
    * @param contribution Amount of ether received
    * @return Amount of tokens for contribution
    */
    function calculateTokenAmount(uint256 contribution) view internal returns(uint256) {
        uint256 totalWeiCollected = totalCollected();
        if(state == State.Paused || state == State.Finished) {
            return 0;
        } else if(state == State.PreSale) {
            return calculateTokenAmount(contribution, preSaleBonuses, totalWeiCollected);
        } else if(state == State.ICO){
            return calculateTokenAmount(contribution, icoBonuses, totalWeiCollected);
        } else {
            revert();   //state is wrong
        }
    }

    /**
    * @dev Calculate amount of tokens to send to investor for specified contribution
    * @param contribution Amount of ether received
    * @param bonuses Array of bonus levels
    * @param alreadyCollected How much ether is already collected
    * @return Amount of tokens for contribution
    */
    function calculateTokenAmount(uint256 contribution, Bonus[] storage bonuses, uint256 alreadyCollected) view internal returns(uint256) {
        uint256 amount = contribution;
        uint256 collected = alreadyCollected;
        uint256 tokens = 0;
        uint8 bn;
        //find next threshold
        for(bn = 0; bn < bonuses.length; bn++){
            if(collected < bonuses[bn].threshold) break;
        }
        //iteratively calculate token amount
        while(amount > 0){                      //while there is something not yet converted
            if(bn < bonuses.length){            //if last bonus threshold not reached
                uint256 remainder = bonuses[bn].threshold.sub(collected);
                assert(remainder > 0);
                if(amount <= remainder){        
                    //we do not reach threshold, so just convert and return
                    return tokens.add(calcTokensWithBonus(amount, baseRate, bonuses[bn].percent));
                }else{                          
                    //convert amount up to threshold and go to next iteration
                    tokens = tokens.add(calcTokensWithBonus(remainder, baseRate, bonuses[bn].percent));
                    collected = collected.add(remainder);
                    amount = amount.sub(remainder);
                    bn++;
                }
            }else {
                //no bonus available, so just convert rest amount
                return tokens.add(amount.mul(baseRate));
            }
        }
        revert();   //we should never reach this point
    }

    /**
    * @dev Scan array of bonuses for current bonus level
    * @param bonuses Array of bonuses to scan
    * @param collected How much ether is already collected
    * @return Current bonus percent
    */
    function findCurrentBonusPercent(Bonus[] storage bonuses, uint256 collected) view internal returns(uint32) {
        for(uint8 bn = 0; bn < bonuses.length; bn++){
            if(collected < bonuses[bn].threshold){
                return bonuses[bn].percent;
            }
        }
        return 0;
    }

    /**
    * @dev Calculates how much tokens should be sended for the specified amount of ether
    * NOTE: this does NOT check if moving to next bonus level is required,
    * so caller of this function SHOULD check it
    * @param contribution Amount of ether received
    * @param _baseRate Current rate without bonuses
    * @param bonusPercent Current bonus percent
    * @return Amount of tokens for contribution
    */
    function calcTokensWithBonus(uint256 contribution, uint256 _baseRate, uint32 bonusPercent) pure internal returns (uint256) {
        uint256 baseTokens = contribution.mul(_baseRate);
        uint256 bonus = baseTokens.mul(bonusPercent).div(PERCENT_DIVIDER);
        return baseTokens.add(bonus);
    }

    /**
    * @notice Calculates how much ether is collected
    * @return Amount collected during PreICO and ICO
    */
    function totalCollected() view public returns(uint256){
        return preSale_collected.add(ICO_collected);   //total wei raised in each round
    }

    /**
    * @notice Check if hard cap for the state is reached
    * @param _state State to check
    * @return If hard cap is reached
    */
    function hardCapReached(State _state) view public returns(bool){
        if(_state == State.PreSale) {
            return preSale_collected >= preSale_hardCap;
        }else if(_state == State.ICO){
            return ICO_collected >= ICO_hardCap;
        }else {
            return false;
        }
    }

    /**
    * @notice Check if max duration for the state is reached
    * @param _state State to check
    * @return If hard cap is reached
    */
    function maxDurationReached(State _state) view public returns(bool){
        if(_state == State.PreSale) {
            return (preSale_startTimestamp != 0) && (now > preSale_startTimestamp.add(preSale_maxDuration));
        }else if(_state == State.ICO){
            return (ICO_startTimestamp != 0) && (now > ICO_startTimestamp.add(ICO_maxDuration));
        }else {
            return false;
        }
    }

    /**
    * @notice Change manager address which is allowed to whitelist investors
    * @param _manager Address of new manager
    */
    function setManager(address _manager) onlyOwner public {
        require(_manager != address(0));
        manager = _manager;
    }

    /**
    * @notice Allow/Deny to make purshases from specified address
    * @param who Address which is allowed to make purshase
    * @param allow True if address "who" allowed to purshase. False for revoke previous allowance
    */
    function whitelistAddress(address who, bool allow) public onlyOwnerOrManager {
        whitelist[who] = allow;
    }
    /**
    * @notice Allow to make purshases from specified addresses
    * @param who Array of address which is allowed to make purshase
    */
    function whitelistAddresses(address[] who) public onlyOwnerOrManager {
        for(uint16 i=0; i < who.length; i++){
            whitelist[who[i]] = true;
        }
    }

    /**
    * @notice Owner can change state
    * @param newState New state of the crowdsale
    */
    function setState(State newState) public onlyOwner {
        require(state != State.Finished);                                           //if Finished, no state change possible
        require(newState != State.Finished);                                        //To finish use finishCrowdsale()
        require(!( newState == State.PreSale && ICO_startTimestamp != 0 ));         //Do not allow switch from ICO to PreSale
        require(!( newState == State.ICO && totalCollected() < preSale_hardCap ));  //Do not allow switch to ICO if PreSale cap not raised    

        if(newState == State.PreSale && preSale_startTimestamp == 0) {
            preSale_startTimestamp = now;
        }else if(newState == State.ICO && ICO_startTimestamp == 0) {
            ICO_startTimestamp = now;
        }
        state = newState;
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
    function refundAvailable(address beneficiary) view public returns(uint256){
        if(state != State.Finished) return 0;
        if(totalCollected() >= goal) return 0;
        return contributions[beneficiary];
    }

}


