pragma solidity ^0.4.0;

import './zeppelin/ownership/Ownable.sol';
import './NigamCoin.sol';
import './TokenTimelockMod.sol';

contract NigamCrowdsale is Ownable, HasNoTokens{
    using SafeMath for uint256;
    using SafeMath for uint8;

    NigamCoin public token;                         //token for crowdsale

    uint256   public preSale1_startTimestamp;       //when Presale 1 started uint256 public
    uint256   public preSale1BasePriceInWei;        //price in wei
    uint256   public preSale1EthHardCap;            //hard cap for Round 1 presale in ETH  
    uint256   public preSale1WeiCollected;          //how much wei already collected at pre-sale 1
    uint256   public preSale1_endTimestamp;         //when Presale 1 ends uint256 public

    uint256   public preSale2_startTimestamp;       //when Presale 2 started uint256 public
    uint256   public preSale2BasePriceInWei;        //price in wei
    uint256   public preSale2EthHardCap;            //hard cap for Round 2 presale in ether  
    uint256   public preSale2WeiCollected;          //how much wei already collected at pre-sale 2
    uint256   public preSale2_endTimestamp;         //when Presale 2 ends uint256 public

    uint256   public ICO_startTimestamp;            //when ICO sale started uint256 public
    uint256   public ICO_basePriceInWei;            //price in wei
    uint256   public ICO_EthHardCap;                //hard cap for the main sale round in ETH
    uint256   public ICO_WeiCollected;              //how much wei already collected at main sale
    uint256   public ICO_endTimestamp;              //when Presale 2 ends uint256 public
    uint256   public bonusDecreaseInterval;         //seconds before bonus decreases uint32
    uint256   public daysPassed;                    //days passed since ICO start datetime (86,400 sec/day)

    uint8     public ownersPercent;                 //percent of tokens that will be minted to owner

    uint64[]  reserveReleases;                      //lockup periods per address
    uint256[] reserveAmounts;                       //lockup amounts per address
    address[] reserveBeneficiaries;                 //lockup addresses 

    enum State { Paused, FirstPreSale, SecondPreSale, ICO, Finished }
    State public state;                             //current state of the contract


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


    function NigamCrowdsale(
        uint256 _preSale1BasePriceInWei, uint256 _preSale1EthHardCap,
        uint256 _preSale2BasePriceInWei, uint256 _preSale2EthHardCap,
        uint256 _ICO_basePriceInWei, uint256 _ICO_EthHardCap, uint256 _bonusDecreaseInterval,
        uint8 _ownersPercent
        ){
        state = State.Paused;
        preSale1BasePriceInWei = _preSale1BasePriceInWei;             
        preSale1EthHardCap = _preSale1EthHardCap;          
        preSale2BasePriceInWei = _preSale2BasePriceInWei;             
        preSale2EthHardCap = _preSale2EthHardCap;                   
        ICO_basePriceInWei = _ICO_basePriceInWei;                        
        ICO_EthHardCap = _ICO_EthHardCap;                      
        bonusDecreaseInterval = _bonusDecreaseInterval;
        ownersPercent = _ownersPercent;     
        token = new NigamCoin();                    //creating token in constructor
    }

    /**
    * @notice To buy tokens just send ether here
    */
    function() payable {
        require(msg.value > 0);
        require(crowdsaleOpen());
        uint256 rate = currentRate(msg.value);
        assert(rate > 0);
        uint256 buyerTokens = rate.mul(msg.value);
        uint256 ownerTokens = buyerTokens.mul(ownersPercent).div(100);  //convert ownersPercent to percent by dividing it by 100
        token.mint(msg.sender, buyerTokens);
        token.mint(owner, ownerTokens);
        TokenPurchase(msg.sender, msg.value, buyerTokens);              //event for TokenPurchase
        if (state == State.FirstPreSale) {
            preSale1WeiCollected = preSale1WeiCollected.add(msg.value);
        }else if (state == State.SecondPreSale) {
            preSale2WeiCollected = preSale2WeiCollected.add(msg.value);
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
    function crowdsaleOpen() constant returns(bool){
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
        if(state == State.FirstPreSale) {
            rate = calculatePreSaleOneRate(etherAmount, preSale1BasePriceInWei);
        } else if(state == State.SecondPreSale) {
            rate = calculatePreSaleTwoRate(etherAmount, preSale2BasePriceInWei);
        } else if(state == State.ICO){
            rate = calculateICOrate(etherAmount, ICO_basePriceInWei);
        } else {
            revert();   //state is wrong
        }
        return rate;
    }

    function calculatePreSaleOneRate(uint256 etherAmount, uint256 basePriceWei) constant returns(uint256) {
        require(etherAmount >= 100 finney);                     //minimum contribution 0.1 ETH
        uint8 bonusPercentage = 75;                             //75% of baseTokens awarded as bonus
        uint256 rate = etherAmount.div(basePriceWei);           //convert etherAmount to wei and divide by price per token (in wei)
        uint256 bonus = rate.mul(bonusPercentage).div(100);     //divide by 100 to convert bonusPercentage to percent 
        rate = rate.add(bonus);                                 //add bonus tokens to base rate
        return rate;
    }

    function calculatePreSaleTwoRate(uint256 etherAmount, uint256 basePriceWei) constant returns(uint256) {
        require(etherAmount >= 100 finney);                 //minimum contribution 0.1 ETH
        uint8 bonusPercentage;                              //bonus percent of tokens awarded for ETH sent
        uint256 rate = etherAmount.div(basePriceWei);       //convert etherAmount to wei and divide by price per token (in wei)
        if(etherAmount >= 500 ether) {                  //$500,000 or or 500 ether
            bonusPercentage = 50;                       //50% of baseTokens awarded
        }
        else if(etherAmount >= 400 ether) {             //$400,000 or 400 ether
            bonusPercentage = 45;                       //45% of baseTokens awarded
        }
        else if(etherAmount >= 300 ether) {             //$300,000 or 300 ether
            bonusPercentage = 40;                       //40% of baseTokens awarded
        }
        else if(etherAmount >= 200 ether) {             //$200,000 or 200 ether
            bonusPercentage = 35;                       //35% of baseTokens awarded
        }
        else if(etherAmount >= 100 ether) {             //$100,000 or 100 ether
            bonusPercentage = 30;                       //30% of baseTokens awarded
        }
        else if(etherAmount >= 50 ether) {              //$50,000 or 50 ether
            bonusPercentage = 29;                       //29% of baseTokens awarded
        }
        else if(etherAmount >= 40 ether) {              //$40,000 or 40 ether
            bonusPercentage = 28;                       //28% of baseTokens awarded
        }
        else if(etherAmount >= 30 ether) {              //$30,000 or 30 ether
            bonusPercentage = 27;                       //27% of baseTokens awarded
        }
        else if(etherAmount >= 20 ether) {              //$20,000 or 20 ether
            bonusPercentage = 26;                       //26% of baseTokens awarded
        }
        else if(etherAmount >= 10 ether) {              //$10,000 or 10 ether
            bonusPercentage = 25;                       //25% of baseTokens awarded
        }
        else {
            bonusPercentage = 0;                        //no bonus for anything less than $10,000
        }               
        uint256 bonus = rate.mul(bonusPercentage).div(100);   //divide by 100 to convert bonusPercentage to percent 
        rate = rate.add(bonus);                               //add bonus tokens to base rate
        return rate;
    }

    function calculateICOrate(uint256 etherAmount, uint256 basePriceWei) constant returns(uint256){
        if(ICO_startTimestamp == 0 || now < ICO_startTimestamp) return 0;
        require(etherAmount >= 10 finney);                                     //minimum contribution 0.01 ETH
        uint256 rate = etherAmount.div(basePriceWei);                           //convert etherAmount to wei and divide by price per token (in wei)
        uint256 saleRunningSeconds = now - ICO_startTimestamp;
        daysPassed = saleRunningSeconds.div(bonusDecreaseInterval);             //remainder will be discarded (bonusDecreaaseInterval = 86400 seconds)
        uint256 startBonusPercentage = 2500;                                    //bonus percent of tokens handed on Day 1 (* 100)
        uint256 bonusPercentage = startBonusPercentage.sub(100.mul(daysPassed));   //1% decrease in bonusTokens per day
        if (bonusPercentage < 0) {
            bonusPercentage = 0;
        }
        uint256 bonus = rate.mul(bonusPercentage).div(10000);   //divide by 10,000 to convert bonusPercentage to percent 
        rate = rate.add(bonus);                                 //add bonus tokens to base rate
        return rate;
    }

    function hardCapReached(State _state) constant returns(bool){
        if(_state == State.FirstPreSale) {
            return preSale1WeiCollected >= preSale1EthHardCap.mul(1000000000000000000);
        }else if(_state == State.SecondPreSale) {
            return preSale2WeiCollected >= preSale2EthHardCap.mul(1000000000000000000);
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
            token.finishMinting();
            token.transferOwnership(owner);
        }else if(newState == State.FirstPreSale && preSale1_startTimestamp == 0) {
            preSale1_startTimestamp = now;
        }else if(newState == State.SecondPreSale && preSale2_startTimestamp == 0) {
            preSale2_startTimestamp = now;
        }else if(newState == State.ICO && ICO_startTimestamp == 0) {
            ICO_startTimestamp = now;
        }
        state = newState;
    }
    function totalEthRaised() returns(uint256){
        uint256 totalEthRaised = preSale1WeiCollected.add(preSale2WeiCollected).add(ICO_WeiCollected);   //total wei raised in each round
        return totalEthRaised;
    }
    /**
    * @notice Owner can claim collected ether
    * @param amount How much ether to take. Please leave enough ether for price updates
    */
    function claim(uint256 amount) onlyOwner {
        require(this.balance >= amount);
        owner.transfer(amount);
    }

    function initReserve(uint64[] reserveReleases, uint256[] reserveAmounts, address[] reserveBeneficiaries) internal {
        require(reserveReleases.length == reserveAmounts.length && reserveReleases.length == reserveBeneficiaries.length);
        for(uint8 i=0; i < reserveReleases.length; i++){
            require(reserveReleases[i] > now);
            require(reserveAmounts[i] > 0);
            require(reserveBeneficiaries[i] != address(0));
            TokenTimelock tt = new TokenTimelock(token, reserveBeneficiaries[i], reserveReleases[i]);
            assert(token.mint(tt, reserveAmounts[i]));
            TokenTimelockCreated(tt, reserveReleases[i], reserveBeneficiaries[i], reserveAmounts[i]);
        }
    }


}


