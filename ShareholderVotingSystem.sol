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
*   @dev    using IPFS, save some documents
*/
contract DocumentRegistry {
    struct Document {
        string hash;
        uint256 dateAdded;
    }
    Document[] private documents;
    address owner;
    modifier onlyOwner() {
        require(owner == msg.sender);
        _;
    }
    constructor() public {
        owner == msg.sender;
    }
    function add(string hash) public onlyOwner returns(uint dateAdded) {
        dateAdded = block.timestamp;
        documents.push(Document(hash, dateAdded));
    }
    function getDocmentsCount() public view returns (uint length) {
        length = documents.length;
    }
    function getDocments(uint index) public view returns(string, uint) { 
        Document memory document = documents[index];
        return (document.hash, document.dateAdded);
    }
}
/*
*   @title  CompanyShares
*   @dev    Issue, buy, sell and transfer of stocks in a company
*/
contract CompanyShares {
    // to prevent some possible problems in handling integer data
    using SafeMath for uint256;
    
    mapping (address => uint256) shareholderToShares;
    mapping (address => bool) approvals;        // owner's approval of withdraw
    
    uint32        sharePrice;     // price per a stock
    address[]   shareholders;   // addresses of stockholders
    uint256     balance;        // to deposit some asset by owner
    address     owner;          // to save the owner of this contract
    
    /*  @dev check if the message sender is the owner.
    */
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }
    /*
    *   @dev    When deploy, this function is executed. 
    *           In real world, startup a company.
    */
    constructor(uint256 supply, uint32 _price) public {
        shareholders.push(msg.sender);
        shareholderToShares[msg.sender] = supply;
        sharePrice = _price;
        owner = msg.sender;
    }
    /*
    *   @dev    View the current status
    */
    function getShareholder() view public returns(address[]) {
        return shareholders;
    }
    function getShareByAddress(address _address) view public returns(uint256) {
        return shareholderToShares[_address];
    }
    /*  @dev    The owner may deposit some for withdraw or etc. 
    */
    function deposit() public payable onlyOwner {
        balance = msg.value;
    }
    function getBalance() view public returns(uint256) {
        return balance;
    }
    /*
    *   @dev    Anybody can buy stocks from the original owner
    */
    function buyShares(uint256 amount) public payable {
        require(shareholderToShares[owner] >= amount);
        require(msg.value >= amount.mul(sharePrice));
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
    /*  @dev    The buyer can cancel its buying of stocks
    */
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
    /*  @dev    The owner can change the stock price anytime.
    */
    function changePriceOfShare(uint32 _price) public onlyOwner {
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
     
    event AgendaSetup(string agenda, uint256 startTime, uint256 endTime, uint noOfOptions);
    event AgendaVote(address voter, uint256 votingTime, uint256 sharesToVote);
    event TransferVotingShares(address to, uint256 shares, uint256 time);
    
    //mapping (address => uint256) shareholderToVotingCount;
    mapping (address => uint256) votingShares;
     
    // Some agenda to be discussed and decided by voting in the meeting
    struct Agenda {
        string contents; 
        uint256 startTime;
        uint256 endTime;
        uint8 noOfOptions;
    }
    Agenda agenda;
    
    uint256[] agendaVotes;
    
    modifier withinDeadLine () {
        require(agenda.startTime <= now);
        require(agenda.endTime >= now);
        _;
    }
    modifier onlyShareholders() {
        for (uint i = 0; i < shareholders.length; i++ ) {
            if (msg.sender == shareholders[i]) break;
        }
        require (i < shareholders.length);
        _;
    }
	// call inheritance constructor
	constructor(uint256 supply, uint32 price) CompanyShares(supply, price) public {}
    /*
    *   @dev Starting the processing of a agenda, set up inital data
    */
    function registerAgenda(string _agendaContents, uint256 duration, 
                                uint8 _noOfOptions) public onlyOwner {
         agenda.contents = _agendaContents;
         agenda.startTime = block.timestamp; //now;
         agenda.endTime = now + duration*3600*1000;
         agenda.noOfOptions = _noOfOptions;
		 
         // Copy from shareholderToShares to votingShares
         // Initially, the number of shares equals to the number of voting shares
         for (uint i = 0; i < shareholders.length; i++) {
             votingShares[shareholders[i]] = shareholderToShares[shareholders[i]];
         }
         emit AgendaSetup(_agendaContents, agenda.startTime, agenda.endTime, _noOfOptions);
    }
    
    /*
    *  @dev Below functions are for only viewing the current status
    */
    function getAgendaVotingVotes(uint index) view public returns (uint256) {
        return agendaVotes[index];
    }
    function getAgendaContents() public view returns(string) {
        return agenda.contents;
    }
    function getStartTime() public view returns(uint256) {
        return agenda.startTime;
    }
    function getEndTime() public view returns(uint256) {
        return agenda.endTime;
    }
    /*
    *  @dev Anybody can participate in the voting if he or she has some 
    *       voting shares
    */
    function vote(uint32 index, uint32 sharesToVote) public onlyShareholders withinDeadLine {
        require(index >= 0);
        require(index < agendaVotes.length);
        require(sharesToVote <= shareholderToShares[msg.sender]);
        agendaVotes[index]++;
        shareholderToShares[msg.sender] = shareholderToShares[msg.sender].sub(sharesToVote);
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
        emit TransferVotingShares(_to, shares, now);
    }
    /*
    *   @dev save the minutes from Shareholders' meeting in IPFS
    */
    function saveDocument(string hash) public onlyOwner {
        DocumentRegistry document = new DocumentRegistry();
        document.add(hash);
    }
}
