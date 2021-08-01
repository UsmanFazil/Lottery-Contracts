//SPDX-License-Identifier: MIT
pragma solidity >0.6.0;
pragma experimental ABIEncoderV2;


import "./SafeMath.sol";
import "./Address.sol";
import "./IERC20.sol";
import "./Ownable.sol";



import "@chainlink/contracts/src/v0.6/VRFConsumerBase.sol";


/**
 * We have followed general OpenZeppelin guidelines: functions revert instead
 * of returning `false` on failure. This behavior is nonetheless conventional
 * and does not conflict with the expectations of ERC20 applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See {IERC20-approve}.
 */
 
contract FunLottery is Ownable, VRFConsumerBase{
    
    using Address for address;
    using SafeMathImp for uint256;
    
    bytes32 internal keyHash;
    uint256 internal fee;

    IERC20 internal func_;


    // structure to store information of lottery
    struct LotteryInfo {
        uint256 lotId;
        uint256 ticketCounter;
        uint256 size;
        uint256 maxtickets;
        uint256 winNumber;
    }
    
    struct Ticket {
        uint256 ticketId;
        bool redeemed;
    }
    
    struct winnerReq{
        uint256 size;
        uint256 lotId;
    }
    
    struct segment{
        uint256 StartNum;
        uint256 rollStart;
        uint256 EndNum;
        uint256 rollEnd;
    }


    // mapping for lottery size => id => info
    mapping (uint256 => mapping( uint256 => LotteryInfo) ) public allLoteries;
    
    // mapping for latest lottery ids against size.  
    mapping (uint256 => uint256)public latestIds;
    
    //mapping to store data of user's tickets
    mapping(address => mapping(uint256=> mapping(uint256 =>mapping(uint256=> Ticket)) ) ) public userTickets;
    
    // user address -> lottery size -> lottery id -> array of ticket numbers
    mapping(address => mapping(uint256=> mapping(uint256 =>uint256[]) ) ) public userTicketIds;
    
    
    // mapping to store requestid against lotterinfo 
    mapping(bytes32 => winnerReq) internal randomReq;
    
    // event for user ticket purchase
    event TicketPurchase(uint256 lottid_, uint256 totaltickets_);
    
    // event for new lottery registration 
    event NewLottery(uint256 size, uint256 lotteryId, uint256 maxtickets);
    
    constructor(address _func)
        VRFConsumerBase(
            0x747973a5A2a4Ae1D3a8fDF5479f1514F65Db9C31, // VRF Coordinator
            0x404460C6A5EdE2D891e8297795264fDe62ADBB75  // LINK Token
        ) public{
        
        require( _func != address(0), "Contracts cannot be 0 address");
        
        keyHash = 0xc251acd21ec4fb7f31bb8868288bfdbaeb4fbfec2df3735ddbd4f7dc8d60103c;
        fee = 0.2 * 10 ** 18; // 0.1 LINK
        
        func_ = IERC20(_func);
        
    }

    
    // function to create new Lottery, only owner can create new lottery
    function createLotto(uint256 _size, uint256 _maxtickets)public onlyOwner {
        require(_size > 0,
            "Prize can not be zero"
        );
        
        require(_maxtickets > 0, 
            "Ticket limit should be greater than zero"
        );
        
        require (latestIds[_size] == 0 ,
            "Lottery size already exists"
        );

        
        newLotto(_size,_maxtickets);
            
    }
    
    // function to initallize new lottery. Private function could be called only inside the smart contract.
    function newLotto(uint256 _size,uint256 _maxtickets)private{
        
        latestIds[_size]= latestIds[_size].adder(1);
        
        LotteryInfo memory newLottery = LotteryInfo(
            latestIds[_size],
            0,
            _size,
            _maxtickets,
            0
        );
            
        allLoteries[_size][latestIds[_size]] = newLottery;

        
        emit NewLottery(_size,latestIds[_size], _maxtickets);
    }
    
    
    // function to buy new ticker for the lottery. 
    // Using this function user can buy multiple tickets as well.
    
    function buyticket(uint256 _size, uint256 totalTickets) public {
        require(totalTickets > 0, 
        "Amount can not be zero"
        );
        
        uint256 id = latestIds[_size];
        
        require( allLoteries[_size][id].maxtickets >= (allLoteries[_size][id].ticketCounter.add(totalTickets) ), 
        "Not enough tickets available"
        );
        
        
        
        
        batchticket(msg.sender, _size, id, totalTickets, allLoteries[_size][id].ticketCounter);
        
        allLoteries[_size][id].ticketCounter = allLoteries[_size][id].ticketCounter.add(totalTickets);
        
        if (allLoteries[_size][id].ticketCounter == allLoteries[_size][id].maxtickets){
            
            newLotto(_size, allLoteries[_size][id].maxtickets);
            generateWinningNum(id, _size);
        }
        
        uint256 funCoins = totalTickets.multip(100000000);
        
        func_.transferFrom(
            msg.sender,
            address(this),
            funCoins
        );
        
        emit TicketPurchase(id, totalTickets);
        
    }
    
    function generateWinningNum(uint256 _id, uint256 _size)internal{
        bytes32 reqId;
        
        reqId = getRandomNumber(_id);
        
        winnerReq memory newReq = winnerReq(
            _size,
            _id
        );
            
        randomReq[reqId] = newReq;
        
    }
    
    //internal function to map tickets against user address
    function batchticket(address _user, uint256 _size, uint256 lotId,uint256 _tickets, uint256 _ticketCounter)internal {
        
        for (uint8 i = 0; i < _tickets; i++) {
            Ticket memory newticket = Ticket(
                _ticketCounter.adder(1),
                false
            );
            
            userTickets[_user][_size][lotId][_ticketCounter.adder(1)] = newticket;
            
            userTicketIds[_user][_size][lotId].push(_ticketCounter.adder(1));
            
            _ticketCounter++;
            
        }
            
    }

    
    // function to get user tickets 
   function getUserTickets(uint256 _lotteryId,address _user, uint256 _size) external view returns(uint256[] memory ) {
       
        return userTicketIds[_user][_size][_lotteryId] ;
    }
    
    
    // function to get the ID of active lotteries 
    function getLottoId(uint256 _size)public view returns(uint256){
        return latestIds[_size];
    }
    
    
    // function to withdraw Func coins from the smart contract (only for admin) 
    function adminWithdraw(uint256 _amount)public onlyOwner{
        
        func_.transfer(
            msg.sender,
            _amount
            );
            
    }

    
    function claimMultiple(uint256[] memory _sizes, uint256[] memory _lotteryids, uint256[] memory _ticketnums)public {
        
        require(_sizes.length == _lotteryids.length, "Array sizes does not match");
        require(_sizes.length == _ticketnums.length, "Array sizes does not match");
        
        uint256 totalReward;
        
        for (uint256 i = 0; i< _sizes.length; i++){
            totalReward = totalReward.adder( RewardCalculation(_sizes[i], _lotteryids[i], _ticketnums[i]) ); 
        }
        
        if (totalReward> 0){
            
            func_.transfer(
                msg.sender,
                totalReward
            );            
        }
        
    }
    
    function RewardCalculation(uint256 _size,uint256 _lotteryid,uint256 _ticketnum)internal  returns(uint256){
       
        uint256 prizeAmount = 0;
        uint256 winningNum = allLoteries[_size][_lotteryid].winNumber;
        uint256 _maxtickets=   allLoteries[_size][_lotteryid].maxtickets;
        uint256 _segmentsize = _maxtickets.div(4);
        
     // Checks the lottery winning numbers are available 
        require(
            winningNum != 0,
            "Winning Numbers not chosen yet"
        );
        
        require(
            userTickets[msg.sender][_size][_lotteryid][_ticketnum].ticketId == _ticketnum,
            "Only the owner can claim"
        );
        
        require(
           userTickets[msg.sender][_size][_lotteryid][_ticketnum].redeemed == false,
            "Already redeemed"
        );
        
        // redeemed Process Start
        userTickets[msg.sender][_size][_lotteryid][_ticketnum].redeemed = true;
        
        
        // segmentSet memory newSeg;
        segment[4] memory segList;
        
        
        
        for (uint256 i=0; i<4; i++){
            
            (segList[i].StartNum, segList[i].EndNum, segList[i].rollStart, segList[i].rollEnd) = calculateSegment(winningNum, _size, _maxtickets, i, _segmentsize);
            
        }
        

        if (_ticketnum == winningNum){ 
            prizeAmount = _size.mul(100000000).div(2); // 50%  
        } 
        
        else if (_ticketnum == segList[1].StartNum){ // 2nd prize
            prizeAmount = percentage(_size,10).mul(100000000); // 10% 
        }
        
        else if (_ticketnum == segList[2].StartNum){ // 3rd prize
            prizeAmount = percentage(_size,5).mul(100000000); // 5% 
        }
        
        else if ( ((_ticketnum > segList[0].StartNum) && (_ticketnum <= segList[0].rollEnd)) || ((_ticketnum > segList[0].rollStart) && (_ticketnum <= segList[0].EndNum))){
            prizeAmount = percentage(_size,18).mul(100000000).div(percentage(_size,10).sub(3)); // 18%
        }
        
        else if ( ((_ticketnum > segList[1].StartNum) && (_ticketnum <= segList[1].rollEnd)) || ((_ticketnum > segList[1].rollStart) && (_ticketnum <= segList[1].EndNum))){
            prizeAmount = percentage(_size,6).mul(100000000).div(percentage(_size,10)); // 6%
        }
        
        else if ( ((_ticketnum > segList[2].StartNum) && (_ticketnum <= segList[2].rollEnd)) || ((_ticketnum > segList[2].rollStart) && (_ticketnum <= segList[2].EndNum))){
            prizeAmount = percentage(_size,7).mul(100000000).div(percentage(_size,20)); // 7%
        }
        
        else if ( ((_ticketnum >= segList[3].StartNum) && (_ticketnum <= segList[3].rollEnd)) || ((_ticketnum >= segList[3].rollStart) && (_ticketnum <= segList[3].EndNum))){
            prizeAmount = percentage(_size,4).mul(100000000).div(percentage(_size,30)); // 4%
        }
        
        return prizeAmount;
   }
    
    
    function calculateReward(uint256 _size,uint256 _lotteryid,uint256 _ticketnum)public view returns(uint256){
       
        uint256 prizeAmount = 0;
        uint256 winningNum = allLoteries[_size][_lotteryid].winNumber;
        uint256 _maxtickets=   allLoteries[_size][_lotteryid].maxtickets;
        uint256 _segmentsize = _maxtickets.div(4);
        
        // segmentSet memory newSeg;
        segment[4] memory segList;


        for (uint256 i=0; i<4; i++){
            
            (segList[i].StartNum, segList[i].EndNum, segList[i].rollStart, segList[i].rollEnd) = calculateSegment(winningNum, _size, _maxtickets, i, _segmentsize);
            
        }
        

        if (_ticketnum == winningNum){ 
            prizeAmount = _size.mul(100000000).div(2); // 50%  
        } 
        
        else if (_ticketnum == segList[1].StartNum){ // 2nd prize
            prizeAmount = percentage(_size,10).mul(100000000); // 10% 
        }
        
        else if (_ticketnum == segList[2].StartNum){ // 3rd prize
            prizeAmount = percentage(_size,5).mul(100000000); // 5% 
        }
        
        else if ( ((_ticketnum > segList[0].StartNum) && (_ticketnum <= segList[0].rollEnd)) || ((_ticketnum > segList[0].rollStart) && (_ticketnum <= segList[0].EndNum))){
            prizeAmount = percentage(_size,18).mul(100000000).div(percentage(_size,10).sub(3)); // 18%
        }
        
        else if ( ((_ticketnum > segList[1].StartNum) && (_ticketnum <= segList[1].rollEnd)) || ((_ticketnum > segList[1].rollStart) && (_ticketnum <= segList[1].EndNum))){
            prizeAmount = percentage(_size,6).mul(100000000).div(percentage(_size,10)); // 6%
        }
        
        else if ( ((_ticketnum > segList[2].StartNum) && (_ticketnum <= segList[2].rollEnd)) || ((_ticketnum > segList[2].rollStart) && (_ticketnum <= segList[2].EndNum))){
            prizeAmount = percentage(_size,7).mul(100000000).div(percentage(_size,20)); // 7%
        }
        
        else if ( ((_ticketnum >= segList[3].StartNum) && (_ticketnum <= segList[3].rollEnd)) || ((_ticketnum >= segList[3].rollStart) && (_ticketnum <= segList[3].EndNum))){
            prizeAmount = percentage(_size,4).mul(100000000).div(percentage(_size,30)); // 4%
        }
        
        return prizeAmount;
   }
    
   
   function calculateSegment(uint256 _winningNum,uint256 _size,uint256 _maxtickets,uint256 _segNum,uint256 _segSize)internal pure returns(uint256,uint256,uint256,uint256){
       
       uint256 startNum;
       uint256 endNum;
       uint256 rollStart;
       uint256 rollEnd;
       
       
       if (_segNum == 0){
           startNum = _winningNum;
           startNum = startNum.modd(_maxtickets);
           
           endNum = percentage(_size, 10);
           endNum = endNum.sub(3);
           endNum = _winningNum.adder(endNum);
           endNum = endNum.modd(_maxtickets);
          
       }
       
       else if (_segNum == 1){
           startNum = _winningNum.adder(_segSize);
           startNum = startNum.modd(_maxtickets);
           
           endNum = percentage(_size,10);
           endNum = startNum.adder(endNum);
           endNum = endNum.modd(_maxtickets);
           
       }
       
       else if (_segNum == 2){
           startNum = _winningNum.adder(_segSize.multip(2));
           startNum = startNum.modd(_maxtickets);
           
           endNum = percentage(_size,20);
           endNum = startNum.adder(endNum);
           endNum = endNum.modd(_maxtickets);
       }
       
        else if (_segNum == 3){
           startNum = _winningNum.adder(_segSize.multip(3));
           startNum = startNum.modd(_maxtickets);
           
           endNum = percentage(_size,30);
           endNum = endNum.sub(1);
           endNum = startNum.adder(endNum);
           endNum = endNum.modd(_maxtickets);
       }
       
       rollStart = startNum;
       rollEnd = endNum;
       
       if (startNum > endNum){
           rollStart = 0;
           rollEnd = _maxtickets;
       }
       
       if (startNum == 0){
           startNum = _maxtickets;
       }
       
       if (endNum == 0){
           endNum = _maxtickets;
       }
       
       return (startNum, endNum, rollStart, rollEnd);
       
   }
   
          // function to get number of active lotteries 
    function getTicketsPurchased()public view returns(uint256,uint256,uint256,uint256){
        
        uint256 _size = 100;
        uint256 firstLottery = allLoteries[_size][getLottoId(_size)].ticketCounter;
        
        _size = 1000;        
        uint256 secondLottery = allLoteries[_size][getLottoId(_size)].ticketCounter; 

        _size = 10000;   
        uint256 thirdLottery = allLoteries[_size][getLottoId(_size)].ticketCounter; 
        
        _size = 100000;    
        uint256 fourthLottery = allLoteries[_size][getLottoId(_size)].ticketCounter; 

        return (firstLottery,secondLottery,thirdLottery,fourthLottery);
    } 
    
    
   function getRandomNumber(uint256 userProvidedSeed) internal returns (bytes32 requestId) {
        require(LINK.balanceOf(address(this)) > fee, "Not enough LINK - fill contract with faucet");
        return requestRandomness(keyHash, fee);
    }
    
     /**
     * Callback function used by VRF Coordinator
     */
    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        uint256 size = randomReq[requestId].size; 
        uint256 id = randomReq[requestId].lotId;
        uint256 maxmod = allLoteries[size][id].maxtickets;
        
        allLoteries[size][id].winNumber = randomness.modd(maxmod).adder(1);
        

    }
    
    function percentage(uint256 _number,uint256 _percentage) internal pure returns(uint256) {
        return (_number.div(100).mul(_percentage));
    }
}






