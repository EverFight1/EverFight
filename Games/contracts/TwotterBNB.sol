pragma solidity 0.6.2;

import "./BalanceService.sol";
import "./TokenTest.sol";

contract TwotterBNB is Context, Ownable {
    using SafeMath for uint256;

    /*** Variables ***/


    enum BET{ BET1, BET2, BET3, BET4}
    enum STATUS{ INIT, PENDING, CLOSED }

    struct Player {
        address _addr;
        uint256 _amount;
    }

    struct Game {
        uint256 _game;
        STATUS _status;
        BET _winner;
        uint256 _closeTimestamp;
    }

    struct PlayerBet {
        BET _bet;
        uint256 _amount;
    }

    mapping (uint256 => mapping (int => Player[]) ) private _players;
    mapping (uint256 => mapping (address => PlayerBet) ) private _bets;
    mapping (uint256 => mapping (int => uint256) ) private _pools;
    mapping (uint256 => Game) private _games;

    uint256 public _rewardDivisor = 10;
    uint256 public _counterGame = 0;
    uint256 public _gameTimer = 30;
    uint256 _nonce;
    BalanceService _balanceService;

    /*** Constructor ***/


    constructor(address payable balanceService) public {
        _games[_counterGame] = Game(_counterGame, STATUS.INIT,BET.BET1,0);
        _nonce = uint(keccak256(abi.encodePacked(now, msg.sender, _nonce))) % 100;
        _balanceService = BalanceService(balanceService);
    }

    /*** Modifiers ***/


    modifier GiveChangeBack(uint256 amount) {
        _;
        if (msg.value > amount) {
            msg.sender.transfer(msg.value - amount);
        }
    }

    modifier AlreadyMadeBet(){
        require(_bets[_counterGame][msg.sender]._amount == 0, "You can bet only once");
        _;
    }

    modifier MakeStatusPending(){
        _;
        if(_games[_counterGame]._status == STATUS.INIT){
            for(int index = int(BET.BET1); index <= int(BET.BET4); index++){
                if(_players[_counterGame][index].length == 0){
                    return;
                }
            }
            _games[_counterGame]._status = STATUS.PENDING;
            _games[_counterGame]._closeTimestamp = block.timestamp+_gameTimer;
        }
    }

    /*** Functions ***/


    function getBet(uint256 game, address adr) public view returns(BET, uint256){
        return (_bets[game][adr]._bet, _bets[game][adr]._amount);
    }

    function getGameTimer() public view returns(uint256) {
        return _gameTimer;
    }

    function setGameTimer(uint256 timer) public returns(bool) {
        _gameTimer = timer;
        return true;
    }

    function setBalanceService(address payable balanceService) public returns(bool) {
        _balanceService = BalanceService(balanceService);
        return true;
    }

    function setRewardDivisor(uint256 divisor) public returns(bool) {
        _rewardDivisor = divisor;
        return true;
    }

    function getRewardDivisor() public view returns(uint256) {
        return _rewardDivisor;
    }

    function getGame(uint256 game) public view returns(uint256, STATUS, BET, uint256) {
        return (_games[game]._game, _games[game]._status, _games[game]._winner , _games[game]._closeTimestamp);
    }

    function getBetPool(uint256 game, BET bet) public view returns(uint256) {
        return _pools[game][int(bet)];
    }

    function getPlayer(uint256 game, BET bet, uint256 index) public view returns(address, uint256) {
        return (_players[game][int(bet)][index]._addr, _players[game][int(bet)][index]._amount);
    }

    function getPlayersLength(uint256 game, BET bet) public view returns(uint256) {
        return _players[game][int(bet)].length;
    }

    function getBalanceService() public view returns(BalanceService){
        return _balanceService;
    }

    function gameBet(uint256 amount, BET bet) public AlreadyMadeBet MakeStatusPending returns (bool) {
        _players[_counterGame][int(bet)].push(Player(msg.sender, amount));
        _bets[_counterGame][msg.sender] = PlayerBet(bet, amount);
        _pools[_counterGame][int(bet)].add(amount);
//        _balanceService.subBalanceBNB(msg.sender, amount);
        return true;
    }

    function gameClaim(uint256 amount) public payable returns (bool) {
//        _balanceService.subBalanceBNB(msg.sender, amount);
        msg.sender.transfer(amount);
        return true;
    }

    function gameClose() public onlyOwner returns (bool) {
        uint256 _grandTotal;
        uint256 _tenPercentGrandTotal;
        uint256 _ninetyPercentGrandTotal;
        uint256 _playerAmountWinPercent;
        BET _winner = random();
        for(int index = int(BET.BET1); index <= int(BET.BET4); index++){
            _grandTotal += _pools[_counterGame][index];
        }
        _tenPercentGrandTotal = _grandTotal.div(100).mul(_rewardDivisor);
        _ninetyPercentGrandTotal = _grandTotal.div(100).mul(100-_rewardDivisor);
//        _balanceService.addBalanceBNB(address(this), _tenPercentGrandTotal);
        for(uint indexPlayers = 0; indexPlayers < _players[_counterGame][int(_winner)].length; indexPlayers++){
            _playerAmountWinPercent = _players[_counterGame][int(_winner)][indexPlayers]._amount.div(100).mul(_pools[_counterGame][int(_winner)]);
            //_balanceService[_players[_counterGame][int(_winner)][indexPlayers]._addr] = _balanceService[_players[_counterGame][int(_winner)][indexPlayers]._addr].add(_ninetyPercentGrandTotal.div(100).mul(_playerAmountWinPercent));
        }
        _games[_counterGame]._status = STATUS.CLOSED;
        _games[_counterGame]._winner = _winner;
        _counterGame++;
        _games[_counterGame] = Game(_counterGame, STATUS.INIT,BET.BET1,0);
        return true;
    }

    function random() private returns (BET) {
        uint randomNumber = uint(keccak256(abi.encodePacked(now, msg.sender, _nonce))) % 4;
        _nonce++;
        return BET(randomNumber);
    }

    function transferToAddressETH(address payable recipient, uint256 amount) public onlyOwner {
        recipient.transfer(amount);
    }

    receive() external payable {
        revert();
    }
}
