pragma solidity ^0.4.18;


import './zeppelin/token/ERC20/MintableToken.sol';
import './zeppelin/token/ERC20/BurnableToken.sol';
import './zeppelin/token/ERC827/ERC827Token.sol';
import './zeppelin/ownership/HasNoEther.sol';
import './zeppelin/ownership/HasNoContracts.sol';
import './zeppelin/ownership/HasNoTokens.sol';

contract CoderCoin is MintableToken, BurnableToken, ERC827Token, HasNoContracts, HasNoTokens {
    string public symbol = 'CDR';
    string public name = 'CoderCoin';
    uint8 public constant decimals = 18;

    /**
     * Allow transfer only after crowdsale finished
     */
    modifier canTransfer() {
        require(mintingFinished);
        _;
    }
    
    function transfer(address _to, uint256 _value) canTransfer public returns (bool) {
        return super.transfer(_to, _value);
    }

    function transferFrom(address _from, address _to, uint256 _value) canTransfer public returns (bool) {
        return super.transferFrom(_from, _to, _value);
    }

    function transfer( address _to, uint256 _value, bytes _data ) canTransfer public returns (bool){
        return super.transfer(_to, _value, _data);
    }
    function transferFrom( address _from, address _to, uint256 _value, bytes _data ) canTransfer public returns (bool){
        return super.transferFrom(_from, _to, _value, _data);
    }
}