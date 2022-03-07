pragma solidity 0.6.2;

import "./TokenTest.sol";

contract BalanceService is Context, Ownable {
    using SafeMath for uint256;

    /*** Variables ***/

    event TokenAdded (address _tokenAddress);
    event TokenRemoved (address _tokenAddress);
    event BNBBlocked (address _userAddressBNB, uint256 _amount, uint256 _freezeTime);
    event IBEP20Blocked (address _tokenAddress, address _userAddressIBEP20, uint256 _amount, uint256 _freezeTime);
    event BNBClaimed (address _userAddressBNB, uint256 _amount);
    event IBEP20Claimed (address _tokenAddress, address _userAddressIBEP20, uint256 _amount);
    event BNBTransfered (address _userFromBNB, address _userToBNB, uint256 _amount);
    event IBEP20Transfered (address _tokenAddress, address _userFromIBEP20, address _userToIBEP20, uint256 _amount);
    event Received (address _userFromIBEP20, uint256 _amount);
    event TokenReceived (address _tokenAddress, address _transferFrom, address _transferTo, uint256 _amount);
    event BNBApproved (address _userFromBNB, address _userToBNB, uint256 _amount);
    event IBEP20Approved (address _tokenAddress, address _userFromIBEP20, address _userToIBEP20, uint256 _amount);

    struct Token {
        IBEP20 _token;
        bool _active;
    }

    struct BlockedToken {
        uint256 _amount;
        uint256 _freezeTime;
    }

    mapping (address => uint256) public _balancesBNB;
    mapping (address => mapping (address => uint256)) public _balancesIBEP20;
    mapping (address => bool) private _unblocked;
    mapping (address => BlockedToken) private _blockedBNBs;
    mapping (address => mapping (address => BlockedToken)) private _blockedIBEP20;
    mapping (address => Token) private _tokens;
    address[] public _tokensList;
    mapping (address => mapping (address => uint256)) private _allowancesBNB;
    mapping (address => mapping (address => mapping (address => uint256))) private _allowancesIBEP20;

    /*** Modifiers ***/

    modifier checkTokenState(address token) {
        require(_tokens[token]._active == true, "Token is not active");
        _;
    }

    modifier checkUnblocked(){
        require(_unblocked[msg.sender], "Sender is blocked");
        _;
    }

    modifier checkAmountBNB(address addr, uint256 amount){
        require(getBalanceBNB(addr) >= amount, "There are insufficient funds in your account");
        _;
    }

    modifier checkAmountIBEP20(address addr, uint256 amount, address IBEP20){
        require(getBalanceIBEP20(addr, IBEP20) >= amount, "There are insufficient funds in your account");
        _;
    }

    /*** Functions ***/


    function addToken(address addr) public onlyOwner {
        _tokens[addr] = Token(IBEP20(addr),true);
        _tokensList.push(addr);
        emit TokenAdded(addr);
    }

    function removeToken(address addr) public onlyOwner{
        _tokens[addr] = Token(IBEP20(addr),false);
        emit TokenRemoved(addr);
    }

    function getToken(uint256 index) public view returns(address) {
        return _tokensList[index];
    }

    function getTokenLength() public view returns(uint256) {
        return _tokensList.length;
    }

    function getBalanceBNB(address addr) public view returns(uint256) {
        (uint256 amount,  uint256 freezeTime) = getBlockedBNB(addr);
        if(freezeTime > block.timestamp){
            return _balancesBNB[addr].sub(amount);
        }
        return _balancesBNB[addr];
    }

    function getBalanceIBEP20(address addr, address IBEP20) public view returns(uint256) {
        (uint256 amount,  uint256 freezeTime) = getBlockedIBEP20(addr, IBEP20);
        if(freezeTime > block.timestamp){
            return _balancesIBEP20[addr][IBEP20].sub(amount);
        }
        return _balancesIBEP20[addr][IBEP20];
    }

    function getBlockedBNB(address userAddress) public view returns(uint256, uint256) {
        return (
        _blockedBNBs[userAddress]._amount,
        _blockedBNBs[userAddress]._freezeTime
        );
    }


    function getBlockedIBEP20(address userAddress, address IBEP20) public view returns(uint256, uint256) {
        return (
        _blockedIBEP20[userAddress][IBEP20]._amount,
        _blockedIBEP20[userAddress][IBEP20]._freezeTime
        );
    }

    function getAllowanceBNB(address owner, address spender) public view returns (uint256) {
        return _allowancesBNB[owner][spender];
    }

    function getAllowanceIBEP20(address IBEP20, address owner, address spender) public view returns (uint256) {
        return _allowancesIBEP20[IBEP20][owner][spender];
    }

    function setBlockedBNB(address userAddress, uint256 amount, uint256 time) public checkUnblocked returns(bool) {
        _blockedBNBs[userAddress] = BlockedToken(amount, time);
        emit BNBBlocked(userAddress, amount, time);
        return true;
    }

    function setBlockedIBEP20(address userAddress, address IBEP20, uint256 amount, uint256 time) public checkUnblocked returns(bool) {
        _blockedIBEP20[userAddress][IBEP20] = BlockedToken(amount, time);
        emit IBEP20Blocked(IBEP20, userAddress, amount, time);
        return true;
    }

    function addUnblocked(address addr) public onlyOwner returns (bool) {
        _unblocked[addr] = true;
        return true;
    }

    function deleteUnblocked(address addr) public onlyOwner returns (bool) {
        _unblocked[addr] = false;
        return true;
    }

    function claimBNB(uint256 amount) public checkAmountBNB(msg.sender, amount) payable returns (bool) {
        _balancesBNB[msg.sender] = _balancesBNB[msg.sender].sub(amount);
        msg.sender.transfer(amount);
        emit BNBClaimed(msg.sender, amount);
        return true;
    }

    function claimIBEP20(uint256 amount, address IBEP20) public checkTokenState(IBEP20) checkAmountIBEP20(msg.sender, amount, IBEP20) payable returns (bool) {
        _balancesIBEP20[msg.sender][IBEP20] = _balancesIBEP20[msg.sender][IBEP20].sub(amount);
        _tokens[IBEP20]._token.transfer(msg.sender, amount);
        emit IBEP20Claimed(IBEP20, msg.sender, amount);
        return true;
    }

    function _transferBNB(address sender, address recipient, uint256 amount) private checkAmountBNB(sender, amount) returns (bool) {
        _balancesBNB[recipient] = _balancesBNB[recipient].add(amount);
        _balancesBNB[sender] = _balancesBNB[sender].sub(amount);
        emit BNBTransfered(sender, recipient, amount);
        return true;
    }

    function transferBNB(address recipient, uint256 amount) public returns(bool){
        _transferBNB(msg.sender, recipient, amount);
        return true;
    }

    function _transferIBEP20(address IBEP20, address sender, address recipient, uint256 amount) private checkTokenState(IBEP20) checkAmountIBEP20(sender, amount, IBEP20) returns (bool) {
        _balancesIBEP20[recipient][IBEP20] = _balancesIBEP20[recipient][IBEP20].add(amount);
        _balancesIBEP20[sender][IBEP20] = _balancesIBEP20[sender][IBEP20].sub(amount);
        emit IBEP20Transfered(IBEP20, sender, recipient, amount);
        return true;
    }

    function transferIBEP20(address IBEP20, address recipient, uint256 amount) public returns(bool){
        _transferIBEP20(IBEP20, msg.sender, recipient, amount);
        return true;
    }

    function transferFromBNB(address sender, address recipient, uint256 amount) external returns (bool) {
        _transferBNB(sender, recipient, amount);
        _approveBNB(sender, msg.sender, _allowancesBNB[sender][msg.sender].sub(amount, "BEP20: transfer amount exceeds allowance"));
        return true;
    }

    function transferFromIBEP20(address IBEP20, address sender, address recipient, uint256 amount) external returns (bool) {
        _transferIBEP20(IBEP20, sender, recipient, amount);
        _approveIBEP20(IBEP20, sender, msg.sender, _allowancesIBEP20[IBEP20][sender][msg.sender].sub(amount, "BEP20: transfer amount exceeds allowance"));
        return true;
    }

    function receiveTokens(address tokenAddress, uint256 amount) public {
        _tokens[tokenAddress]._token.transferFrom(msg.sender, address(this), amount);
        _balancesIBEP20[msg.sender][tokenAddress] = _balancesIBEP20[msg.sender][tokenAddress].add(amount);
        emit TokenReceived(tokenAddress, msg.sender, address(this), amount);
    }

    function approveBNB(address spender, uint256 amount) public returns (bool) {
        _approveBNB(msg.sender, spender, amount);
        return true;
    }

    function increaseAllowanceBNB(address spender, uint256 addedValue) public returns (bool) {
        _approveBNB(msg.sender , spender, _allowancesBNB[msg.sender][spender].add(addedValue));
        return true;
    }

    function decreaseAllowanceBNB(address spender, uint256 subtractedValue) public returns (bool) {
        _approveBNB(msg.sender, spender, _allowancesBNB[msg.sender][spender].sub(subtractedValue, "Decreased allowance below zero"));
        return true;
    }

    function approveIBEP20(address IBEP20, address spender, uint256 amount) public returns (bool) {
        _approveIBEP20(IBEP20, msg.sender, spender, amount);
        return true;
    }

    function increaseAllowanceIBEP20(address IBEP20, address spender, uint256 addedValue) public returns (bool) {
        _approveIBEP20(IBEP20, msg.sender , spender, _allowancesIBEP20[IBEP20][msg.sender][spender].add(addedValue));
        return true;
    }

    function decreaseAllowanceIBEP20(address IBEP20, address spender, uint256 subtractedValue) public returns (bool) {
        _approveIBEP20(IBEP20, msg.sender, spender, _allowancesIBEP20[IBEP20][msg.sender][spender].sub(subtractedValue, "Decreased allowance below zero"));
        return true;
    }

    function _approveBNB(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "Approve from the zero address");
        require(spender != address(0), "Approve to the zero address");

        _allowancesBNB[owner][spender] = amount;
        emit BNBApproved(owner, spender, amount);
    }

    function _approveIBEP20(address IBEP20, address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "Approve from the zero address");
        require(spender != address(0), "Approve to the zero address");

        _allowancesIBEP20[IBEP20][owner][spender] = amount;
        emit IBEP20Approved(IBEP20, owner, spender, amount);
    }

    receive() external payable {
        _balancesBNB[msg.sender] = _balancesBNB[msg.sender].add(msg.value);
        emit Received(msg.sender, msg.value);
    }

}
