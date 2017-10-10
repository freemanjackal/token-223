pragma solidity ^0.4.16;
contract ContractReceiver
{
    function tokenFallback(address, uint256, bytes);
}
contract ERC223 {

  uint public totalSupply;
  function balanceOf(address who) constant returns (uint);
  function transfer(address to, uint value) returns (bool ok);
  function transfer(address to, uint value, bytes data) returns (bool ok);
  event Transfer(address indexed from, address indexed to, uint value, bytes data);

}

contract MathLib {

    function safeAdd(uint256 x, uint256 y) internal returns(uint256) {
      uint256 z = x + y;
      assert((z >= x) && (z >= y));
      return z;
    }

    function safeSubtract(uint256 x, uint256 y) internal returns(uint256) {
      assert(x >= y);
      uint256 z = x - y;
      return z;
    }

    function safeMult(uint256 x, uint256 y) internal returns(uint256) {
      uint256 z = x * y;
      assert((x == 0)||(z/x == y));
      return z;
    }
}

contract Owned {

  address public owner;

  function Owned() {
      owner = msg.sender;
  }

  modifier onlyOwner {
      require(msg.sender == owner);
      _;
  }

}

contract Token is ERC223, MathLib {

  /**
   * @dev Fix for the ERC20 short address attack.
   */
   address public Ico_contract;      // addres with permission for making transfer

  modifier onlyPayloadSize(uint size) {
     require(msg.data.length >= size + 4) ;
     _;
  }

  mapping(address => uint) balances;

  function transfer(address _to, uint _value, bytes _data) returns (bool success) {

    if(isContract(_to)) {
        return transferToContract(_to, _value, _data);
    }
    return transferToAddress(_to, _value, _data);
  }

  function transfer(address _to, uint _value) returns (bool success) {
        bytes memory empty;
        if(isContract(_to)) {
          return transferToContract(_to, _value, empty);
        }
        return transferToAddress(_to, _value, empty);
  }

  function isContract(address _addr) private returns (bool is_contract) {
     uint length;
     assembly {
           //retrieve the size of the code on target address, this needs assembly
           length := extcodesize(_addr)
     }
     return (length>0);
  }
//when transaction target is a contract
  function transferToContract(address _to, uint _value, bytes _data) private returns (bool success) {
    require(balanceOf(msg.sender) > _value);
    balances[msg.sender] = safeSubtract(balanceOf(msg.sender), _value);
    balances[_to] = safeAdd(balanceOf(_to), _value);
    ContractReceiver receiver = ContractReceiver(_to);
    receiver.tokenFallback(msg.sender, _value, _data);
    Transfer(msg.sender, _to, _value, _data);
    return true;
  }

//when transaction target is an address
function transferToAddress(address _to, uint _value, bytes _data) private returns (bool success) {
  require(balanceOf(msg.sender) > _value);
  balances[msg.sender] = safeSubtract(balanceOf(msg.sender), _value);
  balances[_to] = safeAdd(balanceOf(_to), _value);
  Transfer(msg.sender, _to, _value, _data);
  return true;
}



  function balanceOf(address _owner) constant returns (uint balance) {
    return balances[_owner];
  }



}

contract Pausable is Owned{
  event Pause();
  event Unpause();

  bool public paused = false;


  /**
   * @dev modifier to allow actions only when the contract IS paused
   */
  modifier whenNotPaused() {
    require (!paused);
    _;
  }

  /**
   * @dev modifier to allow actions only when the contract IS NOT paused
   */
  modifier whenPaused {
    require (paused) ;
    _;
  }

  /**
   * @dev called by the owner to pause, triggers stopped state
   */
  function pause() onlyOwner whenNotPaused returns (bool) {
    paused = true;
    Pause();
    return true;
  }

  /**
   * @dev called by the owner to unpause, returns to normal state
   */
  function unpause() onlyOwner whenPaused returns (bool) {
    paused = false;
    Unpause();
    return true;
  }


}

contract MyPlubitToken is Owned, Token {
    string public constant name = "Plubit Token";
    string public constant symbol = "PBT";
    uint256 public constant decimals = 18;
    string public version = "1.0";

    uint256 public sellPrice;
    //contracts
    address public PlubSaleDeposit        = 0xD7199729a878c2D228cc4E82A7ce6351bEDADD2e;      // deposit address for PBT Sale contract
    address public PlubPresaleDeposit     = 0x15BbF009b65c1D4599AB91214eC1B5e5c5426e92;      // deposit address for PBT Presale Contributors
    address public PlubTeamDeposit        = 0x46a2a8C123c4584A3D05f4de84B3B4732510BC07;      // deposit address for PBT Vesting for team and advisors
    address public PlubNetDeposit        = 0x32Fd75Ac2dFC185895396155A03ea16203783cd3;      // deposit address for PBT Vesting for team and advisors



    uint256 public constant PlubSale      = 10000000 * 10**decimals;
    uint256 public constant PlubPreSale   = 5000000 * 10**decimals;
    uint256 public constant PlubTeam      = 2000000 * 10**decimals;
    uint256 public constant PlubNet       = 10000000 * 10**decimals;

    mapping (address => bool) public frozenAccount;


  /* Initializes contract with initial supply tokens to the creator of the contract */
  function MyPlubitToken() {
      balances[PlubSaleDeposit]           = PlubSale;                                         // Deposit PBT
      balances[PlubPresaleDeposit]        = PlubPreSale;                                      // Deposit PBT
      balances[PlubTeamDeposit]           = PlubTeam;                                         // Deposit PBT
      balances[PlubNetDeposit]            = PlubNet;                                         // Deposit PBT

      totalSupply = PlubSale + PlubPreSale + PlubTeam + PlubNet;
      bytes memory data;
      Transfer(0x0,PlubSaleDeposit,PlubSale, data);
      Transfer(0x0,PlubPresaleDeposit,PlubPreSale, data);
      Transfer(0x0,PlubTeamDeposit,PlubTeam, data);
      Transfer(0x0,PlubNetDeposit,PlubNet, data);
  }

  function load(address _ico) onlyOwner {
      Ico_contract = _ico;
  }

  function transferFromICO(address _from, address _to, uint _value) only_ICO onlyPayloadSize(3 * 32) returns (bool success) {
    balances[_to] = safeAdd(balances[_to], _value);
    balances[_from] = safeSubtract(balances[_from], _value);
    bytes memory data;
    Transfer(_from, _to, _value, data);
    return true;
  }

  modifier only_ICO
    {
        require(msg.sender == Ico_contract);
        _;
}

}
