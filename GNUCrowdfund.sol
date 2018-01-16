pragma solidity ^0.4.15;
import './TokenHolder.sol';
import './GNUToken.sol';


contract GNUCrowdfund is TokenHolder {

    uint256 constant public startTime = 1515692787;
    uint256 constant public endTime = 1516038382;
    uint256 constant internal week2Start = startTime + (7 days);   
    uint256 constant internal week3Start = week2Start + (7 days);  
    uint256 constant internal week4Start = week3Start + (7 days);

    uint256 public totalPresaleTokensYetToAllocate;
    address public beneficiary = 0x0;
    address public tokenAddress = 0x0;

    GNUToken token;

    event CrowdsaleContribution(address indexed _contributor, uint256 _amount, uint256 _return);
    event PresaleContribution(address indexed _contributor, uint256 _amountOfTokens);

    /**
        @dev constructor
        @param _totalPresaleTokensYetToAllocate     Total amount of presale tokens sold
        @param _beneficiary                         Address that will be receiving the ETH contributed
    */
    function GNUCrowdfund(uint256 _totalPresaleTokensYetToAllocate, address _beneficiary) 
    validAddress(_beneficiary) 
    {
        totalPresaleTokensYetToAllocate = _totalPresaleTokensYetToAllocate;
        beneficiary = _beneficiary;
    }


    // Ensures that the current time is between startTime (inclusive) and endTime (exclusive)
    modifier between() {
        assert(now >= startTime && now < endTime);
        _;
    }

    // Ensures the Token address is set
    modifier tokenIsSet() {
        require(tokenAddress != 0x0);
        _;
    }

    /**
        @dev Sets the GNU Token address
        Can only be called once by the owner
        @param _tokenAddress    GNU Token Address
    */
    function setToken(address _tokenAddress) validAddress(_tokenAddress) ownerOnly {
        require(tokenAddress == 0x0);
        tokenAddress = _tokenAddress;
        token = GNUToken(_tokenAddress);
    }

    /**
        @dev Sets a new Beneficiary address
        Can only be called by the owner
        @param _newBeneficiary    Beneficiary Address
    */
    function changeBeneficiary(address _newBeneficiary) validAddress(_newBeneficiary) ownerOnly {
        beneficiary = _newBeneficiary;
    }

    /**
        @dev Function to send GNU to presale investors
        Can only be called while the presale is not over.
        @param _batchOfAddresses list of addresses
        @param _amountofGNU matching list of address balances
    */
    function deliverPresaleTokens(address[] _batchOfAddresses, uint256[] _amountofGNU) external tokenIsSet ownerOnly returns (bool success) {
        require(now < startTime);
        for (uint256 i = 0; i < _batchOfAddresses.length; i++) {
            deliverPresaleTokenToClient(_batchOfAddresses[i], _amountofGNU[i]);            
        }
        return true;
    }

    /**
        @dev Logic to transfer presale tokens
        Can only be called while the there are leftover presale tokens to allocate. Any multiple contribution from 
        the same address will be aggregated.
        @param _accountHolder user address
        @param _amountofGNU balance to send out
    */
    function deliverPresaleTokenToClient(address _accountHolder, uint256 _amountofGNU) internal ownerOnly {
        require(totalPresaleTokensYetToAllocate > 0);
        token.transfer(_accountHolder, _amountofGNU);
        token.addToAllocation(_amountofGNU);
        totalPresaleTokensYetToAllocate = safeSub(totalPresaleTokensYetToAllocate, _amountofGNU);
        PresaleContribution(_accountHolder, _amountofGNU);
    }

///////////////////////////////////////// PUBLIC FUNCTIONS /////////////////////////////////////////
    /**
        @dev ETH contribution function
        Can only be called during the crowdsale. Also allows a person to buy tokens for another address

        @return tokens issued in return
    */
    function contributeETH(address _to) public validAddress(_to) between tokenIsSet payable returns (uint256 amount) {
        return processContribution(_to);
    }

    /**
        @dev handles contribution logic
        note that the Contribution event is triggered using the sender as the contributor, regardless of the actual contributor

        @return tokens issued in return
    */
    function processContribution(address _to) private returns (uint256 amount) {

        uint256 tokenAmount = getTotalAmountOfTokens(msg.value);
        beneficiary.transfer(msg.value);
        token.transfer(_to, tokenAmount);
        token.addToAllocation(tokenAmount);
        CrowdsaleContribution(_to, msg.value, tokenAmount);
        return tokenAmount;
    }


   
    /**
        @dev Returns total tokens allocated so far
        Constant function that simply returns a number

        @return total tokens allocated so far
    */
    function totalGNUSold() public constant returns(uint256 total) {
        return token.totalAllocated();
    }
    
    /**
        @dev computes the number of tokens that should be issued for a given contribution
        @param _contribution    contribution amount
        @return computed number of tokens
    */
    function getTotalAmountOfTokens(uint256 _contribution) public constant returns (uint256 amountOfTokens) {
        uint256 currentTokenRate = 0;
        if (now < week2Start) {
            return currentTokenRate = safeMul(_contribution, 6000);
        } else if (now < week3Start) {
            return currentTokenRate = safeMul(_contribution, 5000);
        } else if (now < week4Start) {
            return currentTokenRate = safeMul(_contribution, 4000);
        } else {
            return currentTokenRate = safeMul(_contribution, 3000);
        }
        
    }

    /**
        @dev Fallback function
        Main entry to buy into the crowdfund, all you need to do is send a value transaction
        to this contract address. Please include at least 100 000 gas in the transaction.
    */
    function() payable {
        contributeETH(msg.sender);
    }
}
