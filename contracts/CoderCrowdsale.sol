pragma solidity ^0.4.18;

import './zeppelin/ownership/Ownable.sol';
import './CoderCoin.sol';
import './TokenTimelockMod.sol';

contract CoderCrowdsale is Ownable, HasNoTokens{
    using SafeMath for uint256;
    using SafeMath for uint8;

    CoderCoin public token;                         //token for crowdsale

    uint256   public preSale_startTimestamp;        //when Presale 1 started uint256 public
    uint256   public preSaleBasePriceInWei;         //price in wei
    uint256   public preSaleEthHardCap;             //hard cap for Round 1 presale in ETH
    uint256   public preSaleWeiCollected;           //how much wei already collected at pre-sale 1
    uint256   public preSale_endTimestamp;          //when Presale 1 ends uint256 public

    uint256   public ICO_startTimestamp;            //when ICO sale started uint256 public
    uint256   public ICO_basePriceInWei;            //price in wei
    uint256   public ICO_EthHardCap;                //hard cap for the main sale round in ETH
    uint256   public ICO_WeiCollected;              //how much wei already collected at main sale
    uint256   public ICO_endTimestamp;              //when Presale 2 ends uint256 public
    uint256   public bonusDecreaseInterval;         //seconds before bonus decreases uint32
    //uint256   public daysPassed;                    //days passed since ICO start datetime (86,400 sec/day)

    uint8     public ownersPercent;                 //percent of tokens that will be minted to owner

    enum State { Paused, PreSale, ICO, Finished }
    State public state;                             //current state of the contracts



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
        uint256 _preSaleBasePriceInWei, uint256 _preSaleEthHardCap,
        uint256 _ICO_basePriceInWei, uint256 _ICO_EthHardCap, uint256 _bonusDecreaseInterval,
        uint8 _ownersPercent
        ) public {
        state = State.Paused;
        preSaleBasePriceInWei = _preSaleBasePriceInWei;
        preSaleEthHardCap = _preSaleEthHardCap;
        ICO_basePriceInWei = _ICO_basePriceInWei;
        ICO_EthHardCap = _ICO_EthHardCap;
        bonusDecreaseInterval = _bonusDecreaseInterval;
        ownersPercent = _ownersPercent;
        token = new CoderCoin();                    //creating token in constructor
    }

    /**
    * @notice To buy tokens just send ether here
    */
    function() payable public {
        require(msg.value > 0);
        require(crowdsaleOpen());
        uint256 rate = currentRate(msg.value);
        assert(rate > 0);
        uint256 buyerTokens = rate.mul(msg.value);
        //uint256 ownerTokens = buyerTokens.mul(ownersPercent).div(100);  //convert ownersPercent to percent by dividing it by 100
        token.mint(msg.sender, buyerTokens);
        //token.mint(owner, ownerTokens);
        TokenPurchase(msg.sender, msg.value, buyerTokens);              //event for TokenPurchase
        if (state == State.PreSale) {
            preSaleWeiCollected = preSaleWeiCollected.add(msg.value);
        }else if (state == State.ICO) {
            ICO_WeiCollected = ICO_WeiCollected.add(msg.value);
        }
        if ( hardCapReached(state) ){
            state = State.Paused;
        }
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
    * @param etherAmount how much ether you are sending
    * @return conversion rate
    */
    function currentRate(uint256 etherAmount) public constant returns(uint256){
        if(state == State.Paused || state == State.Finished) return 0;
        uint256 rate;
        if(state == State.PreSale) {
            rate = calculatePreSaleRate(etherAmount, preSaleBasePriceInWei);
        } else if(state == State.ICO){
            rate = calculateICOrate(etherAmount, ICO_basePriceInWei);
        } else {
            revert();   //state is wrong
        }
        return rate;
    }

    function calculatePreSaleRate(uint256 etherAmount, uint256 basePriceWei) constant public returns(uint256) {
        require(etherAmount >= 100 finney);                     //minimum contribution 0.1 ETH
        uint256 rate = etherAmount.div(basePriceWei);           //convert etherAmount to wei and divide by price per token (in wei)
        uint8 bonusPercentage;                                  //baseTokens awarded as bonus
        uint256 totalWeiCollected = totalEthRaised();
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
        uint256 bonus = rate.mul(bonusPercentage).div(100);     //divide by 100 to convert bonusPercentage to percent
        rate = rate.add(bonus);                                 //add bonus tokens to base rate
        return rate;
    }

    function calculateICOrate(uint256 etherAmount, uint256 basePriceWei) constant public returns(uint256){
        if(ICO_startTimestamp == 0 || now < ICO_startTimestamp) return 0;
        require(etherAmount >= 100 finney);                             //minimum contribution 0.1 ETH
        uint256 rate = etherAmount.div(basePriceWei);                   //convert etherAmount to wei and divide by price per token (in wei)
        uint256 saleRunningSeconds = now - ICO_startTimestamp;
        uint256 daysPassed = saleRunningSeconds.div(bonusDecreaseInterval);     //remainder will be discarded (bonusDecreaaseInterval = 86400 seconds)
        uint256 startBonusPercentage = 2500;                            //bonus percent of tokens handed on Day 1 (* 100)
        uint256 decreaseAmount = 100;                                   //1% decrease in bonusTokens per day
        uint256 bonusPercentage = startBonusPercentage.sub(decreaseAmount.mul(daysPassed));
        if (bonusPercentage < 0) {
            bonusPercentage = 0;
        }
        uint256 bonus = rate.mul(bonusPercentage).div(10000);           //divide by 10,000 to convert bonusPercentage to percent
        rate = rate.add(bonus);                                         //add bonus tokens to base ratee
        return rate;
    }

    function hardCapReached(State _state) constant public returns(bool){
        if(_state == State.PreSale) {
            return preSaleWeiCollected >= preSaleEthHardCap.mul(1000000000000000000);
        }else if(_state == State.ICO){
            return ICO_WeiCollected >= ICO_EthHardCap.mul(1000000000000000000);
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

    function totalEthRaised() constant public returns(uint256){
        return preSaleWeiCollected.add(ICO_WeiCollected);   //total wei raised in each round
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
            require(reservePercents[i] <= 100);
            beneficiaryPercent += reservePercents[i];
            require(beneficiaryPercent <= 100);
        }
        uint8 ownerPercent2 = 100 - beneficiaryPercent;

        uint256 totalTokens = token.totalSupply().mul(ownersPercent).div(100);
        for(i=0; i < reserveBeneficiaries.length; i++){
            uint256 amount = totalTokens.mul(reservePercents[i]).div(100);
            require(reserveReleases[i] > now);
            require(reserveBeneficiaries[i] != address(0));
            //TokenTimelock tt = new TokenTimelock(token, reserveBeneficiaries[i], reserveReleases[i]);
            TokenTimelockMod tt = new TokenTimelockMod(reserveReleases[i]);
            tt.transferOwnership(reserveBeneficiaries[i]);
            assert(token.mint(tt, amount));
            TokenTimelockCreated(tt, reserveReleases[i], reserveBeneficiaries[i], amount);
        }

        amount = totalTokens.mul(ownerPercent2).div(100);
        token.mint(owner, amount);

        token.finishMinting();
        token.transferOwnership(owner);
        state = State.Finished;
    }

}


