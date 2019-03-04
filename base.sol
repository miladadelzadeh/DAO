pragma solidity >=0.4.22 <0.6.0;
contract owned {
    address public owner;
    constructor() public {
        owner = msg.sender;
    }
    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }
    function transferOwnership(address newOwner) onlyOwner  public {
        owner = newOwner;
    }
}
contract Congress is owned{

    constructor (
    )  payable public {
        addMember(owner, 'founder');
    }

    function () payable external {
        emit receivedEther(msg.sender, msg.value);
    }

    event receivedEther(address sender, uint amount);
    
    /*******************************************************/

    mapping (address => Member) public member;
    Member[] public members;
    struct Member {
        address account;        string name;        uint memberSince; uint token;
    }
    modifier onlyMembers {
        require(member[msg.sender].memberSince != 0);
        _;
    }
    function addMember(address _account, string memory _name) public {
        member[_account].account =_account;
        member[_account].name =_name;
        member[_account].memberSince =now;
        member[_account].token =1000;
        members.push(member[_account]);
        emit MembershipChanged(_account, true);
    }
    event MembershipChanged(address account, bool isMember);

    function getMember(address _account)onlyMembers public view returns(string memory,uint,uint){
        return (member[_account].name,member[_account].memberSince,member[_account].token);
    }
    /*
    function getMembers()onlyMembers public view returns(address[] memory,bytes32[] memory){
        uint size=members.length;
        address[] memory addressTemps=new address[](size);
        bytes32[] memory stringTemps=new bytes32[](size);
        for(uint i=0;i<size;i++){
            addressTemps[i]=members[i].account;
            stringTemps[i]=stringToBytes32(members[i].name);
        }
        return (addressTemps,stringTemps);
    }
    function stringToBytes32(string memory source)public pure returns (bytes32 result) {
        bytes memory tempEmptyStringTest = bytes(source);
        if (tempEmptyStringTest.length == 0) {
            return 0x0;
        }
    
        assembly {
            result := mload(add(source, 32))
        }
    }
    */
    function removeMember(address targetMember) public onlyMembers{
        for(uint i=0;i<members.length;i++){
            if(members[i].account==member[targetMember].account){
                members[i].account=members[members.length-1].account;
                members[i].name=members[members.length-1].name;
                members[i].memberSince=members[members.length-1].memberSince;
                members[i].token=members[members.length-1].token;
            }
        }
        delete members[members.length-1];
        members.length--;

        emit MembershipChanged(targetMember, false);
    }

    /*******************************************************/

    uint public numProposals;
    uint public deadLine;
    
    struct PropDetail{
        uint proposalId;        string description;        string details;      string attachments;
    }
    mapping(uint => PropDetail)propsDetail;
    struct Proposal {
        uint proposalId;        address recipient;        uint weiAmount; 
        uint minExecutionDate;        bool executed;        bool proposalPassed;        uint numberOfVotes;
        uint currentResult;        mapping (address => bool) voted;
        uint typeOfProposal;         address account;            string accountName;
    }
    mapping(uint => Proposal)proposal;
    
    function newProposal(address _recipient,uint _amount,uint _dayDeadLine,uint8 _typeOfProposal,
    address _account,string memory _accountName,string memory _description,
    string memory _details,string memory _attachments)
        onlyMembers public{
        uint id=numProposals;
        
        if(_typeOfProposal==0){
            member[_recipient].token-=10;
        }else if(_typeOfProposal==1){
            member[_recipient].token-=50;
        }else if(_typeOfProposal==2){
            member[_recipient].token-=40;
        }
        
        deadLine=_dayDeadLine;
        proposal[id].recipient = _recipient;
        proposal[id].weiAmount = _amount* 1 ether;
        proposal[id].minExecutionDate=now + _dayDeadLine * 24 * 60;
        proposal[id].executed = false;
        proposal[id].proposalPassed = false;
        proposal[id].numberOfVotes = 0;
        proposal[id].currentResult=0;
        proposal[id].typeOfProposal=_typeOfProposal;
        proposal[id].account=_account;
        proposal[id].accountName=_accountName;

        propsDetail[id].proposalId=id;
        propsDetail[id].description=_description;
        propsDetail[id].details=_details;
        propsDetail[id].attachments=_attachments;

        emit ProposalAdded(id);
        numProposals++;
    }
    event ProposalAdded(uint proposalId);

    function getProposal(uint _id)public onlyMembers view
        returns(address recipient,uint amount,string memory desc,string memory details,
            uint min,bool exec,uint voteNums,
            uint current,uint types,address account,string memory name){
            
            recipient=proposal[_id].recipient;
            amount=proposal[_id].weiAmount;
            desc= propsDetail[_id].description;
            details=propsDetail[_id].details;
            min=deadLine;
            exec=proposal[_id].executed;
            voteNums=proposal[_id].numberOfVotes;
            current=proposal[_id].currentResult;
            types=proposal[_id].typeOfProposal;
            account=proposal[_id].account;
            name=proposal[_id].accountName;
            
            return(recipient,amount,desc,details,min,exec,voteNums,current,types,account,name);  
    }
    
    
    event Voted(bool support, address account,string comment, uint numbers);
    struct Vote {
        bool inSupport;        address voter;        string justification;
    }
    function vote(uint proposalNumber,bool supportsProposal,string memory justificationText)
        onlyMembers public{
        require(!proposal[proposalNumber].voted[msg.sender]); 
        proposal[proposalNumber].voted[msg.sender] = true; 
        proposal[proposalNumber].numberOfVotes++;  
        if (supportsProposal) { 
            proposal[proposalNumber].currentResult++;
        } else {
            proposal[proposalNumber].currentResult--; 
        }
        emit Voted(supportsProposal, msg.sender,justificationText, proposal[proposalNumber].numberOfVotes);
    }


    uint public minimumQuorum;
    uint public majorityMargin;
    
    event ProposalExecuted(uint currentResult, uint voteNumbers,uint types,address account,string name);

    function executeProposal(uint proposalId) public onlyMembers{
        minimumQuorum = members.length / 2;
        majorityMargin= proposal[proposalId].numberOfVotes / 2 + 1;
        require(now > proposal[proposalId].minExecutionDate                                          
            && !proposal[proposalId].executed                                                       
            && proposal[proposalId].numberOfVotes >= minimumQuorum
            );              
        if (proposal[proposalId].currentResult >= majorityMargin) {
            proposal[proposalId].executed = true; 
            proposal[proposalId].proposalPassed = true;
            if(proposal[proposalId].typeOfProposal==1){
                addMember(proposal[proposalId].account,proposal[proposalId].accountName);
            }else if(proposal[proposalId].typeOfProposal==2){
                removeMember(proposal[proposalId].account);
            }
        } else {
            proposal[proposalId].proposalPassed = false;
        }
        emit ProposalExecuted(proposal[proposalId].currentResult,
            proposal[proposalId].numberOfVotes,proposal[proposalId].typeOfProposal
            ,proposal[proposalId].account,proposal[proposalId].accountName);
    }
}