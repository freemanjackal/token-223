pragma solidity ^0.4.16;


contract PreSalePlubitContract is Owned, Pausable, MathLib {

    MyPlubitToken    pub;

    // crowdsale parameters
    uint256 public startBlock = 3000;
    uint256 public endBlock   = 400000;
    uint256 public maxSupply;
    address public ethFundDepositPreSale   = address;      // deposit address for ETH for plubit Fund for presale
    address public PlubPresaleDeposit = 0x15BbF009b65c1D4599AB91214eC1B5e5c5426e92;      // deposit address for plubit
    address public plubAddress =    0xd0caEacb166Ed5B30BebfE704cb4E0786326B6A8;       //addres of token contract

    bool public isFinalized;                                                            // switched to true in operational state
    uint256 public constant decimals = 18;                                              // #dp in token contract
    uint256 public tokenCreationCap;
    uint256 public constant tokenExchangeRate = 1000;                                   // define how many tokens per 1 ETH
    uint256 public constant minContribution = 0.5 ether;
    uint256 public constant MAX_GAS_PRICE = 50000000000 wei;                            // maximum gas price for contribution transactions

    function PreSalePlubitContract() {
        CreateTokensEvent();
        pub = MyPlubitToken(plubAddress);
        tokenCreationCap = 0;
        isFinalized = false;
        maxSupply = pub.MaxPlubPreSale;
    }

    event MintPlub(address from, address to, uint256 val);
    event LogRefund(address indexed _to, uint256 _value);
    event CreateTokensEvent();


    function CreatePlub(address to, uint256 val) internal returns (bool success) {
        MintPlub(plubFundDeposit,to,val);
        return pub.transferFromPreICO(plubFundDeposit, to, val);
    }

    function () payable {
        CreateTokensEvent();
        createTokens(msg.sender,msg.value);
    }

    /// @dev Accepts ether and creates new IND tokens.
    function createTokens(address _beneficiary, uint256 _value) internal whenNotPaused {
      require (tokenCreationCap < maxSupply);                                         // CAP reached no more please
      require (block.number >= startBlock);
      require (block.number <= endBlock);
      require (_value >= minContribution);                                              // To avoid spam transactions on the network
      require (!isFinalized);
      require (tx.gasprice <= MAX_GAS_PRICE);

      uint256 tokens = safeMult(_value, tokenExchangeRate);                             // check that we're not over totals
      uint256 checkedSupply = safeAdd(tokenCreationCap, tokens);

      //require (pub.balanceOf(msg.sender) + tokens <= maxTokens);   to define max tokens a user can buy

      // fairly allocate the last few tokens
      if (tokenCreationCap > maxSupply) {
        uint256 tokensToAllocate = safeSubtract(maxSupply, tokenCreationCap);
        uint256 tokensToRefund   = safeSubtract(tokens,tokensToAllocate);
        tokenCreationCap = maxSupply;
        uint256 etherToRefund = tokensToRefund / tokenExchangeRate;

        require(CreatePlub(_beneficiary,tokensToAllocate));                              // Create
        msg.sender.transfer(etherToRefund);
        LogRefund(msg.sender,etherToRefund);
        ethFundDepositPreSale.transfer(this.balance);
        return;
      }

      tokenCreationCap = checkedSupply;
      require(CreatePlub(_beneficiary, tokens));                                         // logs token creation
      ethFundDepositPreSale.transfer(this.balance);
    }

    /// @dev Ends the funding period and sends the ETH home
    function finalize() external onlyOwner {
      require (!isFinalized);
      // move to operational
      isFinalized = true;
      ethFundDepositPreSale.transfer(this.balance);                                            // send the eth to multi-sig
    }

}
