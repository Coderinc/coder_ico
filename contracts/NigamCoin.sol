pragma solidity ^0.4.0;


import './zeppelin/token/MintableToken.sol';
import './zeppelin/token/BurnableToken.sol';
import './zeppelin/ownership/HasNoEther.sol';
import './zeppelin/ownership/HasNoContracts.sol';
import './zeppelin/ownership/HasNoTokens.sol';

contract NigamCoin is MintableToken, BurnableToken, HasNoContracts, HasNoTokens { //MintableToken is StandardToken, Ownable
    string public symbol = 'NGM';
    string public name = 'NigamCoin';
    uint8 public constant decimals = 18;

    /**
     * Allow transfer only after crowdsale finished
     */
    modifier canTransfer() {
        require(mintingFinished);
        _;
    }
    
    function transfer(address to, uint256 value) canTransfer returns (bool) {
        return super.transfer(_to, _value);
    }

    function transferFrom(address from, address to, uint256 _value) canTransfer returns (bool) {
        return super.transferFrom(_from, to, value);
    }

}