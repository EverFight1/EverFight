pragma solidity 0.6.2;

import "./BalanceService.sol";

contract TwotterHolderEF is Context, Ownable {
    using SafeMath for uint256;

    /*** Variables ***/

    enum BET{ BET1, BET2, BET3, BET4}
    enum STATUS{ INIT, PENDING, CLOSED }

    struct Player {
        address payable _addr;
        uint256 _amount;
    }

    struct Game {
        uint256 _game;
        STATUS _status;
        uint256 _startTimestamp;
        uint256 _closeTimestamp;
        uint256 _amountAM;
        uint256 _bet1Pool;
        uint256 _bet2Pool;
        uint256 _bet3Pool;
        uint256 _bet4Pool;
        uint256 _betAllPool;
        BET _winner;
    }

    mapping (uint256 => mapping (int => Player[]) ) private _players;
    mapping (uint256 => Game) private _games;
    mapping (uint256 => mapping (address => bool) ) private _activePlayers;

    uint256 public _counterGame = 0;
    uint256 public _freezeTime = 3*24*60*60;
    uint256 public _minAMHoldTokensValue = 0;
    uint256 public _minEFHoldTokensValue = 0;
    uint256 public _playerAmountWinPercent = 15;
    uint256 _nonce;
    BalanceService _balanceService;
    IBEP20 _alternativeMoneyToken;
    IBEP20 _everFightToken;

    /*** Constructor ***/


    constructor(address payable balanceService, address payable alternativeMoney, address payable everFight) public {
        _balanceService = BalanceService(balanceService);
        _alternativeMoneyToken = IBEP20(alternativeMoney);
        _everFightToken = IBEP20(everFight);
    }

    /*** Modifiers ***/


    modifier checkCloseGame() {
        require(_games[_counterGame]._closeTimestamp < block.timestamp && _games[_counterGame]._status == STATUS.PENDING, "Current game is not over");
        _;
    }

    modifier checkActualGameState(){
        require((_games[_counterGame]._startTimestamp < block.timestamp && _games[_counterGame]._closeTimestamp > block.timestamp) && _games[_counterGame]._status == STATUS.PENDING, "Current game is not running");
        _;
    }

    modifier checkStartAmount(uint256 amount, address IBEP20){
        require(_balanceService.getBalanceIBEP20(address(this), address(_alternativeMoneyToken)) >= amount, "There are insufficient funds in your account");
        _;
    }

    modifier checkMinimumAMValue(){
        require(_balanceService.getBalanceIBEP20(msg.sender, address(_alternativeMoneyToken)) >= _minAMHoldTokensValue, "Don't have enough AM tokens");
        _;
    }

    modifier checkMinimumEFValue(){
        require(_balanceService.getBalanceIBEP20(msg.sender, address(_everFightToken)) >= _minEFHoldTokensValue, "Don't have enough EF tokens");
        _;
    }

    modifier checkAddressAlreadyInGame(){
        require(_activePlayers[_counterGame][msg.sender] == false, "Game: You already in current game");
        _;
    }

    /*** Functions ***/


    function getGameStatus(uint256 game) public view returns(STATUS) {
        return _games[game]._status;
    }

    function getGameTimestamps(uint256 game) public view returns(uint256, uint256) {
        return (
        _games[game]._startTimestamp,
        _games[game]._closeTimestamp
        );
    }

    function getGameAmountAM(uint256 game) public view returns(uint256) {
        return (
        _games[game]._amountAM
        );
    }

    function getGameIndividualBets(uint256 game) public view returns(uint256, uint256, uint256, uint256) {
        return (
        _games[game]._bet1Pool,
        _games[game]._bet2Pool,
        _games[game]._bet3Pool,
        _games[game]._bet4Pool
        );
    }

    function getGameAllPool(uint256 game) public view returns(uint256) {
        return (
        _games[game]._betAllPool
        );
    }

    function getWinnerPool(uint256 game) public view returns(BET) {
        return (
        _games[game]._winner
        );
    }

    function getPlayer(uint256 game, BET bet, uint256 index) public view returns(address, uint256) {
        return (
        _players[game][int(bet)][index]._addr,
        _players[game][int(bet)][index]._amount
        );
    }

    function getPlayersLength(uint256 game, BET bet) public view returns(uint256) {
        return _players[game][int(bet)].length;
    }

    function getBalanceService() public view returns(BalanceService){
        return _balanceService;
    }

    function getAlternativeMoneyToken() public view returns(IBEP20){
        return _alternativeMoneyToken;
    }

    function getEverFightToken() public view returns(IBEP20){
        return _everFightToken;
    }

    function getPlayerAmountWinPercent() public view returns(uint256) {
        return _playerAmountWinPercent;
    }


    function getMinAMHoldTokensValue() public view returns(uint256) {
        return _minAMHoldTokensValue;
    }

    function getMinEFHoldTokensValue() public view returns(uint256) {
        return _minEFHoldTokensValue;
    }

    function getActivePlayer(uint256 game, address addr) public view returns(bool) {
        return _activePlayers[game][addr];
    }

    function setBalanceService(address payable balanceService) public returns(bool) {
        _balanceService = BalanceService(balanceService);
        return true;
    }

    function setAlternativeMoneyToken(address payable alternativeMoneyToken) public returns(bool) {
        _alternativeMoneyToken = IBEP20(alternativeMoneyToken);
        return true;
    }

    function setEverFightToken(address payable everFightToken) public returns(bool) {
        _everFightToken = IBEP20(everFightToken);
        return true;
    }

    function setPlayerAmountWinPercent(uint256 playerAmountWinPercent) public returns(bool) {
        _playerAmountWinPercent = playerAmountWinPercent;
        return true;
    }

    function setMinAMHoldTokensValue(uint256 minAMHoldTokensValue) public returns(bool) {
        _minAMHoldTokensValue = minAMHoldTokensValue;
        return true;
    }

    function setMinEFHoldTokensValue(uint256 minEFHoldTokensValue) public returns(bool) {
        _minEFHoldTokensValue = minEFHoldTokensValue;
        return true;
    }

    function start(uint256 startTimestamp, uint256 closeTimestamp, uint256 amount) public onlyOwner checkStartAmount(amount, address(_alternativeMoneyToken)) returns (bool) {
        _games[_counterGame] = Game(_counterGame, STATUS.PENDING, startTimestamp, closeTimestamp , amount, 0, 0, 0, 0, 0, BET.BET1);
        _balanceService.setBlockedIBEP20(address(this), address(_alternativeMoneyToken), amount, closeTimestamp);
        return true;
    }

    function join(BET bet) public checkActualGameState checkAddressAlreadyInGame checkMinimumAMValue checkMinimumEFValue returns (bool) {
        uint256 amount = _balanceService.getBalanceIBEP20(msg.sender, address(_alternativeMoneyToken));
        _players[_counterGame][int(bet)].push(Player(msg.sender, amount));
        _activePlayers[_counterGame][msg.sender] = true;

        if (BET.BET1 == bet) {
            _games[_counterGame]._bet1Pool = _games[_counterGame]._bet1Pool.add(amount);
        } else if (BET.BET2 == bet) {
            _games[_counterGame]._bet2Pool = _games[_counterGame]._bet2Pool.add(amount);
        } else if (BET.BET3 == bet) {
            _games[_counterGame]._bet3Pool = _games[_counterGame]._bet3Pool.add(amount);
        } else if (BET.BET4 == bet) {
            _games[_counterGame]._bet4Pool = _games[_counterGame]._bet4Pool.add(amount);
        }

        _games[_counterGame]._betAllPool = _games[_counterGame]._betAllPool.add(amount);
        _balanceService.setBlockedIBEP20(msg.sender, address(_alternativeMoneyToken), amount , block.timestamp + _freezeTime);
        return true;
    }

    function close() public checkCloseGame onlyOwner returns (bool) {
        uint256 _winnerPool = _games[_counterGame]._amountAM.div(100).mul(_playerAmountWinPercent);
        uint256 _allPool = _games[_counterGame]._amountAM.sub(_winnerPool);
        BET _winner = random();

        for(uint256 bet = uint256(BET.BET1); bet <= uint256(BET.BET4); bet++){
            for(uint256 indexPlayers = 0; indexPlayers < getPlayersLength(_counterGame, BET(bet)); indexPlayers++){
                winnerPoolPrice(BET(bet), indexPlayers, _allPool, _games[_counterGame]._betAllPool);
            }
        }

        for(uint indexPlayers = 0; indexPlayers < getPlayersLength(_counterGame, _winner); indexPlayers++){
            if(BET.BET1 == _winner){
                winnerPoolPrice(_winner, indexPlayers, _winnerPool, _games[_counterGame]._bet1Pool);
            } else if (BET.BET2 == _winner) {
                winnerPoolPrice(_winner, indexPlayers, _winnerPool, _games[_counterGame]._bet2Pool);
            } else if (BET.BET3 == _winner) {
                winnerPoolPrice(_winner, indexPlayers, _winnerPool, _games[_counterGame]._bet3Pool);
            } else if (BET.BET4 == _winner) {
                winnerPoolPrice(_winner, indexPlayers, _winnerPool, _games[_counterGame]._bet4Pool);
            }
        }

        _games[_counterGame]._status = STATUS.CLOSED;
        _games[_counterGame]._winner = _winner;
        _counterGame++;
        return true;
    }

    function random() private returns (BET) {
        uint randomNumber = uint(keccak256(abi.encodePacked(now, msg.sender, _nonce))) % 4;
        _nonce++;
        return BET(randomNumber);
    }

    function winnerPoolPrice(BET bet, uint256 indexPlayers, uint256 winnerPool, uint256 betPool) private returns (bool) {
        uint256 _playerPoolPercent = _players[_counterGame][int(bet)][indexPlayers]._amount.div(betPool).mul(1000);
        uint256 _playerPoolReward = winnerPool.mul(_playerPoolPercent).div(1000);
        _balanceService.transferIBEP20(address(_alternativeMoneyToken), _players[_counterGame][int(bet)][indexPlayers]._addr, _playerPoolReward);
        return true;
    }
}
