// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;


import "./ERC721A.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol"; 

contract NFTContract is Ownable, ERC721A {
    uint256 public MAX_SUPPLY = 6666;
    uint256 public mintRate = 0.01 ether;
    uint256 public MAX_MINTS = 10;
    uint256 public maxMintperTx = 5;
    string public hiddenMetadataUri;
    bool public paused = true;
    bool public revealed = false;
    
    address proxyRegistryAddress;
    string public baseURI = "";
    string public baseExtension = ".json";

    constructor(string memory _initBaseURI) ERC721A("Voyage Cats", "VC") {
        setHiddenMetadataUri("https://degenheroes.mypinata.cloud/ipfs/QmdTpg1KFzzFU7sbtmQifUKxL486Hodvg9q5RnzixC6Epd/prereveal.json");
        setBaseURI(_initBaseURI);
    }

    function tokenURI(uint256 _tokenId)
    public
    view
    virtual
    override
    returns (string memory)

    {
    require(
      _exists(_tokenId),
      "ERC721Metadata: URI query for nonexistent token"
    );

    if (revealed == false) {
        return hiddenMetadataUri;
    }

    string memory currentBaseURI = _baseURI();
    return bytes(currentBaseURI).length > 0
        ? string(abi.encodePacked(currentBaseURI,Strings.toString(_tokenId) , baseExtension))
        : "";
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    function mint(uint256 _quantity) external payable {
        require(!paused, "Sale is not active!");
        if (totalSupply() < 666) {
            require(_quantity <= maxMintperTx, "Max tx limit exceeded!");
            require(_quantity + _numberMinted(msg.sender) <= MAX_MINTS, "Exceeded the limit");
          _safeMint(msg.sender, _quantity);
        } else {
          if (msg.sender != owner()) {
            require(_quantity <= maxMintperTx, "Max tx limit exceeded!");
            require(_quantity + _numberMinted(msg.sender) <= MAX_MINTS, "Exceeded the limit");
            require(msg.value >= (mintRate * _quantity), "Not enough ether sent");
          }
          require(totalSupply() + _quantity <= MAX_SUPPLY, "Not enough tokens left");
          _safeMint(msg.sender, _quantity);
        }
    }

    function setPaused(bool _state) external onlyOwner {
        paused = _state;
    }

    function setHiddenMetadataUri(string memory _hiddenMetadataUri) public onlyOwner {
        hiddenMetadataUri = _hiddenMetadataUri;
    }

    function setRevealed(bool _state) public onlyOwner {
        revealed = _state;
    }

    function setMax(uint256 _quantity) external onlyOwner {
        MAX_MINTS = _quantity;
    }

    function setMaxMintTx(uint256 _quantity) external onlyOwner {
        maxMintperTx = _quantity;
    }
 
    function mintForAddresses(uint256 _quantity, address _address) public onlyOwner {
        _safeMint(_address, _quantity);
    }

    function withdrawAll() external onlyOwner {
        require(address(this).balance > 0, "ZERO");
        payable(msg.sender).transfer(address(this).balance);
    }


    function setBaseURI(string memory _newBaseURI) public onlyOwner {
        baseURI = _newBaseURI;
    }

    function setBaseExtension(string memory _newBaseExtension) public onlyOwner {
        baseExtension = _newBaseExtension;
    }
}