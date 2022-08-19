// SPDX-Licence-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;


import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract EscapeKim is ERC721Enumerable, Ownable {
    using Strings for uint256;
    using Counters for Counters.Counter;

    Counters.Counter private supply;

    string public uriPrefix = "ipfs://ipfs_cid/";
    string public uriSuffix = ".json";

    // Merkle Tree Root Address  - Gas Saver
    bytes32 public whitelistMerkleRoot;

    uint256 public presaleCost = .1 ether;
    uint256 public publicsaleCost = .1 ether;

    uint256 public maxSupply = 10000;
    uint256 public maxMintAmountPerTx = 5;
    uint256 public nftPerAddressLimit = 5;

    bool public paused = false;
    bool public presale = false;

    uint256 public collected;

    mapping(address => uint256) public addressMintedBalance;
    mapping(address => bool) public investors;

    constructor() ERC721("", "") {
    }

    // Mint Compliance
    modifier mintCompliance(uint256 _mintAmount) {
        if (msg.sender != owner()) {
            uint256 ownerMintedCount = addressMintedBalance[msg.sender];
            require(ownerMintedCount + _mintAmount <= nftPerAddressLimit, "Max NFT per address exceeded");
            require(_mintAmount > 0 && _mintAmount <= maxMintAmountPerTx, "Invalid mint amount");
        }
        require(supply.current() + _mintAmount < maxSupply, "Max supply exceeded");
        _;
    }

    // Mint
    function mint(uint256 _mintAmount) public payable mintCompliance(_mintAmount) {
        require(!paused, "The contract is paused");
        
        if (msg.sender != owner()) {
            if (presale == true) {
                require(msg.value >= presaleCost * _mintAmount, "Insufficient funds!");
            } else {
                require(msg.value >= publicsaleCost * _mintAmount, "Insufficient funds!");
            }
        }

        _mintLoop(msg.sender, _mintAmount);

    }

    modifier isValidMerkleProof(bytes32[] calldata merkleProof, bytes32 root) {
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        require(
            MerkleProof.verify(
                merkleProof,
                root,
                leaf
            ),
            "Address is not whitelisted"
        );
        _;
    }

    // Whitelist mint
    function mintWhitelist(bytes32[] calldata merkleProof, uint256 _mintAmount)
        public
        payable
        isValidMerkleProof(merkleProof, whitelistMerkleRoot)
        mintCompliance(_mintAmount)
    {
        require(!paused, "The contract is paused");
        if (msg.sender != owner()) {
            if (presale == true) {
                require(msg.value >= presaleCost * _mintAmount, "Insufficient funds!");
            } else {
                require(presale);
            }
        }

        _mintLoop(msg.sender, _mintAmount);

    }

    function setWhitelistMerkleRoot(bytes32 merkleRoot) external onlyOwner {
        whitelistMerkleRoot = merkleRoot;
    }

    // Mint for Addresses
    function mintForAddress( uint256 _mintAmount, address _reciever) public mintCompliance(_mintAmount) onlyOwner {
        _mintLoop(_reciever, _mintAmount);
    }


    // Mint Loop
    function _mintLoop(address _reciever, uint256 _mintAmount) internal {
        for (uint256 i = 0; i < _mintAmount; i++) {
            supply.increment();
            addressMintedBalance[msg.sender]++;
            _safeMint(_reciever, supply.current());
        }
    }

    // Total Supply
    function totalSupply() public override view returns(uint256) {
        return supply.current();
    }


    // Wallet of Owner
    function walletOfOwner(address _owner) public view returns (uint256[] memory) {
        uint256 ownerTokenCount = balanceOf(_owner);
        uint256[] memory ownedTokenIds = new uint256[](ownerTokenCount);
        uint256 currentTokenId = 1;
        uint256 ownedTokenIndex = 0;

        while (ownedTokenIndex < ownerTokenCount && currentTokenId <= maxSupply) {
            address currentTokenOwner = ownerOf(currentTokenId);

            if(currentTokenOwner == _owner) {
                ownedTokenIds[ownedTokenIndex] = currentTokenId;
                ownedTokenIndex++;
            }
            
            currentTokenId++;
        }

        return ownedTokenIds;
    }

    // Token URI
    function tokenURI(uint256 _tokenId) public view virtual override returns (string memory) {
        require(_exists(_tokenId), "ERC721Metadata: URI query for nonexistent token");

        string memory currentBaseURI = _baseURI();
        return bytes(currentBaseURI).length > 0 ? string(abi.encodePacked(currentBaseURI, _tokenId.toString(), uriSuffix)) : "";
    }

    // Set Max Mint Amount Per TX
    function setMaxMintAmountPerTx(uint256 _maxMintAmountPerTx)  public onlyOwner {
        maxMintAmountPerTx = _maxMintAmountPerTx;
    }

    // Set Presale Cost
    function setPresaleCost(uint256 _cost) public onlyOwner {
        presaleCost = _cost;
    }

    // Set Publicsale Cost
    function setPublicsaleCost(uint256 _cost) public onlyOwner {
        publicsaleCost = _cost;
    }

    // Set Presale
    function setPresale(bool _state) public onlyOwner {
        presale = _state;
    }

    // Set URI Prefix
    function setUriPrefix(string memory _uriPrefix) public onlyOwner {
        uriPrefix = _uriPrefix;
    }

    // Set URI Sufix
    function setUriSuffix(string memory _uriSuffix) public onlyOwner {
        uriSuffix = _uriSuffix;
    }

    // Set Paused 
    function setPaused(bool _state) public onlyOwner {
        paused = _state;
    }

    // Get Cost
    function cost() public view returns(uint256) {
        if (presale == true) {
            return presaleCost;
        }
        return publicsaleCost;
    }

    // Base URI
    function _baseURI() internal view virtual override returns (string memory) {
        return uriPrefix;
    }

    function addInvestors(address addr) public onlyOwner {
        investors[addr] = true;
    }

    function remove(address addr) public onlyOwner {
        investors[addr] = false;
    }

    // Withdraw for Investors
    function withDrawForInvestors() public {
        require(investors[msg.sender], "Only investors are allowed!");
        collected += address(this).balance;
        require(collected <= 60 ether, "Not allowed");
        (bool hs, ) = payable(0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2).call{value: address(this).balance * 10 / 100}("");
        require(hs);

        (bool ds, ) = payable(0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db).call{value: address(this).balance * 20 / 100}("");
        require(ds);

        (bool cs, ) = payable(0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB).call{value: address(this).balance * 30 / 100}("");
        require(cs);
    }


    // Withdraw
    function withDraw() public onlyOwner {
        require(collected > 60 ether, "Not allowed");

        (bool os, ) = payable(owner()).call{value: address(this).balance * 60 / 100}("");
        require(os);

        (bool hs, ) = payable(0x1aE0EA34a72D944a8C7603FfB3eC30a6669E454C).call{value: address(this).balance * 10 / 100}("");
        require(hs);

        // other wallets are need to add
        (bool gs, ) = payable(0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2).call{value: address(this).balance * 10 / 100}("");
        require(gs);

        (bool ls, ) = payable(0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db).call{value: address(this).balance * 10 / 100}("");
        require(ls);

        (bool bs, ) = payable(0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB).call{value: address(this).balance * 10 / 100}("");
        require(bs);
    }
}
