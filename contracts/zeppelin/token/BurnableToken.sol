pragma solidity ^0.4.13;

import './StandardToken.sol';
import '../math/SafeMath.sol';

/**
 * @title Burnable Token
 * @dev Token that can be irreversibly burned (destroyed). Token owners are able to "burn" (sell to the contract and withdraw from circulation) part of their tokens, and receive some reward. This reward is calculated as <amount_of_burned_tokens> * <amount_of_ETH_on the_contract> / <total_amount_of_tokens>.
 */
contract BurnableToken is StandardToken {
    using SafeMath for uint256;

    event Burn(address indexed from, uint256 amount);
    event BurnRewardIncreased(address indexed from, uint256 value);

    /**
    * @dev Sending ether to contract increases burning reward 
    */
    function() payable {
        if(msg.value > 0){
            BurnRewardIncreased(msg.sender, msg.value);    
        }
    }

    /**
     * @dev Calculates how much ether one will receive in reward for burning tokens
     * @param _amount of tokens to be burned
     */
    function burnReward(uint256 _amount) public constant returns(uint256){
        return this.balance.mul(_amount).div(totalSupply);
    }

    /**
    * @dev Burns tokens and send reward
    * This is internal function because it DOES NOT check 
    * if _from has allowance to burn tokens.
    * It is intended to be used in transfer() and transferFrom() which does this check.
    * @param _from The address which you want to burn tokens from
    * @param _amount of tokens to be burned
    */
    function burn(address _from, uint256 _amount) internal returns(bool){
        require(balances[_from] >= _amount);
        
        uint256 reward = burnReward(_amount);
        assert(this.balance - reward > 0);

        balances[_from] = balances[_from].sub(_amount);
        totalSupply = totalSupply.sub(_amount);
        //assert(totalSupply >= 0); //Check is not needed because totalSupply.sub(value) will already throw if this condition is not met
        
        _from.transfer(reward);
        Burn(_from, _amount);
        return true;
    }

    /**
    * @dev Transfers or burns tokens
    * Burns tokens transferred to this contract itself or to zero address
    * @param _to The address to transfer to or token contract address to burn.
    * @param _value The amount to be transferred.
    */
    function transfer(address _to, uint256 _value) returns (bool) {
        if( (_to == address(this)) || (_to == 0) ){
            return burn(msg.sender, _value);
        }else{
            return BurnableToken.transfer(_to, _value);
        }
    }

    /**
    * @dev Transfer tokens from one address to another 
    * or burns them if _to is this contract or zero address
    * @param _from address The address which you want to send tokens from
    * @param _to address The address which you want to transfer to
    * @param _value uint256 the amount of tokens to be transfered
    */
    function transferFrom(address _from, address _to, uint256 _value) returns (bool) {
        if( (_to == address(this)) || (_to == 0) ){
            var _allowance = allowed[_from][msg.sender];
            //require (_value <= _allowance); //Check is not needed because _allowance.sub(_value) will already throw if this condition is not met
            allowed[_from][msg.sender] = _allowance.sub(_value);
            return burn(_from, _value);
        }else{
            return BurnableToken.transferFrom(_from, _to, _value);
        }
    }

}
