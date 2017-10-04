pragma solidity ^0.4.0;

import './zeppelin/ownership/Ownable.sol';
// import './oraclizeAPI_mod.sol';
import './NigamCoin.sol';
// import './zeppelin/math/SafeMath.sol';

contract NigamCrowdsale is Ownable, HasNoTokens {
    using SafeMath for uint256;
    using SafeMath for uint8;

    NigamCoin public token;     //token for crowdsale
    uint256 public constant ethPrice = 300;    //ETHUSD price in $0.00001, will be set by Oraclize, example: if 1 ETH = 295.14000 USD, then ethPrice = 29514000

    uint256   public preSale1BasePrice;       //price in cents
    // uint8     public preSale1BonusSchedule;   //bonus percents
    // uint256   public preSale1BonusLimits;     //limits to apply bonuses
    uint256   public preSale1EthHardCap;      //hard cap for Round 1 presale in ether  
    uint256   public preSale1EthCollected;    //how much ether already collected at pre-sale 1

    uint256   public preSale2BasePrice;       //price in cents
    // uint8     public preSale2BonusSchedule;   //bonus percents
    // uint256   public preSale2BonusLimits;     //limits to apply bonuses
    uint256   public preSale2EthHardCap;      //hard cap for Round 2 presale in ether  
    uint256   public preSale2EthCollected;    //how much ether already collected at pre-sale 2


    uint256   public saleBasePrice;                 //price in cents uint32  public
    uint32    public salePriceIncreaseInterval;     //seconds before price increase uint32
    uint32    public salePriceIncreaseAmount;       //amount to increase price to (in cents)
    uint256   public saleEthHardCap;                //hard cap for the main sale round in ether
    uint256   public saleStartTimestamp;            //when sale started uint256 public
    uint256   public saleEthCollected;              //how much ether already collected at main sale

    uint8 ownersPercent;              //percent of tokens that will be minted to owner during the sale

    enum State { Paused, FirstPreSale, SecondPreSale, Sale, Finished }
    State public state;                  //current state of the contract



    uint32 public oraclizeUpdateInterval = 60;  //update price interval in seconds

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


    function NigamCrowdsale(NigamCoin _token, 
        uint256 _preSale1BasePrice, uint256 _preSale1EthHardCap,
        uint256 _preSale2BasePrice, uint256 _preSale2EthHardCap,
        uint256 _saleBasePrice, uint32 _salePriceIncreaseInterval, uint32 _salePriceIncreaseAmount, uint256 _saleEthHardCap,
        uint8 _ownersPercent
        ){
        state = State.Paused;

        uint8 i;

        // assert(_preSale1BonusSchedule.length == 5 && _preSale1BonusSchedule.length == _preSale1BonusLimits.length);
        preSale1BasePrice = _preSale1BasePrice;             //0.0016667 or 1/600 ETH
        //preSale1BonusSchedule = _preSale1BonusSchedule;     //[5, 10, 15, 25, 50];    
        // for(i=0; i< _preSale1BonusSchedule.length; i++) preSale1BonusSchedule[i] = _preSale1BonusSchedule[i];
        //preSale1BonusLimits   = _preSale1BonusLimits;       //[4 ether, 10 ether, 15 ether, 25 ether, 100 ether];
        // for(i=0; i< _preSale1BonusLimits.length; i++) preSale1BonusLimits[i] = _preSale1BonusLimits[i];
        preSale1EthHardCap = _preSale1EthHardCap;           //1666.67 ether;
        // assert(preSale1BonusSchedule.length == preSale1BonusLimits.length);

        // assert(preSale2BonusSchedule.length == 5 && _preSale2BonusSchedule.length == _preSale2BonusLimits.length);
        preSale2BasePrice = _preSale2BasePrice;             //0.0025 or 1/400 ETH;
        //preSale2BonusSchedule = _preSale2BonusSchedule;     //[1, 3, 5, 8, 25]
        // for(i=0; i< _preSale2BonusSchedule.length; i++) preSale2BonusSchedule[i] = _preSale2BonusSchedule[i];
        //preSale2BonusLimits = _preSale2BonusLimits;         //[500 ether, 1000 ether, 2500 ether, 5000 ether, 1000 ether];
        // for(i=0; i< _preSale2BonusLimits.length; i++) preSale2BonusLimits[i] = _preSale2BonusLimits[i];
        preSale2EthHardCap = _preSale2EthHardCap;                   //16666.67 ether;

        saleBasePrice = _saleBasePrice;                         //0.003333 or 1/300 ETH;
        salePriceIncreaseInterval = _salePriceIncreaseInterval;   //24*60*60; //1 day
        salePriceIncreaseAmount = _salePriceIncreaseAmount;     //0.00066667 or 1/1500 ETH;
        saleEthHardCap = _saleEthHardCap;                       //166666.67 ether;

        ownersPercent = _ownersPercent;   //whole number that will be divided by 100 later

        //token = new NigamCoin();
        token = _token;
        //assert(token.delegatecall( bytes4(keccak256("transferOwnership(address)")), this));
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
        TokenPurchase(msg.sender, msg.value, buyerTokens);
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
            rate = calculatePreSaleRateOne(etherAmount, preSale1BasePrice);
        } else if(state == State.SecondPreSale) {
            rate = calculatePreSaleRateTwo(etherAmount, preSale2BasePrice);
        } else if(state == State.Sale){
            rate = calculateSaleRate();
        } else {
            revert();   //state is wrong
        }
        return rate;
    }
    function calculatePreSaleRateOne(uint256 etherAmount, uint256 basePrice) constant returns(uint256) {
        require(etherAmount >= 2 ether);                //minimum contribution 2 ETH
        uint8 bonusPercentage;
        uint256 rate = ethPrice.div(basePrice);  //calculate initial number of tokens for ETH sent
        if(etherAmount >= 100 ether) {       //100 ETH
            bonusPercentage = 50;             //50% of baseTokens awarded
        }
        if(etherAmount >= 25 ether) {        //25 ETH
            bonusPercentage = 25;             //25% of baseTokens awarded
        }
        if(etherAmount >= 15 ether) {        //15 ETH 
            bonusPercentage = 15;             //15% of baseTokens awarded
        }
        if(etherAmount >= 10 ether) {        //10 ETH 
            bonusPercentage = 10;             //10% of baseTokens awarded
        }
        if(etherAmount >= 4 ether) {         //4 ETH 
            bonusPercentage = 5;              //5% of baseTokens awarded
        }         
        uint256 bonus = rate.mul(bonusPercentage.div(100));   //divide by 100 to put in percent
        rate = rate.add(bonus);
        return rate;
    }

    function calculatePreSaleRateTwo(uint256 etherAmount, uint256 basePrice) constant returns(uint256) {
        uint8 bonusPercentage;        
        uint256 rate = ethPrice.div(basePrice);       //calculate initial number of tokens for ETH sent
        if(etherAmount >= 10000 ether) {       //10000 ETH
            bonusPercentage = 25;               //25% of baseTokens awarded
        }
        if(etherAmount >= 5000 ether) {     //5000 ETH
            bonusPercentage = 8;             //8% of baseTokens awarded
        }
        if(etherAmount >= 2500 ether) {     //2500 ETH 
            bonusPercentage = 5;             //5% of baseTokens awarded
        }
        if(etherAmount >= 1000 ether) {     //1000 ETH 
            bonusPercentage = 3;             //3% of baseTokens awarded
        }
        if(etherAmount >= 500 ether) {      //500 ETH 
            bonusPercentage = 1;             //1% of baseTokens awarded
        }         
        uint256 bonus = rate.mul(bonusPercentage.div(100));   //divide by 100 to put in percent
        rate = rate.add(bonus);
        return rate;
    }

    function calculateSaleRate() constant returns(uint256){
        if(saleStartTimestamp == 0 || now < saleStartTimestamp) return 0;
        uint256 saleRunningSeconds = now - saleStartTimestamp;
        uint256 passedIntervals = saleRunningSeconds / salePriceIncreaseInterval; //remainder will be discarded
        uint256 price = saleBasePrice.add( passedIntervals.mul(salePriceIncreaseAmount) );
        uint256 rate = ethPrice.div(price);
        return rate;
    }
    function hardCapReached(State _state) constant returns(bool){
        if(_state == State.FirstPreSale) {
            return preSale1EthCollected >= preSale1EthHardCap;
        }else if(_state == State.SecondPreSale) {
            return preSale2EthCollected >= preSale2EthHardCap;
        }else if(_state == State.Sale){
            return saleEthCollected >= saleEthHardCap;
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
        }else if(newState == State.Sale && saleStartTimestamp == 0) {
            saleStartTimestamp = now;
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
    /**
    * @notice Owner can change price update interval
    * @param newOraclizeUpdateInterval Update interval in seconds. Zero will stop updates.
    */
    // function updateInterval(uint32 newOraclizeUpdateInterval) public onlyOwner {
    //     if(oraclizeUpdateInterval == 0 && newOraclizeUpdateInterval > 0){
    //         oraclizeUpdateInterval = newOraclizeUpdateInterval;
    //         updateEthPriceInternal();
    //     }else{
    //         oraclizeUpdateInterval = newOraclizeUpdateInterval;
    //     }
    // }
    /**
    * @notice Owner can do this to start price updates
    * Also, he can put some ether to the contract so that it can pay for the updates
    */
    // function updateEthPrice() public payable onlyOwner{
    //     updateEthPriceInternal();
    // }
    /**
    * @dev Callback for Oraclize
    */
    // function __callback(bytes32 myid, string result, bytes proof) {
    //     require(msg.sender == oraclize_cbAddress());
    //     ethPrice = parseInt(result, 5); //5 makes ethPrice to be price in 0.00001 USD
    //     EthPriceUpdate(ethPrice);
    //     if(oraclizeUpdateInterval > 0){
    //         updateEthPriceInternal();
    //     }
    // }
    // function updateEthPriceInternal() internal {
    //     oraclize_query(oraclizeUpdateInterval, "URL", "json(https://api.kraken.com/0/public/Ticker?pair=ETHUSD).result.XETHZUSD.c.0");
    // }

}


