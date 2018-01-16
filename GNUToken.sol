pragma solidity ^0.4.15;
import './ERC20Token.sol';
import './TokenHolder.sol';


contract GNUToken is ERC20Token, TokenHolder {

    uint256 constant public GNU_UNIT = 10 ** 18;
    uint256 public totalSupply = 50 * (10**6) * GNU_UNIT;

    //  Constants 
    uint256 constant public maxPresaleSupply = 1 * 10**6 * GNU_UNIT;
    uint256 constant public minCrowdsaleAllocation = 20 * 10**6 * GNU_UNIT;
    uint256 constant public incentivisationAllocation = 20 * 10**6 * GNU_UNIT;
    uint256 constant public advisorsAllocation = 5 * 10**6 * GNU_UNIT;
    uint256 constant public GNUTeamAllocation = 5 * 10**6 * GNU_UNIT;

    address public crowdFundAddress;
    address public advisorAddress;
    address public incentivisationFundAddress;
    address public GNUTeamAddress;



    uint256 public totalAllocatedToAdvisors = 0; 
    uint256 public totalAllocatedToTeam = 0; 
    uint256 public totalAllocated = 0; 
    uint256 constant public endTime = 1516038382;					//end time			

    bool internal isReleasedToPublic = false;

    uint256 internal teamTranchesReleased = 0;
    uint256 internal maxTeamTranches = 8;

    modifier safeTimelock() {
        require(now >= endTime + 6 * 4 weeks);
        _;
    }

    modifier advisorTimelock() {
        require(now >= endTime + 2 * 4 weeks);
        _;
    }

    modifier crowdfundOnly() {
        require(msg.sender == crowdFundAddress);
        _;
    }

    /**
        @dev constructor
        @param _crowdFundAddress   Crowdfund address
        @param _advisorAddress     Advisor address
    */
    function GNUToken(address _crowdFundAddress, address _advisorAddress, address _incentivisationFundAddress, address _GNUTeamAddress)
    ERC20Token("Genun Coin","GNU",18)
     {
        crowdFundAddress = _crowdFundAddress;
        advisorAddress = _advisorAddress;
        GNUTeamAddress = _GNUTeamAddress;
        incentivisationFundAddress = _incentivisationFundAddress;
        balanceOf[_crowdFundAddress] = minCrowdsaleAllocation + maxPresaleSupply; // Total presale + crowdfund tokens
        balanceOf[_incentivisationFundAddress] = incentivisationAllocation;       // 10% Allocated for Marketing and Incentivisation
        totalAllocated += incentivisationAllocation;                              // Add to total Allocated funds
    }

///////////////////////////////////////// ERC20 OVERRIDE /////////////////////////////////////////

    /**
        @dev send coins
        throws on any error rather then return a false flag to minimize user errors
        in addition to the standard checks, the function throws if transfers are disabled

        @param _to      target address
        @param _value   transfer amount

        @return true if the transfer was successful, throws if it wasn't
    */
    function transfer(address _to, uint256 _value) public returns (bool success) {
        if (isTransferAllowed() == true || msg.sender == crowdFundAddress || msg.sender == incentivisationFundAddress) {
            assert(super.transfer(_to, _value));
            return true;
        }
        revert();        
    }

    /**
        @dev an account/contract attempts to get the coins
        throws on any error rather then return a false flag to minimize user errors
        in addition to the standard checks, the function throws if transfers are disabled

        @param _from    source address
        @param _to      target address
        @param _value   transfer amount

        @return true if the transfer was successful, throws if it wasn't
    */
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        if (isTransferAllowed() == true || msg.sender == crowdFundAddress || msg.sender == incentivisationFundAddress) {        
            assert(super.transferFrom(_from, _to, _value));
            return true;
        }
        revert();
    }

    /**
        @dev Release one single tranche of the GNU Team Token allocation
        throws if before timelock (6 months) ends and if not initiated by the owner of the contract
        returns true if valid
        Schedule goes as follows:
        3 months: 12.5% (this tranche can only be released after the initial 6 months has passed)
        6 months: 12.5%
        9 months: 12.5%
        12 months: 12.5%
        15 months: 12.5%
        18 months: 12.5%
        21 months: 12.5%
        24 months: 12.5%
        @return true if successful, throws if not
    */
    function releaseGNUTeamTokens() safeTimelock ownerOnly returns(bool success) {
        require(totalAllocatedToTeam < GNUTeamAllocation);

        uint256 GNUTeamAlloc = GNUTeamAllocation / 1000;
        uint256 currentTranche = uint256(now - endTime) / 12 weeks;     // "months" after crowdsale end time (division floored)

        if(teamTranchesReleased < maxTeamTranches && currentTranche > teamTranchesReleased) {
            teamTranchesReleased++;

            uint256 amount = safeMul(GNUTeamAlloc, 125);
            balanceOf[GNUTeamAddress] = safeAdd(balanceOf[GNUTeamAddress], amount);
            Transfer(0x0, GNUTeamAddress, amount);
            totalAllocated = safeAdd(totalAllocated, amount);
            totalAllocatedToTeam = safeAdd(totalAllocatedToTeam, amount);
            return true;
        }
        revert();
    }

    /**
        @dev release Advisors Token allocation
        throws if before timelock (2 months) ends or if no initiated by the advisors address
        or if there is no more allocation to give out
        returns true if valid

        @return true if successful, throws if not
    */
    function releaseAdvisorTokens() advisorTimelock ownerOnly returns(bool success) {
        require(totalAllocatedToAdvisors == 0);
        balanceOf[advisorAddress] = safeAdd(balanceOf[advisorAddress], advisorsAllocation);
        totalAllocated = safeAdd(totalAllocated, advisorsAllocation);
        totalAllocatedToAdvisors = advisorsAllocation;
        Transfer(0x0, advisorAddress, advisorsAllocation);
        return true;
    }

    /**
        @dev Retrieve unsold tokens from the crowdfund
        throws if before timelock (6 months from end of Crowdfund) ends and if no initiated by the owner of the contract
        returns true if valid

        @return true if successful, throws if not
    */
    function retrieveUnsoldTokens() safeTimelock ownerOnly returns(bool success) {
        uint256 amountOfTokens = balanceOf[crowdFundAddress];
        balanceOf[crowdFundAddress] = 0;
        balanceOf[incentivisationFundAddress] = safeAdd(balanceOf[incentivisationFundAddress], amountOfTokens);
        totalAllocated = safeAdd(totalAllocated, amountOfTokens);
        Transfer(crowdFundAddress, incentivisationFundAddress, amountOfTokens);
        return true;
    }

    /**
        @dev Keep track of token allocations
        can only be called by the crowdfund contract
    */
    function addToAllocation(uint256 _amount) crowdfundOnly {
        totalAllocated = safeAdd(totalAllocated, _amount);
    }

    /**
        @dev Function to allow transfers
        can only be called by the owner of the contract
        Transfers will be allowed regardless after the crowdfund end time.
    */
    function allowTransfers() ownerOnly {
        isReleasedToPublic = true;
    } 

    /**
        @dev User transfers are allowed/rejected
        Transfers are forbidden before the end of the crowdfund
    */
    function isTransferAllowed() internal constant returns(bool) {
        if (now > endTime || isReleasedToPublic == true) {
            return true;
        }
        return false;
    }
}
