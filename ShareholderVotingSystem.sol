pragma solidity ^0.4.22;

/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {

  /**
  * @dev Multiplies two numbers, throws on overflow.
  */
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0) {
      return 0;
    }
    uint256 c = a * b;
    assert(c / a == b);
    return c;
  }

  /**
  * @dev Integer division of two numbers, truncating the quotient.
  */
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }

  /**
  * @dev Subtracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
  */
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  /**
  * @dev Adds two numbers, throws on overflow.
  */
  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }
}

/*
*
*/
contract CompanyShares {
    using SafeMath for uint256;
    
    mapping (address => uint256) shareholderToShares;
    mapping (address => bool) approvals;
    
    uint public sharePrice;
    address[] public shareholders;
    uint256 private balance;
    address private owner;
    
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }
    constructor(uint256 supply, uint _price) public {
        shareholders.push(msg.sender);
        shareholderToShares[msg.sender] = supply;
        sharePrice = _price;
        owner = msg.sender;
    }
    function getShareholder() view public returns(address[]) {
        return shareholders;
    }
    function getShareByAddress(address _address) view public returns(uint256) {
        return shareholderToShares[_address];
    }
    function deposit() public payable onlyOwner {
        balance = msg.value;
    }
    function getBalance() view public returns(uint256) {
        return balance;
    }
    function buyShares(uint256 amount) public payable {
        require(shareholderToShares[owner] >= amount);
        require(msg.value >= amount.mul(sharePrice));
        //balance = balance.add(amount*sharePrice);
        owner.transfer(amount.mul(sharePrice));
        shareholderToShares[owner] = shareholderToShares[owner].sub(amount);
        shareholders.push(msg.sender); //check duplicate
        shareholderToShares[msg.sender] = 
            shareholderToShares[msg.sender].add(amount);
    }
    function approve(address _to, bool yesNo) public onlyOwner {
        approvals[_to] = yesNo;
    } 
    function withdraw() public { 
        require(approvals[msg.sender]);
        uint256 amount = shareholderToShares[msg.sender].mul(sharePrice);
        require(balance >= amount);
        shareholderToShares[owner] = 
            shareholderToShares[owner].add(shareholderToShares[msg.sender]);
        msg.sender.transfer(amount);
        balance = balance.sub(amount);
        shareholderToShares[msg.sender] = 0;
    }
    function changePriceOfShare(uint _price) public onlyOwner {
        sharePrice = _price;
    }
    function transferShares(address _to, uint256 shares) public {
        require(shareholderToShares[msg.sender] >= shares);
        shareholderToShares[_to] = shares;
        shareholderToShares[msg.sender] = shareholderToShares[msg.sender].sub(shares);
    }
}
/*
*
*/
contract Voting is CompanyShares {
    using SafeMath for uint32;
    
    mapping (address => uint32) shareholderToVotingCount;
    
    struct AgendaForVoting {
        string contents;
        uint256 endTime;
    }
    AgendaForVoting agendaForVoting;
    struct AgendaVoting {
        string  choice;
        uint32  votes;
    }
    AgendaVoting[] agendaVotings;
    
    modifier withinDeadLine () {
        require(agendaForVoting.endTime >= now);
        _;
    }
    modifier onlyShareholders() {
        for (uint i = 0; i < shareholders.length; i++ ) {
            if (msg.sender == shareholders[i]) break;
        }
        require (i < shareholders.length);
        _;
    }
    function addAgendaContents(string _agendaContents, uint _endTime) public onlyOwner {
         agendaForVoting.contents = _agendaContents;
         agendaForVoting.endTime = _endTime;
    }
    function addAgendaVoting(string _choice) public onlyOwner {
        agendaVotings.push(AgendaVoting(_choice, 0));
    }
    function getAgendaVotingResult(uint index) view public returns (uint32) {
        return agendaVotings[index].votes;
    }
    function getAgenda() public view returns(string) {
        return agendaForVoting.contents;
    }
    function getEndTime() public view returns(uint256) {
        return agendaForVoting.endTime;
    }
    function vote(uint32 index, uint32 sharesToVote) public onlyShareholders withinDeadLine {
        require(index >= 0);
        require(index < agendaVotings.length);
        require(shareholderToVotingCount[msg.sender]+sharesToVote 
                <= shareholderToShares[msg.sender]);
        agendaVotings[index].votes++;
        shareholderToVotingCount[msg.sender].add(sharesToVote);
    }
}
