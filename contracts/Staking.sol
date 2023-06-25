// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;
import "./ERC20.sol";
import "./VoteToken.sol";

/**
 * @dev     Contracts that allows users to lock the voteToken to get the voting power, that can be queried at different time points.
 * @notice  Vote weight decays linearly over time. Lock time cannot be more than 4 years. Decayed value can be withdrawn.
 */

contract Staking {


    uint public startTime = block.timestamp;

    struct Line{
        uint bias;
        int slope;
    }

    struct Stake {
        mapping(uint => int) slopeChange; // epoch -> slope change
        mapping(uint => uint) deposits; // epoch -> deposit event
        Line line;
        uint lastUpdateEpoch;
        uint deposited;
    }


    mapping(address=>Stake) public stakes;

    Stake public totalStake;

    ERC20 immutable public voteToken;


    uint constant ONE_YEAR   = 1 days * 365;
    uint constant FOUR_YEARS = ONE_YEAR * 4;
    uint constant WEEK = 1 weeks;

    constructor(ERC20 _voteToken) {
        voteToken = _voteToken;
    }

    // EPOCH FUNCTIONS

    /**
     * @notice  Epochs start with 1. 1 Epoch == 1 week
     * @dev     Get epoch number for given timestamp
     * @param   time timestamp 
     * @return  uint  epoch number
     */
    function getEpoch(uint time) public view returns (uint){
        return (time - startTime) / WEEK + 1;
    }

    /**
     * @dev     get epoch of current block timestamp
     * @return  uint  epoch number of the current block
     */
    function currentEpoch() public view returns (uint){
        return getEpoch(block.timestamp);
    }

    // STAKING FUNCTIONALITY

    function _getPastLine(Stake storage stake, uint epoch) private view returns (Line memory) {
        Line memory line = stake.line;
        for (uint i = stake.lastUpdateEpoch; i>epoch; i--){ 
            line.bias += uint(line.slope); 
            line.bias -= stake.deposits[i];
            line.slope -= stake.slopeChange[i];
        }
        return line;
    }

    function _getFutureLine(Stake storage stake, uint epoch) private view returns (Line memory) {
        Line memory line = stake.line;

        for (uint i = stake.lastUpdateEpoch+1; i<=epoch; i++){ 
            line.bias += stake.deposits[i];
            line.bias -= uint(line.slope);
            line.slope += stake.slopeChange[i];
        }
        return line;
    }


    function _getLineAt(Stake storage stake, uint epoch) private view returns (Line memory) {
        uint cur_epoch = currentEpoch();
        if (epoch >= stake.lastUpdateEpoch) {
            return _getFutureLine(stake, epoch);
        } else {
            return _getPastLine(stake, epoch);
        }
    }


    function _updateStake(Stake storage stake) private returns (uint) {
        uint epoch = currentEpoch();
        stake.line = _getFutureLine(stake, epoch);
        stake.lastUpdateEpoch = epoch;
    }

    /**
     * @dev     Function for creation of the stake.
     * @param   amount  amount of tokens that 
     * @param   durationEpochs  For how long the amount will be locked, in epochs
     */
    function lock(uint256 amount, uint durationEpochs) public {
        require(durationEpochs <= FOUR_YEARS / WEEK, "Too long lock period");
        require(durationEpochs >= 4, "Too short lock period" );

        uint newSlope = amount / durationEpochs; 
        uint newBias = amount; 

        voteToken.transferFrom(msg.sender, address(this), amount);

        uint epoch = currentEpoch();
        Stake storage stake = stakes[msg.sender];


        stake.deposited += amount;
        stake.deposits[epoch] += amount;
        stake.slopeChange[epoch] += int(newSlope);
        stake.slopeChange[epoch + durationEpochs] -= int(newSlope);
        _updateStake(stake);


        totalStake.deposited += amount;
        totalStake.deposits[epoch] += amount;
        totalStake.slopeChange[epoch] += int(newSlope);
        totalStake.slopeChange[epoch + durationEpochs] -= int(newSlope);
        _updateStake(totalStake);
    }


    function unlock() public {
        Stake storage stake = stakes[msg.sender];
        _updateStake(stake);
        voteToken.transfer(msg.sender, stake.deposited - stake.line.bias);
        stake.deposited -= stake.line.bias; 
    }

    // VOTING power

    function votingPower(address user) public view returns (uint){ 
        return _getLineAt(stakes[msg.sender], currentEpoch()).bias;
    }

    function votingPowerAt(address user, uint epoch) public view returns (uint){
        return _getLineAt(stakes[msg.sender], epoch).bias;
    }


    function totalVotingPower() public view returns (uint){
        return _getFutureLine(totalStake, currentEpoch()).bias;
    }

    function totalVotingPowerAt(uint epoch) public view returns (uint){
        return _getLineAt(totalStake, epoch).bias;
    }

}