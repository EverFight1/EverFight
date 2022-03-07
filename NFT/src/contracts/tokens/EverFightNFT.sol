// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./nf-token-metadata.sol";
import "../ownership/ownable.sol";

/**
 * @dev This is an example contract implementation of NFToken with metadata extension.
 */
contract EverFightNFT is NFTokenMetadata, Ownable {

  enum TIER{ FIRST, SECOND, THIRD}
  enum KIND{ SKIN, CARD}
  enum CARDTYPE{ ATTACK, DEFENCE}

  struct Properties {
    uint256 attack;
    uint256 defence;
    uint256 vitality;
    TIER tier;
  }

  struct Item {
    KIND kind;
    CARDTYPE cardType;
    string name;
    string description;
    string image;
    Properties properties;
  }

  mapping (uint256 => Item) public _items;
  mapping (address => uint256[]) public _playerItems;// 5, [1,2,3,4,7]

  /**
  * @dev Contract constructor. Sets metadata extension `name` and `symbol`.
  */
  constructor() {
    nftName = "CryptoWars";
    nftSymbol = "CW";
  }

  /**
  * @dev Mints a new NFT.
  * @param _to The address that will own the minted NFT.
  * @param _tokenId of the NFT to be minted by the msg.sender.
  * @param _uri String representing RFC 3986 URI.
  */
  function mint(
    address _to,
    uint256 _tokenId,
    string calldata _uri,
    KIND _kind,
    string _name,
    string _description,
    string _image,
    uint256 _attack,
    uint256 _defence,
    uint256 _vitality,
    TIER _tier
  ) external onlyOwner {
    super._mint(_to, _tokenId);
    super._setTokenUri(_tokenId, _uri);
    _items[_tokenId] = Item(_kind, _name, _description, _image, Properties(_attack, _defence, _vitality, _tier));
  }
}