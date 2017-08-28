pragma solidity ^0.4.11;

import './MintableToken.sol';
import './SafeMath.sol';
import './TokenBonus.sol';

/**
 * @title Crowdsale
 * @dev Crowdsale is a base contract for managing a token crowdsale.
 * Crowdsales have a start and end timestamps, where investors can make
 * token purchases and the crowdsale will assign them tokens based
 * on a token per ETH swaprate. Funds collected are forwarded to a wallet
 * as they arrive.
 */
contract Crowdsale {
  using SafeMath for uint256;

  // The token being sold
  MintableToken public token;
  TokenBonus public tokenBonusContract;

  // start and end timestamps where investments are allowed (both inclusive)
  uint256 public startTime;
  uint256 public endTime;


  // address where funds are collected
  address public wallet;
  address public owner;
  address public Sponsor;

  // how many token units a buyer gets per wei
  uint256 public swaprate = 100;
  uint256 public SponsorSwapRate = 150;

  // amount of raised money in wei
  uint256 public amountRaised;
  uint256 public totalSupply;

  /**
   * event for token purchase logging
   * @param purchaser who paid for the tokens
   * @param beneficiary who got the tokens
   * @param value weis paid for purchase
   * @param amount amount of tokens purchased
   */
  event TokenPurchase(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);
  event SponsorTokenPurchase(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);
  event TokenBonusClaimed(address indexed beneficiary, uint256 amount);

  modifier onlySponsor {
    require (msg.sender == Sponsor);
    _;
  }

  modifier isValidPurchase {
    require (validPurchase());
    _;
  }

  modifier isValidBeneficiary (address _addr) {
    require (_addr != 0x0);
    _;
  }

  modifier isExistingBeneficiary (address _addr) {
    require (token.balanceOf(_addr) > 0);
    _;
  }

  modifier isValidPurchaseForSponsor {
    require (validPurchaseForSponsor());
    _;
  }



  function Crowdsale(uint256 _startTime, uint256 _endTime, address _wallet, address _owner, address _sponsor, address _TACvoting) {
    require(_startTime >= now);
    require(_endTime >= _startTime);
    require(_wallet != 0x0);

    token = createTokenContract();
    tokenBonusContract = createTokenBonusContract(token, _TACvoting);
    startTime = _startTime;
    endTime = _endTime;
    wallet = _wallet;
    Sponsor = _sponsor;
    owner = _owner;
    totalSupply = totalSupply.add(1518000e18);
    token.mint(owner, 1518000e18);
  }

  // creates the token to be sold.
  // override this method to have crowdsale of a specific mintable token.
  function createTokenContract() internal returns (MintableToken) {
    return new MintableToken();
  }
  // creates the token to be sold.
  // override this method to have crowdsale of a specific mintable token.
  function createTokenBonusContract(address tokencontract, address _TACvoting) internal returns (TokenBonus) {
    return new TokenBonus(tokencontract, _TACvoting);
  }

  // fallback function can be used to buy tokens
  function () payable {
    buyTokens(msg.sender);
  }

  // low level token purchase function
  function buyTokens(address beneficiary)
  payable
  isValidPurchase
  isValidBeneficiary (beneficiary) {

    uint256 etherAmount = msg.value;

    // calculate token amount to be created
    uint256 tokens = etherAmount.mul(swaprate);

    // update state
    amountRaised = amountRaised.add(etherAmount);
    totalSupply  = totalSupply.add(tokens);

    token.mint(beneficiary, tokens);
    TokenPurchase(msg.sender, beneficiary, etherAmount, tokens);

    forwardFunds();
  }

  // low level token purchase function
  function buyTokensforSponsor(address beneficiary)
  payable
  onlySponsor
  isValidPurchaseForSponsor
  isValidBeneficiary (beneficiary) {

    uint256 etherAmount = msg.value;

    // calculate token amount to be created
    uint256 tokens = etherAmount.mul(SponsorSwapRate);

    // update state
    amountRaised = amountRaised.add(etherAmount);
    totalSupply  = totalSupply.add(tokens);

    token.mint(beneficiary, tokens);
    SponsorTokenPurchase(msg.sender, beneficiary, etherAmount, tokens);

    forwardFunds();
  }

  function claimTokenBonus (address beneficiary)
  isValidBeneficiary (beneficiary) {
    uint tokens = tokenBonusContract.mintTokenBonus(beneficiary);
    totalSupply  = totalSupply.add(tokens);
    token.mint(beneficiary, tokens);
    TokenBonusClaimed(beneficiary, tokens);
  }

  // send ether to the fund collection wallet
  // override to create custom fund forwarding mechanisms
  function forwardFunds() internal {
    wallet.transfer(msg.value);
  }

  function validPurchaseForSponsor() internal constant returns (bool) {
    bool afterPeriod = now >= endTime;
    bool nonZeroPurchase = msg.value != 0;
    return afterPeriod && nonZeroPurchase;
  }
  // @return true if the transaction can buy tokens
  function validPurchase() internal constant returns (bool) {
    bool withinPeriod = now >= startTime && now <= endTime;
    bool nonZeroPurchase = msg.value != 0;
    return withinPeriod && nonZeroPurchase;
  }

  // @return true if crowdsale event has ended
  function hasEnded() public constant returns (bool) {
    return now > endTime;
  }
}
