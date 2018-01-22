pragma solidity ^0.4.18;

import './zeppelin/ownership/Ownable.sol';
import './CoderCoin.sol';
import './TokenTimelockMod.sol';

contract CoderCrowdsale is Ownable, HasNoTokens{
    using SafeMath for uint256;
    
    uint8 private constant PERCENT_DIVIDER = 100;              

    uint256 public constant minContribution = 100 finney;   //we do not accept contributions lower than this value

    CoderCoin public token;                         //token for crowdsale

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

    uint8     public foundersPercent;                 //percent of tokens that will be minted to founders (including timelocks)

    enum State { Paused, PreSale, ICO, Finished }
    State public state;                             //current state of the contracts

    mapping(address => bool) whitelist;


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
        uint256 _preSale_baseRate, uint256 _preSale_hardCap, uint256 _ICO_baseRate, uint256 _ICO_hardCap,
        uint8 _ICO_bonusStartPercent, uint32 _ICO_bonusDecreaseInterval, uint8 _ICO_bonusDecreasePercent,
        uint8 _foundersPercent
        ) public {

        require(_preSale_baseRate > 0);
        require(_preSale_hardCap > 0);
        require(_ICO_baseRate > 0);
        require(_ICO_hardCap > 0);
        require(_ICO_bonusDecreaseInterval > 0);
        require(_ICO_bonusStartPercent > 0 && _ICO_bonusStartPercent <= PERCENT_DIVIDER);
        require(_ICO_bonusDecreasePercent > 0 && _ICO_bonusDecreasePercent < _ICO_bonusStartPercent);
        
        state = State.Paused;
        preSale_baseRate = _preSale_baseRate;
        preSale_hardCap = _preSale_hardCap;
        ICO_baseRate = _ICO_baseRate;
        ICO_hardCap = _ICO_hardCap;
        ICO_bonusDecreaseInterval = _ICO_bonusDecreaseInterval;
        ICO_bonusStartPercent = _ICO_bonusStartPercent;
        ICO_bonusDecreasePercent = _ICO_bonusDecreasePercent;

        foundersPercent = _foundersPercent;

        token = new CoderCoin();                    //creating token in constructor
    }

    /**
    * @notice To buy tokens just send ether here
    */
    function() payable public {
        require(msg.value >= minContribution);
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
        }

        token.mint(msg.sender, buyerTokens);
        TokenPurchase(msg.sender, msg.value, buyerTokens);              //event for TokenPurchase
    }

    /**
    * @notice Check if crowdsale is open or not
    */
    function crowdsaleOpen() constant public returns(bool){
        return  (state != State.Paused) &&
                (state != State.Finished) &&
                !hardCapReached(state);
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
        uint8 bonusPercentage;                                  //baseTokens awarded as bonus
        uint256 totalWeiCollected = totalCollected();
        if(totalWeiCollected < 500 ether) {                          
            bonusPercentage = 75;                               //75% bonus tokens awarded for first 500 ETH
        }
        else if(totalWeiCollected < 1000 ether) {
            bonusPercentage = 50;                               //50% bonus tokens awarded for next 500 ETH (total 1000 ETH)
        }
        else if(totalWeiCollected < 2000 ether) {
            bonusPercentage = 45;                               //45% bonus tokens awarded for next 1000 ETH (total 2000 ETH)
        }
        else if(totalWeiCollected < 3000 ether) {
            bonusPercentage = 40;                               //40% bonus tokens awarded for next 1000 ETH (total 3000 ETH)
        }
        else if(totalWeiCollected < 4000 ether) {
            bonusPercentage = 35;                               //35% bonus tokens awarded for next 1000 ETH (total 4000 ETH)
        }
        else {
            bonusPercentage = 30;                               //30% bonus tokens awarded for last 1000 ETH (total 5000 ETH)                   
        }
        uint256 rate = preSale_baseRate;
        uint256 bonus = rate.mul(bonusPercentage).div(PERCENT_DIVIDER); //divide by 100 to convert bonusPercentage to percent
        rate = rate.add(bonus);                                 //add bonus tokens to base rate
        return rate;
    }

    function calculateICOrate() constant public returns(uint256){
        if(ICO_startTimestamp == 0 || now < ICO_startTimestamp) return 0;
        uint256 rate = ICO_baseRate;
        uint256 saleRunningSeconds = now - ICO_startTimestamp;
        uint256 daysPassed = saleRunningSeconds.div(ICO_bonusDecreaseInterval); //remainder will be discarded

        uint256 decreaseBonusPercent = ICO_bonusDecreasePercent * daysPassed;
        assert(decreaseBonusPercent / daysPassed == ICO_bonusDecreasePercent); //SafeMath doesn't work with uint8 so check this manualy
        uint256 bonusPercentage = (ICO_bonusStartPercent > decreaseBonusPercent) ? (ICO_bonusStartPercent - decreaseBonusPercent) : 0;
        assert(bonusPercentage <= PERCENT_DIVIDER);

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


    function whitelistAddress(address who, bool allow) public {
        whitelist[who] = allow;
    }
    function whitelistAddresses(address[] who) public {
        for(uint32 i=0; i < who.length; i++){
            whitelist[who[i]] = true;
        }
    }


}


