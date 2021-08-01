// SPDX-License-Identifier: MIT
pragma solidity >0.6.0;

import "./Context.sol";
import "./IERC20.sol";
import "./SafeMath.sol";
import "./Address.sol";
import "./Ownable.sol";

 
contract Exchange is Context,Ownable {
    
    using Address for address;
    using SafeMathImp for uint256;
    
    IERC20 internal usdc_;
    IERC20 internal func_;
    
    uint256 public usdRate;
    uint256 public bnbRate;
    uint256 public bnbDecimals;
    uint256 public usdDecimals;
    
    constructor(address usdCoin,address _func, uint256 _usdRate, uint256 _bnbRate)public{
        usdRate = _usdRate;
        bnbRate = _bnbRate;
        
        usdc_ = IERC20(usdCoin);
        func_ = IERC20(_func);
        
    }
    
     receive()external payable{
        uint256 funCoins = msg.value;
        funCoins = funCoins.multip(bnbRate);
        funCoins = funCoins.multip(1e8);
        funCoins = funCoins.divv(1e18);
        
        func_.transfer(
            msg.sender,
            funCoins
        );
    }

    
    function buyWithUsdc(uint256 amount) public returns(bool){
        
        require(amount > 0, "Funds not provided");
        
        usdc_.transferFrom(
            msg.sender,
            address(this),
            amount
        );
        
        uint256 funCoins = amount;
        funCoins = funCoins.multip(bnbRate);
        funCoins = funCoins.multip(1e8);
        funCoins = funCoins.divv(1e18);
        
        func_.transfer(
            msg.sender,
            funCoins
        );
        
        return true;
    }
    
    function updateRates(uint256 _usdRate, uint256 _bnbRate)public onlyOwner{
        usdRate = _usdRate;
        bnbRate = _bnbRate;
    }
    
    function withDrawBnb(uint256 amount, address payable recepient)public payable onlyOwner{
        bool sent = recepient.send(amount);
        require(sent, "Failed to send Ether");
    }
    
    function adminWithdraw(uint256 _amount)public onlyOwner{
        
        func_.transfer(
            msg.sender,
            _amount
            );
            
    }
    
    
    function withdrawUsd(uint256 amount, address payable _recepient) public onlyOwner{
    
        usdc_.transfer(
            _recepient,
            amount
        );
    }
    
}


