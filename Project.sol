// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;


import "./ERC721A.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol"; 
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract NFT_Contract is ERC721A, Ownable {
    using Strings for uint256;
    mapping(address => uint256) public whitelistClaimed;
    mapping(address => uint256) public publicClaimed;

    string public baseURI;
    string public baseExtension = ".json";
    uint256 public whitelistCost = 0.07 ether;
    uint256 public publicCost = 0.088 ether;
    bool public whitelistEnabled = false;
    bool public paused = false;
    bytes32 public merkleRoot;
    uint256 public maxWhitelist = 5;
    uint256 public maxPublic = 5;
    uint256 public mintPerTx = 5;
    uint256 public maxSupply = 10000;

    uint96 public royaltyFeesInBips;
    address public royaltyAddress;
    string public contractURI;

    constructor(
        string memory _initBaseURI,
        uint96 _royaltyFeesInBips
    ) ERC721A("", "") {
        royaltyFeesInBips = _royaltyFeesInBips;
        royaltyAddress = owner();
        setBaseURI(_initBaseURI);
    }

    function whitelistMint(uint256 quantity, bytes32[] calldata _merkleProof)
        public
        payable
    {
        uint256 supply = totalSupply();
        require(quantity > 0, "Quantity Must Be Higher Than Zero");
        require(supply + quantity <= maxSupply, "Max Supply Reached");
        require(whitelistEnabled, "The whitelist sale is not enabled!");
        require(
            whitelistClaimed[msg.sender] + quantity <= maxWhitelist,
            "You're not allowed to mint this Much!"
        );
        require(msg.value >= whitelistCost * quantity, "Insufficient Funds");
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        require(
            MerkleProof.verify(_merkleProof, merkleRoot, leaf),
            "Invalid proof!"
        );

        whitelistClaimed[msg.sender] += quantity;
        _safeMint(msg.sender, quantity);
    }

    function mint(uint256 quantity) external payable {
        uint256 supply = totalSupply();
        require(!paused, "The contract is paused!");
        require(!whitelistEnabled, "Public mint is disable!");
        require(quantity > 0, "Quantity Must Be Higher Than Zero!");
        require(supply + quantity <= maxSupply, "Max Supply Reached!");

        if (msg.sender != owner()) {
            require(
            publicClaimed[msg.sender] + quantity <= maxPublic,
                "You're not allowed to mint this Much!"
            );
            require(
                quantity <= maxPublic,
                "You're Not Allowed To Mint more than maxMint Amount"
            );
            require(msg.value >= publicCost * quantity, "Insufficient Funds");
        }
        publicClaimed[msg.sender] += quantity;
        _safeMint(msg.sender, quantity);
    }

    // internal
    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        string memory currentBaseURI = _baseURI();
        return
            bytes(currentBaseURI).length > 0
                ? string(
                    abi.encodePacked(
                        currentBaseURI,
                        tokenId.toString(),
                        baseExtension
                    )
                )
                : "";
    }

    function setCost(uint256 _whitelistCost, uint256 _publicCost)
        public
        onlyOwner
    {
        whitelistCost = _whitelistCost;
        publicCost = _publicCost;
    }

    function setMax(uint256 _whitelist, uint256 _public) public onlyOwner {
        maxWhitelist = _whitelist;
        maxPublic = _public;
    }

    function setMintPerTx(uint256 quantity) public onlyOwner {
        mintPerTx = quantity;
    }

    function setMaxSuppy(uint256 _amount) public onlyOwner {
        maxSupply = _amount;
    }

    function setMerkleRoot(bytes32 _merkleRoot) public onlyOwner {
        merkleRoot = _merkleRoot;
    }

    function setWhitelistEnabled(bool _state) public onlyOwner {
        whitelistEnabled = _state;
    }

    function setPaused(bool _state) public onlyOwner {
        paused = _state;
    }

    function setBaseURI(string memory _newBaseURI) public onlyOwner {
        baseURI = _newBaseURI;
    }

    function mintForAddresses(uint256 quantity, address _address) public onlyOwner {
        require(!paused, "The contract is paused!");
        _safeMint(_address, quantity);
    }

    function setBaseExtension(string memory _newBaseExtension)
        public
        onlyOwner
    {
        baseExtension = _newBaseExtension;
    }

    function setRoyaltyReciever(address _address) public onlyOwner {
        royaltyAddress = _address;
    }

    function royaltyInfo(uint256 _tokenId, uint256 _salePrice)
        external
        view
        returns (address, uint256)
    {
        _tokenId; // silence solc warning
        return (royaltyAddress, calculateRoyalty(_salePrice));
    }

    function calculateRoyalty(uint256 _salePrice) view public returns (uint256) {
        return (_salePrice / 10000) * royaltyFeesInBips;
    }

    function supportsInterface(bytes4 interfaceId)
            public
            view
            override(ERC721A)
            returns (bool)
    {
        return interfaceId == 0x2a55205a || super.supportsInterface(interfaceId);
    }

    function withdraw() public onlyOwner {
        (bool ts, ) = payable(owner()).call{value: address(this).balance}("");
        require(ts);
    }
}
