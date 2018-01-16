pragma solidity ^0.4.15;

import './IERC20Token.sol';

contract IGNUToken is IERC20Token {
    function crowdfundAddress() public constant returns (address);
    function incentivisationFundAddress() public constant returns (address);
    function totalAllocated() public constant returns (uint256);
}

contract GNUAllocation {
    address public tokenAddress;
    IGNUToken token;

    function GNUAllocation(address _tokenAddress){
        tokenAddress = _tokenAddress;
        token = IGNUToken(tokenAddress);
    }

    function circulation() constant returns (uint256) {
        return token.totalAllocated() - token.balanceOf(token.incentivisationFundAddress());
    }
}
