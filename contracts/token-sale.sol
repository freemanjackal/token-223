pragma solidity ^0.4.16;


contract SalePlubitContract is Owned, Pausable, MathLib {

    MyPlubitToken    pub;

    // crowdsale parameters
    uint256 public startBlock = 3000;
    uint256 public endBlock   = 400000;
    uint256 public totalSupply;
    address public ethFundDeposit   = 0xCAb07e359322702Cc34eD480bb20aF8Aab6aD6A9;      // deposit address for ETH for plubit Fund
    address public plubFundDeposit   = 0xD7199729a878c2D228cc4E82A7ce6351bEDADD2e;      // deposit address for plubit
    address public plubAddress =    0xd0caEacb166Ed5B30BebfE704cb4E0786326B6A8;       //addres of token contract

    bool public isFinalized;                                                            // switched to true in operational state
    uint256 public constant decimals = 18;                                              // #dp in token contract
    uint256 public tokenCreationCap;
    uint256 public constant tokenExchangeRate = 1000;                                   // define how many tokens per 1 ETH
    uint256 public constant minContribution = 0.05 ether;
    uint256 public constant maxTokens = 1 * (10 ** 6) * 10**decimals;
    uint256 public constant MAX_GAS_PRICE = 50000000000 wei;                            // maximum gas price for contribution transactions

    function SalePlubitContract() {
        CreateTokensEvent();
        pub = MyPlubitToken(plubAddress);
        tokenCreationCap = pub.balanceOf(plubFundDeposit);
        isFinalized = false;
    }

    event MintPlub(address from, address to, uint256 val);
    event LogRefund(address indexed _to, uint256 _value);
    event CreateTokensEvent();


    function CreatePlub(address to, uint256 val) internal returns (bool success) {
        MintPlub(plubFundDeposit,to,val);
        return pub.transferFromICO(plubFundDeposit, to, val);
    }

    function () payable {
        CreateTokensEvent();
        createTokens(msg.sender,msg.value);
    }

    /// @dev Accepts ether and creates new IND tokens.
    function createTokens(address _beneficiary, uint256 _value) internal whenNotPaused {
      require (tokenCreationCap > totalSupply);                                         // CAP reached no more please
      require (block.number >= startBlock);
      require (block.number <= endBlock);
      require (_value >= minContribution);                                              // To avoid spam transactions on the network
      require (!isFinalized);
      require (tx.gasprice <= MAX_GAS_PRICE);

      uint256 tokens = safeMult(_value, tokenExchangeRate);                             // check that we're not over totals
      uint256 checkedSupply = safeAdd(totalSupply, tokens);

      require (pub.balanceOf(msg.sender) + tokens <= maxTokens);

      // fairly allocate the last few tokens
      if (tokenCreationCap < checkedSupply) {
        uint256 tokensToAllocate = safeSubtract(tokenCreationCap,totalSupply);
        uint256 tokensToRefund   = safeSubtract(tokens,tokensToAllocate);
        totalSupply = tokenCreationCap;
        uint256 etherToRefund = tokensToRefund / tokenExchangeRate;

        require(CreatePlub(_beneficiary,tokensToAllocate));                              // Create
        msg.sender.transfer(etherToRefund);
        LogRefund(msg.sender,etherToRefund);
        ethFundDeposit.transfer(this.balance);
        return;
      }

      totalSupply = checkedSupply;
      require(CreatePlub(_beneficiary, tokens));                                         // logs token creation
      ethFundDeposit.transfer(this.balance);
    }

    /// @dev Ends the funding period and sends the ETH home
    function finalize() external onlyOwner {
      require (!isFinalized);
      // move to operational
      isFinalized = true;
      ethFundDeposit.transfer(this.balance);                                            // send the eth to multi-sig
    }

}
