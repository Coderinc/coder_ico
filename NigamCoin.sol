pragma solidity ^0.4.11;

import "./installed_contracts/zeppelin/token/StandardToken.sol";

import "./KrakenPriceTicker.sol";


contract NigamCoin is StandardToken {
    
    using SafeMath for uint256;
  
    string public symbol = 'NGM';

    string public name = 'NigamCoin';
    
    uint8 public constant decimals = 18;
    
    uint256 public tokensPerEther;

    uint256 public etherPriceInUSD = 300;    //how to make dynamic?
    
    uint256 public weiPrice = etherPrice.safeDiv(1000000000000000000);    //etherPrice safeDivided by 10^(18)

    uint256 public _totalSupply = 99999999 ether;

    uint256 public tokenPriceInUSD = 1.safeDiv(2);   //TOKEN Price in USD

    uint256 public tokensPerETH = etherPriceInUSD.safeDiv(tokenPriceInUSD);     //TOKENS PER ETH

    uint256 public tokenPriceInETH = 1.safeDiv(tokensPerETH)            //TOKEN PRICE PER ETH
    
    uint256 public totalContribution = 0;

    uint256 public constant dollarCap = 55500000;          //ICO cap in USD

    uint256 public constant contributionCapinEther = dollarCap.safeDiv(etherPrice);    //ICO cap in ETH

    uint256 public constant contributionCapinWei = dollarCap.safeDiv(etherPrice).safeMul(1000000000000000000);     //ICO cap in wei

    uint256 public contributionInDollars;   //msg.sender's contribution in USD
    
    uint256 public bonusSupply = 0;
    
    bool public purchasingAllowed = false;
    
    uint8 public currentSaleDay = 1; 

    uint8 public bonusPercentage;
    
    string public startDate = '2017-10-01 18:00';
    
    address public owner;
    
    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }
    
    mapping(address => uint256) balances;
    mapping (address => mapping (address => uint256)) public allowed;
    
    function NigamCoin() {
        owner = msg.sender;
        balances[msg.sender] = _totalSupply;
    }
    
    function changeStartDate(string _startDate){
        require(
            msg.sender==owner
        );
        startDate = _startDate;
    }
    
    function totalSupply() constant returns (uint256 totalSupply) {
        return _totalSupply;
    }
   
    function getStats() constant returns (uint256, uint256, uint256,  bool, uint256, uint256, string) {
        return (totalContribution, _totalSupply, bonusSupply, purchasingAllowed, currentSaleDay, currentBonus, startDate);
    }
    
    function transferOwnership(address _newOwner) onlyOwner {
        owner = _newOwner;
    }
    
     function rebrand(string _symbol, string _name) onlyOwner {
        symbol = _symbol;
        name   = _name;
     }

    
    function withdraw() onlyOwner {
        owner.transfer(this.balance);
    }
    /* 
     * create payable token. Now you can purchase it
     *
     */
    function () payable {
        require(
            msg.value > 0
            && purchasingAllowed
            && totalContribution <= contributionCapinWei;
        );

        uint256 _contribution = msg.value;
        /*  everything is in wei */
        uint256 baseTokens  = msg.value.safeMul(tokensPerEther);
        uint256 bonusTokens = baseTokens.safeMul(bonusPercentage).safeDiv(100);
        /* send tokens to buyer. Buyer gets baseTokens + bonusTokens */
        balances[msg.sender] = balances[msg.sender].safeAdd(baseTokens).safeAdd(bonusTokens);
        /* send eth to owner */
        owner.transfer(msg.value);
        
        bonusSupply       = bonusSupply.safeAdd(bonusTokens);
        totalContribution = totalContribution.safeAdd(msg.value);
        _totalSupply      = _totalSupply.safeSub(baseTokens).safeSub(bonusTokens); //Check if

        Transfer(address(this), msg.sender, baseTokens.safeAdd(bonusTokens));
    }
    
    function enablePurchasing() onlyOwner {
        purchasingAllowed = true;
    }
    
    function disablePurchasing() onlyOwner {
        purchasingAllowed = false;
    }
    


    function presaleRoundOne(uint256 _contribution, uint8 _day) {
        require(
            (_contribution >= 2 ether    //minimum contribution 2 ETH
            && _day > 0 && _day <= 31) 
        );
        uint256 tokensPerEther = etherPrice.safeMul(2)

        if(_contribution) >= 100 ether) {       //100 ETH in wei
            bonusPercentage = 50;       //50% of baseTokens awarded
        }
        if(_contribution) >= 25 ether) {        //25 ETH in wei
            bonusPercentage = 25;       //25% of baseTokens awarded
        }
        if(_contribution) >= 15 ether) {        //15 ETH in wei
            bonusPercentage = 15;       //15% of baseTokens awarded
        }
        if(_contribution) >= 10 ether) {        //10 ETH in wei
            bonusPercentage = 10;       //10% of baseTokens awarded
        }
        if(_contribution) >= 4 ether) {         //4 ETH in wei
            bonusPercentage = 5;       //5% of baseTokens awarded
        }         
    }


    function presaleRoundTwo(uint256 _contribution, uint8 _day) {
        require(
            (_day > 31 && _day < 62) 
        );
        uint256 tokensPerEther = etherPrice.safeMul(4).safeDiv(3);

        if(_contribution) >= 1000 ether) {       //10000 ETH in wei
            bonusPercentage = 25;       //25% of baseTokens awarded
        }
        if(_contribution) >= 5000 ether) {        //5000 ETH in wei
            bonusPercentage = 8;       //8% of baseTokens awarded
        }
        if(_contribution) >= 2500 ether) {        //2500 ETH in wei
            bonusPercentage = 5;       //5% of baseTokens awarded
        }
        if(_contribution) >= 1000 ether) {        //1000 ETH in wei
            bonusPercentage = 3;       //3% of baseTokens awarded
        }
        if(_contribution) >= 500 ether) {         //500 ETH in wei
            bonusPercentage = 1;       //1% of baseTokens awarded
        }         
    }


    function tokenSale(uint256 _contribution, uint8 _day){
        require(
            (_day >= 62 && _day < 93) 
        );
        uint256 tokensPerEther = etherPrice.safeMul(1);

        for (var i=_day; i<=_day+30; i++) {
            tokensPerEther = tokensPerEther.safeMul(5).safeDiv(6);
        }

    }


    function balanceOf(address _owner) constant returns (uint256 balance) {
        return balances[_owner];
    }

    function transfer(address _to, uint256 _value) returns (bool success) {
        require(
            (balances[msg.sender] >= _value)
            && (_value > 0)
            && (_to != address(0))
            && (balances[_to].safeAdd(_value) >= balances[_to])
            && (msg.data.length >= (2 * 32) + 4)
        );

        balances[msg.sender] = balances[msg.sender].safeSub(_value);
        balances[_to] = balances[_to].safeAdd(_value);
        Transfer(msg.sender, _to, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) returns (bool success) {
        require(
            (allowed[_from][msg.sender] >= _value) // Check allowance
            && (balances[_from] >= _value) // Check if the sender has enough
            && (_value > 0) // Don't allow 0 value transfer
            && (_to != address(0)) // Prevent transfer to 0x0 address
            && (balances[_to].safeAdd(_value) >= balances[_to]) // Check for overflows
            && (msg.data.length >= (2 * 32) + 4) //mitigates the ERC20 short address attack
            //most of these things are not necesary
        );
        balances[_from] = balances[_from].safeSub(_value);
        balances[_to] = balances[_to].safeAdd(_value);
        allowed[_from][msg.sender] = allowed[_from][msg.sender].safeSub(_value);
        Transfer(_from, _to, _value);
        return true;
    }

    function approve(address _spender, uint256 _value) returns (bool success) {
        
        require(
            (_value == 0) 
            || (allowed[msg.sender][_spender] == 0)
        );
        allowed[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);
        return true;
    }


    function allowance(address _owner, address _spender) constant returns (uint256 remaining) {
        return allowed[_owner][_spender];
    }

    
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);



    // function setCurrentSaleDayAndBonus(uint8 _day) onlyOwner {
    //     require(
    //         (_day > 0 && _day < 11) 
    //     );

    //     currentBonus = 10; 
    //     currentSaleDay = _day;

    //     if(_day==1) {
    //         currentBonus = 100;
    //     } 
    //     if(_day==2) {
    //         currentBonus = 75;
    //     }
    //     if(_day>=3 && _day<5) {
    //         currentBonus = 50;
    //     }
    //     if(_day>=5 && _day<8) {
    //         currentBonus = 25;
    //     } 
    // }

    // function setBonus(uint256 _contribution) {
    //     require(
    //         msg.value > 0     //in wei
    //         (_day > 0 && _day < 61) 
    //     );

    //  //   _contribution / EtherPerDollar = contributionInDollars; 

    //     for (_day < 31) {
    //         if(contributionInDollars >= 25000) {
    //             bonusPercentage = 50;       //50% of baseTokens awarded
    //         }
    //         if(contributionInDollars >= 10000) {
    //             bonusPercentage = 30;       //30% of baseTokens awarded
    //         }
    //         if(contributionInDollars >= 5000) {
    //             bonusPercentage = 20;       //20% of baseTokens awarded
    //         }
    //         if(contributionInDollars >= 2000) {
    //             bonusPercentage = 15;       //15% of baseTokens awarded
    //         }
    //         if(contributionInDollars >= 1000) {
    //             bonusPercentage = 10;       //10% of baseTokens awarded
    //         }
    //         if(contributionInDollars >= 500) {
    //             bonusPercentage = 5;       //5% of baseTokens awarded
    //         }         
    //     }

    //     for (_day < 61) {
    //         if(contributionInDollars >= 20000) {
    //             bonusPercentage = 15;       //15% of baseTokens awarded
    //         }
    //         if(contributionInDollars >= 10000) {
    //             bonusPercentage = 10;       //10% of baseTokens awarded
    //         }
    //         if(contributionInDollars >= 5000) {
    //             bonusPercentage = 7;       //7% of baseTokens awarded
    //         }
    //         if(contributionInDollars >= 2000) {
    //             bonusPercentage = 4;       //4% of baseTokens awarded
    //         }
    //         if(contributionInDollars >= 1000) {
    //             bonusPercentage = 2;       //2% of baseTokens awarded
    //         }
    //         if(contributionInDollars >= 500) {
    //             bonusPercentage = 1;       //1% of baseTokens awarded
    //         }         
    //     }
    // }
}