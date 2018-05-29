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
*   @title  CompanyShares
*   @dev    Issue, buy, sell and transfer of stocks in a company
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
    /*
    *   @dev    When deploy, this function is executed. 
    *           In real world, startup a company.
    */
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
    /*  @dev    owner may deposit some for refund (maybe ?)
    */
    function deposit() public payable onlyOwner {
        balance = msg.value;
    }
    function getBalance() view public returns(uint256) {
        return balance;
    }
    /*
    *   @dev    Anybody can by the stocks from the original owner
    */
    function buyShares(uint256 amount) public payable {
        require(shareholderToShares[owner] >= amount);
        require(msg.value >= amount.mul(sharePrice));
        //balance = balance.add(amount*sharePrice);
        owner.transfer(amount.mul(sharePrice));
        shareholderToShares[owner] = shareholderToShares[owner].sub(amount);
         
        //check if there is duplicate address
        for (uint i = 0; i < shareholders.length; i++)
            if (shareholders[i] == msg.sender) break;
        if (i == shareholders.length) shareholders.push(msg.sender);
        
        shareholderToShares[msg.sender] = 
            shareholderToShares[msg.sender].add(amount);
    }
    /*  @dev The owner only can approve the withdraw of purchasing stocks
    */
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
    /*
    *   @dev    shareholders can transfer their stocks to others
    *           without any condition
    */
    function transferShares(address _to, uint256 shares) public {
        require(shareholderToShares[msg.sender] >= shares);
        shareholderToShares[_to] = shares;
        shareholderToShares[msg.sender] = shareholderToShares[msg.sender].sub(shares);
    }
}
/*
*   @title  VotingOnAgenda
*   @dev    Voting system to handle a agneder suggested in a stockholder's meeting
*/
contract VotingOnAgenda is CompanyShares {
    // to prevent some possible problems in handling integer data
    using SafeMath for uint32;  
    using SafeMath for uint256; 
     
    event AgendaSetup(string agenda, uint256 startTime, uint256 endTime);
    event AgendaVote(address voter, uint256 votingTime, uint256 sharesToVote);
    
    mapping (address => uint256) shareholderToVotingCount;
    mapping (address => uint256) votingShares;
     
    struct Agenda {
        string contents;
        uint256 startTime;
        uint256 endTime;
    }
    Agenda agendaForVoting;
    struct AgendaVoting {
        string  choice;
        uint32  votes;
    }
    AgendaVoting[] agendaVotings;
    
    modifier withinDeadLine () {
        require(agendaForVoting.startTime <= now);
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
    /*
    *   @dev Starting the processing of a agenda, set up inital data
    */
    function setupAgenda(string _agendaContents, uint256 _startTime, 
                        uint256 _endTime) public onlyOwner {
         agendaForVoting.contents = _agendaContents;
         agendaForVoting.startTime = _startTime;
         agendaForVoting.endTime = _endTime;
         
         // Copy from shareholderToShares to votingShares
         // Initially, the number of shares equals to the number of voting shares
         for (uint i = 0; i < shareholders.length; i++) {
             votingShares[shareholders[i]] = shareholderToShares[shareholders[i]];
         }
         emit AgendaSetup(_agendaContents, _startTime, _endTime);
    }
    function addAgendaVoting(string _choice) public onlyOwner {
        agendaVotings.push(AgendaVoting(_choice, 0));
    }
    
    /*
    *  @dev Below functions are for only viewing the current status
    */
    function getAgendaVotingVotes(uint index) view public returns (uint32) {
        return agendaVotings[index].votes;
    }
    function getAgendaVotingChoice(uint index) view public returns(string) {
        return agendaVotings[index].choice;
    }
    function getAgendaContents() public view returns(string) {
        return agendaForVoting.contents;
    }
    function getStartTime() public view returns(uint256) {
        return agendaForVoting.startTime;
    }
    function getEndTime() public view returns(uint256) {
        return agendaForVoting.endTime;
    }
    
    /*
    *  @dev Anybody can participate in the voting if he or she has some 
    *       voting shares
    */
    function vote(uint32 index, uint32 sharesToVote) public onlyShareholders withinDeadLine {
        require(index >= 0);
        require(index < agendaVotings.length);
        require(shareholderToVotingCount[msg.sender]+sharesToVote 
                <= shareholderToShares[msg.sender]);
        agendaVotings[index].votes++;
        shareholderToVotingCount[msg.sender].add(sharesToVote);
        emit AgendaVote(msg.sender, now, sharesToVote);
    }
    /*
    *  @dev Shareholders can yield their voting shares to other address
    *       only between startTime  and endTime
    */
    function transferVotingShares(address _to, uint256 shares) public withinDeadLine {
        require(votingShares[msg.sender] >= shares);
        votingShares[_to] = shares;
        votingShares[msg.sender] = votingShares[msg.sender].sub(shares);
    }
}
