pragma solidity 0.6.2;

import "./BalanceService.sol";

contract CryptoWars is Context, Ownable {
    using SafeMath for uint256;

    /*** Variables ***/

    enum STATUS { STARTED, CLOSED }
    enum CARD { ATTACK, DEFENSE }
    enum ACTION { HOOK, STRAIGHT, LOW_BLOW }

    struct Player {
        string _nickname;
        uint256 _amount;
    }

    struct Game {
        STATUS _gameStatus;
        uint256 _game;
        address _playerAddress;
        uint256 _gameStartTimestamp;
        uint256 _gameCloseTimestamp;
        CharacterSkin _characterData;
        Round[] _rounds;
        bool _cancelGame;
        Card[5] _cardsPlayer;
        Card[5] _cardsBot;
        uint256 _playerHP;
        uint256 _botHP;
    }

    struct CharacterSkin {
        address _characterSkin;
        address _playerAttack;
        address _playerDefence;
        address _playerVitality;
    }

    struct Round {
        STATUS _roundStatus;
        uint256 _roundTimestamp;
        ACTION _playerAttackType;
        ACTION _botAttackType;
        ACTION _playerDefenceType;
        ACTION _botDefenceType;
        uint256 _playerHitHP;
        uint256 _botHitHP;
        Card[] _whichCards;
    }

    struct Card {
        address _cardAddress;
        CARD _cardType;
        uint256 _cardValue;
        bool _isUsed;
    }

    mapping (uint256 => Game) private _games;
    mapping (address => uint256) private _playerLastGame;

    uint256 private _durationRoundTime;
    uint256 private _baseAttack = 3;
    uint256 private _cancelGameTime;
    uint256 private _counterGame = 0;
    uint256 private _minTokensValue = 0;
    uint256 _nonceAttack;
    uint256 _nonceDefence;
    // ERC721

    /*** Constructor ***/


    constructor() public {

    }

    /*** Modifiers ***/

    modifier checkPlayerAlreadyPlaying(){
        require(_games[_playerLastGame[msg.sender]]._gameStatus == STATUS.CLOSED, "Game: You already in game");
        _;
    }

    modifier checkLastStartedGame(){
        require(_games[_playerLastGame[msg.sender]]._gameStatus == STATUS.STARTED);
        _;
    }

    /*** Functions ***/

    function getDurationRoundTime() public view returns(uint256) {
        return _durationRoundTime;
    }

    function getBaseAttack() public view returns(uint256) {
        return _baseAttack;
    }

    function getCancelGameTime() public view returns(uint256) {
        return _cancelGameTime;
    }

    function getMinTokensValue() public view returns(uint256) {
        return _minTokensValue;
    }

    function setDurationRoundTime(uint256 durationRoundTime) public returns(bool) {
        _durationRoundTime = durationRoundTime;
        return true;
    }

    function setBaseAttack(uint256 baseAttack) public returns(bool) {
        _baseAttack = baseAttack;
        return true;
    }

    function setCancelGameTime(uint256 cancelGameTime) public returns(bool) {
        _cancelGameTime = cancelGameTime;
        return true;
    }

    function setMinTokensValue(uint256 minTokensValue) public returns(bool) {
        _minTokensValue = minTokensValue;
        return true;
    }

    function join(address characterSkin, address[5] cards) checkPlayerAlreadyPlaying  public returns (bool) {
        _games[_counterGame] = Game(STATUS.STARTED, _counterGame, msg.sender, block.timestamp , 0, characterSkin, 0, 0, 0, 0, 0, 0);
        _playerLastGame[msg.sender] = _counterGame;
        _counterGame++;
        _games[_playerLastGame[msg.sender]]._rounds.push(Round(STATUS.STARTED, block.timestamp + _durationRoundTime, 0, 0, 0, 0, 0));
        return true;
    }

    function surrender() checkLastStartedGame public returns (bool) {
        _games[_playerLastGame[msg.sender]]._status = STATUS.CLOSED;
        return true;
    }

    function round(ACTION playerAttackType, ACTION playerDefenceType, Card[1] playerAttackCard, Card[1] playerDefenceCard) public returns (bool) {
        Round _lastRound = _games[_playerLastGame[msg.sender]]._rounds[_games[_playerLastGame[msg.sender]]._rounds.length - 1];

        _lastRound._playerAttackType = playerAttackType;
        _lastRound._playerDefenceType = playerDefenceType;

        _lastRound._botAttackType = randomAction();
        _lastRound._botDefenceType = randomAction();

        if(_lastRound._playerAttackType != _lastRound._botDefenceType){
            _lastRound._playerHitHP = calculatePlayerHit();
            _games[_playerLastGame[msg.sender]]._botHP = _games[_playerLastGame[msg.sender]]._botHP - _lastRound._playerHitHP;
        }

        if(_games[_playerLastGame[msg.sender]]._botHP <= 0){
            _games[_playerLastGame[msg.sender]]._gameStatus = STATUS.CLOSED;

        }else{
            if(_lastRound._botAttackType != _lastRound._playerDefenceType){
                _lastRound._botHitHP = _calculatedBotAttack();
                _games[_playerLastGame[msg.sender]]._playerHP = _games[_playerLastGame[msg.sender]]._playerHP - _lastRound._botHitHP;
            }
        }

        if(_games[_playerLastGame[msg.sender]]._playerHP <= 0){
            _games[_playerLastGame[msg.sender]]._gameStatus = STATUS.CLOSED;
        }

        _games[_playerLastGame[msg.sender]]._rounds[_games[_playerLastGame[msg.sender]]._rounds.length - 1] = _lastRound;

        _games[_playerLastGame[msg.sender]]._rounds.push(Round(STATUS.STARTED, block.timestamp + _durationRoundTime, 0, 0, 0, 0, 0));
        return true;
    }

    function randomAction() private returns (ACTION) {
        uint randomNumber = uint(keccak256(abi.encodePacked(now, msg.sender, _nonceAttack))) % 3;
        _nonceAttack++;
        return ACTION(randomNumber);
    }

    function calculatePlayerHit() private returns (uint256) {
        uint256 _calculatedPlayerAttack;
        CharacterSkin _calculation = _games[_playerLastGame[msg.sender]]._characterData;
        uint256 _botDefence = _calculation._playerDefence;
        _calculatedPlayerAttack = _baseAttack + (_calculation._playerAttack - _botDefence);
        return _calculatedPlayerAttack;
    }

    function calculateBotHit() private returns (uint256) {
        uint256 _calculatedBotAttack;
        CharacterSkin _calculation = _games[_playerLastGame[msg.sender]]._characterData;
        uint256 _botAttack = _calculation._playerAttack;
        _calculatedBotAttack = _baseAttack + (_botAttack - _calculation._playerDefence);
        return _calculatedBotAttack;
    }
}
