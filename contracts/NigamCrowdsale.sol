pragma solidity ^0.4.0;

import './zeppelin/ownership/Ownable.sol';
import './NigamCoin.sol';

contract NigamCrowdsale is Ownable, HasNoTokens{
    using SafeMath for uint256;
    using SafeMath for uint8;

    NigamCoin public token;                         //token for crowdsale
    uint256   public totalEthRaised;                //total ETH amount raised

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
    uint256   public daysPassed;                    //days passed since ICO start datetime (86,400 sec intervals)

    uint8     public ownersPercent;                 //percent of tokens that will be minted to owner during the sale

    enum State { Paused, FirstPreSale, SecondPreSale, ICO, Finished }
    State public state;                             //current state of the contract


    /**
    * event for token purchase logging
    * @param purchaser who paid for the tokens
    * @param value weis paid for purchase
    * @param amount amount of tokens purchased
    */
    event TokenPurchase(address indexed purchaser, uint256 value, uint256 amount);


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

        ownersPercent = _ownersPercent;     //whole number that will be divided by 100 later
        token = new NigamCoin();            //creating token in constructor
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
        require(etherAmount >= 100 finney);                   //minimum contribution 0.1 ETH
        uint8 bonusPercentage = 75;                           //75% of baseTokens awarded as bonus
        uint256 rate = etherAmount.div(basePriceWei);      //convert etherAmount to wei and divide by price per token (in wei)
        uint256 bonus = rate.mul(bonusPercentage).div(100);   //divide by 100 to convert bonusPercentage to percent 
        rate = rate.add(bonus);                               //add bonus tokens to base rate
        return rate;
    }

    function calculatePreSaleTwoRate(uint256 etherAmount, uint256 basePriceWei) constant returns(uint256) {
        require(etherAmount >= 100 finney);                 //minimum contribution 0.1 ETH
        uint8 bonusPercentage;                              //bonus percent of tokens awarded for ETH sent
        uint256 rate = etherAmount.div(basePriceWei);      //convert etherAmount to wei and divide by price per token (in wei)
        if(etherAmount >= 10 ether) {                 //$500,000 or or 1667 ether
            bonusPercentage = 50;                       //50% of baseTokens awarded
        }
        else if(etherAmount >= 9 ether) {            //$400,000 or 1333 ether
            bonusPercentage = 45;                       //45% of baseTokens awarded
        }
        else if(etherAmount >= 8 ether) {             //$300,000 or 1000 ether
            bonusPercentage = 40;                       //40% of baseTokens awarded
        }
        else if(etherAmount >= 7 ether) {             //$200,000 or 667 ether
            bonusPercentage = 35;                       //35% of baseTokens awarded
        }
        else if(etherAmount >= 6 ether) {             //$100,000 or 333 ether
            bonusPercentage = 30;                       //30% of baseTokens awarded
        }
        else if(etherAmount >= 5 ether) {             //$50,000 or 167 ether
            bonusPercentage = 29;                       //29% of baseTokens awarded
        }
        else if(etherAmount >= 4 ether) {             //$40,000 or 133 ether
            bonusPercentage = 28;                       //28% of baseTokens awarded
        }
        else if(etherAmount >= 3 ether) {              //$30,000 or 100 ether
            bonusPercentage = 27;                       //27% of baseTokens awarded
        }
        else if(etherAmount >= 2 ether) {              //$20,000 or 67 ether
            bonusPercentage = 26;                       //26% of baseTokens awarded
        }
        else if(etherAmount >= 1 ether) {              //$10,000 or 33 ether
            bonusPercentage = 25;                       //25% of baseTokens awarded
        }
        else {
            bonus = 0;                              //no bonus for anything less than $10,000
        }               
        uint256 bonus = rate.mul(bonusPercentage).div(100);   //divide by 100 to convert bonusPercentage to percent 
        rate = rate.add(bonus);                               //add bonus tokens to base rate
        return rate;
    }

    function calculateICOrate(uint256 etherAmount, uint256 basePriceWei) constant returns(uint256){
        if(ICO_startTimestamp == 0 || now < ICO_startTimestamp) return 0;
        require(etherAmount >= 100 finney);                             //minimum contribution 0.1 ETH
        uint256 rate = etherAmount.div(basePriceWei);      //convert etherAmount to wei and divide by price per token (in wei)
        uint256 saleRunningSeconds = now - ICO_startTimestamp;
        daysPassed = saleRunningSeconds.div(bonusDecreaseInterval);     //remainder will be discarded (bonusDecreaaseInterval = 86400 seconds)
        uint256 bonusPercentage;                                        //bonus percent of tokens handed per ETH received
        if(daysPassed <= 0) {                
            bonusPercentage = 2500;                   //Day1 - 25% of baseTokens awarded
        }
        else if(daysPassed <= 1) {           
            bonusPercentage = 2400;                   //Day2 - 24% of baseTokens awarded
        }
        else if(daysPassed <= 2) {          
            bonusPercentage = 2300;                   //Day3 - 23% of baseTokens awarded
        }
        else if(daysPassed <= 3) {           
            bonusPercentage = 2200;                   //Day4 - 22% of baseTokens awarded
        }
        else if(daysPassed <= 4) {           
            bonusPercentage = 2100;                   //Day5 - 21% of baseTokens awarded
        }
        else if(daysPassed <= 5) {            
            bonusPercentage = 2000;                   //Day6 - 20% of baseTokens awarded
        }
        else if(daysPassed <= 6) {            
            bonusPercentage = 1900;                   //Day7 - 19% of baseTokens awarded
        }
        else if(daysPassed <= 7) {            
            bonusPercentage = 1800;                   //Day8 - 18% of baseTokens awarded
        }
        else if(daysPassed <= 8) {            
            bonusPercentage = 1700;                   //Day9 - 17% of baseTokens awarded
        }
        else if(daysPassed <= 9) {            
            bonusPercentage = 1600;                   //Day10 - 16% of baseTokens awarded
        }
        else if(daysPassed <= 10) {           
            bonusPercentage = 1500;                   //Day11 - 15% of baseTokens awarded
        }
        else if(daysPassed <= 11) {           
            bonusPercentage = 1400;                   //Day12 - 14% of baseTokens awarded
        }
        else if(daysPassed <= 12) {           
            bonusPercentage = 1300;                   //Day13 - 13% of baseTokens awarded
        }
        else if(daysPassed <= 13) {           
            bonusPercentage = 1200;                   //Day14 - 12% of baseTokens awarded
        }
        else if(daysPassed <= 14) {            
            bonusPercentage = 1100;                   //Day15 - 11% of baseTokens awarded
        }
        else if(daysPassed <= 15) {            
            bonusPercentage = 1000;                   //Day16 - 10% of baseTokens awarded
        }
        else if(daysPassed <= 16) {            
            bonusPercentage = 900;                    //Day17 - 9% of baseTokens awarded
        }
        else if(daysPassed <= 17) {            
            bonusPercentage = 800;                    //Day18 - 8% of baseTokens awarded
        }
        else if(daysPassed <= 18) {            
            bonusPercentage = 700;                    //Day19 - 7% of baseTokens awarded
        }
        else if(daysPassed <= 19) {          
            bonusPercentage = 600;                    //Day20 - 6% of baseTokens awarded
        }
        else if(daysPassed <= 20) {           
            bonusPercentage = 500;                    //Day21 - 5% of baseTokens awarded
        }
        else if(daysPassed <= 21) {           
            bonusPercentage = 400;                    //Day22 - 4% of baseTokens awarded
        }
        else if(daysPassed <= 22) {           
            bonusPercentage = 300;                    //Day23 - 3% of baseTokens awarded
        }
        else if(daysPassed <= 23) {            
            bonusPercentage = 200;                    //Day24 - 2% of baseTokens awarded
        }
        else if(daysPassed <= 24) {            
            bonusPercentage = 100;                    //Day25 - 1% of baseTokens awarded
        }
        else {
            bonus = 0;                                //no bonus after 25th day
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
    function totalEthRaised() constant returns(uint256){
        totalEthRaised = preSale1WeiCollected.add(preSale2WeiCollected).add(ICO_WeiCollected).div(1000000000000000000);   //adding wei raised in each round together and converting to ETH
    }
    /**
    * @notice Owner can claim collected ether
    * @param amount How much ether to take. Please leave enough ether for price updates
    */
    function claim(uint256 amount) onlyOwner {
        require(this.balance >= amount);
        owner.transfer(amount);
    }
}


