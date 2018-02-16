pragma solidity ^0.4.18;


import './zeppelin/token/ERC20/ERC20Basic.sol';
import './zeppelin/token/ERC20/SafeERC20.sol';
import './zeppelin/ownership/Ownable.sol';


/**
 * @title TokenTimelock
 * @dev TokenTimelock is a token holder contract that will allow a
 * beneficiary to extract the tokens after a given release time
 */
contract TokenTimelockMod is Ownable {
  using SafeERC20 for ERC20Basic;

  // timestamp when token release is enabled
  uint64 public releaseTime;

  function TokenTimelockMod(uint64 _releaseTime) public {
    require(_releaseTime > now);
    releaseTime = _releaseTime;
  }

  /**
   * @notice Transfers tokens held by timelock to beneficiary.
   */
  function release(ERC20Basic token) public {
    require(now >= releaseTime);

    uint256 amount = token.balanceOf(this);
    require(amount > 0);

    token.safeTransfer(owner, amount);
  }

  // /**
  // * Sample usage
  // */
  // function initReserve(uint64[] reserveReleases, uint256[] reserveAmounts, address[] reserveBeneficiaries) internal {
  //     require(reserveReleases.length == reserveAmounts.length && reserveReleases.length == reserveBeneficiaries.length);
  //     for(uint8 i=0; i < reserveReleases.length; i++){
  //         require(reserveReleases[i] > now);
  //         require(reserveAmounts[i] > 0);
  //         require(reserveBeneficiaries[i] != address(0));
  //         TokenTimelockMod tt = new TokenTimelockMod(reserveReleases[i]);
  //         tt.transferOwnership(reserveBeneficiaries[i]);
  //         assert(token.mint(tt, reserveAmounts[i]));
  //         TokenTimelockCreated(tt, reserveReleases[i], reserveBeneficiaries[i], reserveAmounts[i]);
  //     }
  // }

}


