// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;
import "./ERC20.sol";
import "./VoteToken.sol";
import "./Staking.sol";


/**
 * @dev     Contracts that allows users to lock the voteToken to get the voting power, that can be queried at different time points.
 * @notice  Vote weight decays linearly over time. Lock time cannot be more than 4 years. Decayed value can be withdrawn.
 */

contract Voting {

    enum VoteStatus {
        NO_VOTE,
        NO,
        YES
    }

    struct Proposal {
        address proposalExecutor;
        uint256 yes;
        uint256 no;
        uint256 creationTime;
        bool executed;
    }

    Staking staking;

    uint256 immutable public minProposePowerDivisor;
    uint256 public lastProposalId;
    mapping(uint256 => Proposal) public proposals;

    uint256 public voteTime;
    mapping(address => VoteStatus) public voteStatus;

    constructor(Staking _staking) {
        staking = _staking;
        minProposePowerDivisor = 100; // 1% of the voting power is needed to create a proposal
        voteTime = 1; // At least one whole epoch must available for voting
    }

    /**
     * @dev     Function to create a proposal. The proposer must fullfill the minum voting power
                requirement to prevent spam.
     * @param   proposalExecutor defines the exact mechanics of the execution, will be delegatecalled.
     * @return  proposalId the id of the proposalis returned
     */
    function createProposal(address proposalExecutor) external returns (uint proposalId) {
        uint256 proposerPower = staking.votingPower(msg.sender); 
        require(proposerPower * minProposePowerDivisor >= staking.totalVotingPower(), "Not enough voting power to propose"); 


        // store proposal settings
        Proposal memory proposal = Proposal({
            proposalExecutor: proposalExecutor,
            creationTime: staking.currentEpoch(),
            yes: 0,
            no: 0,
            executed: false
            });
        proposals[lastProposalId] = proposal;
        lastProposalId += 1;

        // Automatic voting mechanism
        proposal.yes += proposerPower; 

        // The last proposalId stored is the one of this proposal
        proposalId = lastProposalId; 
    }

    /**
     * @dev     Function to create vote on a proposal. Change vote mechanics implemented
     * @param   proposalId which proposal is voted on.
     * @param   yes is true -> YES, otherwise NO
     * @return  votes of the user are returned
     */
    function vote(uint256 proposalId, bool yes) external returns (uint256 votes) {
        Proposal storage proposal = proposals[proposalId];

        // Voting time has not passed
        require(proposal.creationTime + voteTime <= staking.currentEpoch(), "Voting period has not ended"); 
        
        
        // Voting mechanics allow also for changing votes
        votes = staking.votingPowerAt(msg.sender, proposal.creationTime - 1);
        VoteStatus userVoteStatus = voteStatus[msg.sender];
        if (userVoteStatus == VoteStatus.NO_VOTE) {
            if (yes) {
                proposal.yes += votes;
            }
            else {
                proposal.no += votes;
            }
        } else if (userVoteStatus == VoteStatus.NO && yes) {
            proposal.yes += votes;
            proposal.no -= votes;
        } else if (userVoteStatus == VoteStatus.YES && !yes) {
            proposal.yes -= votes;
            proposal.no += votes;
        }
        
        return votes;
    }

    /**
     * @dev     Function to execute a proposal
     * @param   proposalId which proposal to execute
     */
    function executeProposal(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];

        require(proposal.yes > proposal.no, "Majority did not vote yes");
        require(proposal.creationTime + voteTime <= staking.currentEpoch(), "Voting period has not ended"); 
        require(!proposal.executed, "Proposal already executed");

        // delegatecall and get into the fallback function
        (bool success, ) = proposal.proposalExecutor.delegatecall("");
        require(success, "execution not successful");

        proposal.executed = true;
    }


}