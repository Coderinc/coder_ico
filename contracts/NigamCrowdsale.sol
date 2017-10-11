pragma solidity ^0.4.0;

import './zeppelin/ownership/Ownable.sol';
// import './oraclize/oraclizeAPI.sol';
import './NigamCoin.sol';

contract NigamCrowdsale is Ownable, HasNoTokens {
    using SafeMath for uint256;
    using SafeMath for uint8;

    NigamCoin public token;                         //token for crowdsale
    uint256   public constant ethPrice = 300;       //ETHUSD price in $0.01 USD, will be set by Oraclize, example: if 1 ETH = 295.14000 USD, then ethPrice = 29514
    uint256   public amountRaised;                  //total amount raised in wei

    uint256   public preSale1_startTimestamp;       //when Presale 1 started uint256 public
    uint256   public preSale1BasePrice;             //price in cents
    uint256   public preSale1DollarHardCap;         //hard cap for Round 1 presale in ether  
    uint256   public preSale1EthCollected;          //how much ether already collected at pre-sale 1
    uint256   public preSale1_endTimestamp;         //when Presale 1 ends uint256 public

    uint256   public preSale2_startTimestamp;       //when Presale 2 started uint256 public
    uint256   public preSale2BasePrice;             //price in cents
    uint256   public preSale2DollarHardCap;         //hard cap for Round 2 presale in ether  
    uint256   public preSale2EthCollected;          //how much ether already collected at pre-sale 2
    uint256   public preSale2_endTimestamp;         //when Presale 2 ends uint256 public

    uint256   public ICO_startTimestamp;            //when ICO sale started uint256 public
    uint256   public ICO_basePrice;                 //price in cents uint32  public
    uint32    public priceIncreaseInterval;         //seconds before price increase uint32
    uint32    public priceIncreaseAmount;           //amount to increase price to (in cents)
    uint256   public ICO_DollarHardCap;             //hard cap for the main sale round in ether
    uint256   public ICO_EthCollected;              //how much ether already collected at main sale
    uint256   public ICO_endTimestamp;              //when Presale 2 ends uint256 public

    uint256   public saleStartTimestamp;            //when sale started uint256 public
    uint8     public ownersPercent;                 //percent of tokens that will be minted to owner during the sale

    enum State { Paused, FirstPreSale, SecondPreSale, ICO, Finished }
    State public state;                             //current state of the contract



    uint32 public oraclizeUpdateInterval = 300;      //update price interval in seconds

    /**
    * event for price update logging
    * @param newEthPrice new price of eth in points, where 1 point = 0.00001 USD
    */
    event EthPriceUpdate(uint256 newEthPrice);

    /**
    * event for token purchase logging
    * @param purchaser who paid for the tokens
    * @param value weis paid for purchase
    * @param amount amount of tokens purchased
    */
    event TokenPurchase(address indexed purchaser, uint256 value, uint256 amount);


    function NigamCrowdsale( 
        uint256 _preSale1BasePrice, uint256 _preSale1DollarHardCap,
        uint256 _preSale2BasePrice, uint256 _preSale2DollarHardCap,
        uint256 _ICO_basePrice, uint256 _ICO_DollarHardCap, uint32 _priceIncreaseInterval, uint32 _priceIncreaseAmount,
        uint8 _ownersPercent
        ){
        state = State.Paused;

        preSale1BasePrice = _preSale1BasePrice;             //0.0016667 or 1/600 ETH
        preSale1DollarHardCap = _preSale1DollarHardCap;           //1666.67 ether;

        preSale2BasePrice = _preSale2BasePrice;             //0.0025 or 1/400 ETH;
        preSale2DollarHardCap = _preSale2DollarHardCap;                   //16666.67 ether;

        ICO_basePrice = _ICO_basePrice;                         //0.003333 or 1/300 ETH;
        priceIncreaseInterval = _priceIncreaseInterval;   //24*60*60; //1 day
        priceIncreaseAmount = _priceIncreaseAmount;     //0.00066667 or 1/1500 ETH;
        ICO_DollarHardCap = _ICO_DollarHardCap;                       //166666.67 ether;

        ownersPercent = _ownersPercent;   //whole number that will be divided by 100 later

        token = new NigamCoin();        //creating token in constructor so that separate token contract doesn't need to be published
        // token = _token;
        // assert(token.delegatecall( bytes4(keccak256("transferOwnership(address)")), this));   //delegate call to transfer ownership of token to crowdsale contract
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
        uint256 ownerTokens = buyerTokens.mul(ownersPercent).div(100); //ownersPercent is percents, so divide to 100
        token.mint(msg.sender, buyerTokens);
        token.mint(owner, ownerTokens);
        TokenPurchase(msg.sender, msg.value, buyerTokens);    //event for TokenPurchase
        if (state == State.FirstPreSale) {
            preSale1EthCollected = preSale1EthCollected.add(msg.value);
        }else if (state == State.SecondPreSale) {
            preSale2EthCollected = preSale2EthCollected.add(msg.value);
        }else if (state == State.ICO) {
            ICO_EthCollected = ICO_EthCollected.add(msg.value);
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
            rate = calculatePreSaleOneRate(etherAmount, preSale1BasePrice);
        } else if(state == State.SecondPreSale) {
            rate = calculatePreSaleTwoRate(etherAmount, preSale2BasePrice);
        } else if(state == State.ICO){
            rate = calculateICOrate();
        } else {
            revert();   //state is wrong
        }
        return rate;
    }
    function calculatePreSaleOneRate(uint256 etherAmount, uint256 basePrice) constant returns(uint256) {
        require(etherAmount >= 2 ether);         //minimum contribution 2 ETH
        uint8 bonusPercentage;
        uint256 rate = ethPrice.div(basePrice).mul(100);  //calculate initial # tokens for ETH sent, convert to cents
        if(etherAmount >= 7 ether) {           //100 ETH
            bonusPercentage = 50;                //50% of baseTokens awarded
        }
        else if(etherAmount >= 6 ether) {            //25 ETH
            bonusPercentage = 25;                //25% of baseTokens awarded
        }
        else if(etherAmount >= 5 ether) {            //15 ETH 
            bonusPercentage = 15;                //15% of baseTokens awarded
        }
        else if(etherAmount >= 4 ether) {            //10 ETH 
            bonusPercentage = 10;                //10% of baseTokens awarded
        }
        else if(etherAmount >= 3 ether) {             //4 ETH 
            bonusPercentage = 5;                 //5% of baseTokens awarded
        }
        else {
            bonus = 0;                           //no bonus for anything less than 4 ETH
        }      
        uint256 bonus = rate.mul(bonusPercentage);   
        rate = rate.add( bonus.div(100) );      //add only the perecentage of bonus (divide by 100)
        return rate;
    }

    function calculatePreSaleTwoRate(uint256 etherAmount, uint256 basePrice) constant returns(uint256) {
        uint8 bonusPercentage;        
        uint256 rate = ethPrice.div(basePrice).mul(100);  //calculate initial # tokens for ETH sent, convert to cents
        if(etherAmount >= 5 ether) {         //10000 ETH
            bonusPercentage = 25;                //25% of baseTokens awarded
        }
        else if(etherAmount >= 4 ether) {         //5000 ETH
            bonusPercentage = 8;                //8% of baseTokens awarded
        }
        else if(etherAmount >= 3 ether) {         //2500 ETH 
            bonusPercentage = 5;                //5% of baseTokens awarded
        }
        else if(etherAmount >= 2 ether) {         //1000 ETH 
            bonusPercentage = 3;                //3% of baseTokens awarded
        }
        else if(etherAmount >= 1 ether) {          //500 ETH 
            bonusPercentage = 1;                //1% of baseTokens awarded
        }
        else {
            bonus = 0;                       //no bonus for anything less than 4 ETH
        }               
        uint256 bonus = rate.mul(bonusPercentage.div(100));   //divide by 100 to put in percent
        rate = rate.add( bonus.div(100) );      //add only the perecentage of bonus (divide by 100)
        return rate;
    }

    function calculateICOrate() constant returns(uint256){
        if(ICO_startTimestamp == 0 || now < ICO_startTimestamp) return 0;
        uint256 saleRunningSeconds = now - ICO_startTimestamp;
        uint256 passedIntervals = saleRunningSeconds / priceIncreaseInterval; //remainder will be discarded
        uint256 price = ICO_basePrice.add( passedIntervals.mul(priceIncreaseAmount) );
        uint256 rate = ethPrice.div(price).mul(100);   //calculate initial # tokens for ETH sent, convert to cents
        return rate;
    }
    function hardCapReached(State state) constant returns(bool){
        if(state == State.FirstPreSale) {
            return preSale1EthCollected >= preSale1DollarHardCap.div(ethPrice);
        }else if(state == State.SecondPreSale) {
            return preSale2EthCollected >= preSale2DollarHardCap.div(ethPrice);
        }else if(state == State.ICO){
            return ICO_EthCollected >= ICO_DollarHardCap.div(ethPrice);    
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
            oraclizeUpdateInterval = 0;
        }else if(newState == State.FirstPreSale && preSale1_startTimestamp == 0) {
            preSale1_startTimestamp = now;
        }else if(newState == State.SecondPreSale && preSale2_startTimestamp == 0) {
            preSale2_startTimestamp = now;
        }else if(newState == State.ICO && ICO_startTimestamp == 0) {
            ICO_startTimestamp = now;
        }
        state = newState;
    }
    /**
    * @notice Owner can claim collected ether
    * @param amount How much ether to take. Please leave enough ether for price updates
    */
    function claim(uint256 amount) onlyOwner {
        require(this.balance >= amount);
        owner.transfer(amount);
    }

    //============================ ORACLIZE ===========================================

    // /**
    // * @notice Owner can change price update interval
    // * @param newOraclizeUpdateInterval Update interval in seconds. Zero will stop updates.
    // */
    // function updateInterval(uint32 newOraclizeUpdateInterval) public onlyOwner {
    //     if(oraclizeUpdateInterval == 0 && newOraclizeUpdateInterval > 0){
    //         oraclizeUpdateInterval = newOraclizeUpdateInterval;
    //         updateEthPriceInternal();
    //     }else{
    //         oraclizeUpdateInterval = newOraclizeUpdateInterval;
    //     }
    // }
    // /**
    // * @notice Owner can do this to start price updates
    // * Also, he can put some ether to the contract so that it can pay for the updates
    // */
    // function updateEthPrice() public payable onlyOwner{
    //     updateEthPriceInternal();
    // }
    // /**
    // * @dev Callback for Oraclize
    // */
    // function __callback(bytes32 myid, string result, bytes proof) {
    //     require(msg.sender == oraclize_cbAddress());
    //     ethPrice = parseInt(result, 2);      //2 makes ethPrice to be price in 0.01 USD
    //    ethPrice = ethPrice.div(100);      //makes ethPrice to be price in 1 USD        
    //     EthPriceUpdate(ethPrice);            //Event for ETH Price Update
    //     if(oraclizeUpdateInterval > 0){
    //         updateEthPriceInternal();
    //     }
    // }
    // function updateEthPriceInternal() internal {
    //     oraclize_query(oraclizeUpdateInterval, "URL", "json(https://api.kraken.com/0/public/Ticker?pair=ETHUSD).result.XETHZUSD.c.0");
    // }
}


