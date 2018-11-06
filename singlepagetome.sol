pragma solidity ^0.4.24;

contract SingleTome {

    /*** WORK IN PROGRESS ***/
    // @dev I really should be abstracting this into a few files and then importing, but I was trying
    // to get this ready for an event, had some trouble deploying multiple contracts, and didn't think it 
    // was worth the effort to figure out deployments on a short timeframe. Future versions will be handled
    // more elegantly.

    /*** DATA STUFFS ***/
    struct Spellbook {
        string name;
        address ownerAddress;
        uint32 powers;
        bytes32 unlockHash;
        bool claimed;
    }
    address public domainMasterAddress;
    address public questMasterAddress;
    address public newContractAddress;

    constructor () public {
        // This is an empty constructor.
    }

    /*** EVENTS ***/
    event NewSpellbook(uint indexed SpellbookId, string name, address owner, uint32 indexed powers, bytes32 unlockHash, bool claimed);
    event Approval(address owner, address indexed approved, uint256 indexed tokenId);
    event Transfer(address from, address indexed to, uint256 indexed tokenId);
    event ContractUpgrade(address indexed newContract);

    /*** STORAGE ***/
    Spellbook[] spellbooks;

    mapping (uint256 => address) public spellbookIndexToOwner;
    mapping (uint256 => address) public spellbookIndexToApproved;
    mapping (uint32 => uint) public powersToId;
    mapping (address => uint256) ownershipTokenCount;

    /// @dev Hermit's Tome is currently in Alpha. Expect upgrades; currently following CK pattern for upgrade.
    /// @param _v2Address new address
    function setNewAddress(address _v2Address) external onlyDomainMaster {
        newContractAddress = _v2Address;
        emit ContractUpgrade(_v2Address);
    }

    /// @notice Returns all the relevant information about a specific kitty.
    /// @param _id The ID of the spellbook of interest.
    function getSpellbook(uint256 _id)
        external
        view
        returns (
        string name,
        bytes32 unlockHash,
        uint32 powers,
        bool claimed
    ) {
        Spellbook memory sb = spellbooks[_id];
        return(sb.name, sb.unlockHash, sb.powers, sb.claimed);
    }

    // @dev takes spellWords from the Domain Master and creates a new Spellbook with unique unlock hash
    // This allows anyone who uncovers the Secret Spell Words (by playing the game in the real and not real worlds) 
    // to enchant the Spellbook exclusively to themself!
    function createSpellbook(string name, uint32 powers, string spellWords) external onlyDomainMaster returns (uint) {
        bytes32 unlockHash = _generateUnlockHash(spellWords);
        address createAddress = address(this);

        Spellbook memory _spellbook = Spellbook({
            name: name,
            ownerAddress: createAddress,
            powers: powers,
            unlockHash: unlockHash,
            claimed: false
        });

        uint256 newSpellbookId = spellbooks.push(_spellbook) - 1;
        powersToId[powers] = newSpellbookId;
        emit NewSpellbook(newSpellbookId, name, address(this), powers, unlockHash, false);
        spellbookIndexToOwner[newSpellbookId] = createAddress;
        return newSpellbookId;
    }
    
    function _generateUnlockHash(string _spellWords) internal pure returns (bytes32) {
        bytes32 unlockHash = keccak256(abi.encodePacked(_spellWords));
        return unlockHash;
    }

    function enchantToOwner(string _spellWords, uint32 powers) public {
        require(msg.sender != 0, "");
        uint _spellbookId = getIdByPowers(powers);
        require(spellbooks[_spellbookId].claimed == false, "Thou shalt not steal");
        require(spellbooks[_spellbookId].unlockHash == keccak256(abi.encodePacked(_spellWords)), "Speak friend and enter");
        claimApprove(msg.sender, _spellbookId);
        transfer(msg.sender, _spellbookId);
        spellbooks[_spellbookId].claimed = true;
        spellbooks[_spellbookId].ownerAddress = msg.sender;
        ownershipTokenCount[msg.sender]++;
    }    

    function getIdByPowers(uint32 powers) internal view returns (uint) {
        return powersToId[powers];
    }    

    function() external payable {
        require(
            msg.sender == questMasterAddress ||
            msg.sender == domainMasterAddress,
            "no tipping! thx"
        );
    }

    modifier onlyDomainMaster() {
        require(msg.sender == domainMasterAddress, "only the lord of this realm may take such an action!");
        _;
    }

    function setDM(address _newDM) external onlyDomainMaster {
        require(_newDM != address(0), "what evil is this?!");
        domainMasterAddress = _newDM;
    }

    function setQM(address _newQM) external onlyDomainMaster {
        require(_newQM != address(0), "mischief has no place here");
        questMasterAddress = _newQM;
    }

    string public constant name = "Hermit's Tome";
    string public constant symbol = "HT";

    bytes4 constant InterfaceSignature_ERC165 = bytes4(keccak256("supportsInterface(bytes4)"));

    bytes4 constant InterfaceSignature_ERC721 =
        bytes4(keccak256("name()")) ^
        bytes4(keccak256("symbol()")) ^
        bytes4(keccak256("totalSupply()")) ^
        bytes4(keccak256("balanceOf(address)")) ^
        bytes4(keccak256("ownerOf(uint256)")) ^
        bytes4(keccak256("approve(address,uint256)")) ^
        bytes4(keccak256("transfer(address,uint256)")) ^
        bytes4(keccak256("transferFrom(address,address,uint256)")) ^
        bytes4(keccak256("tokensOfOwner(address)")) ^
        bytes4(keccak256("tokenMetadata(uint256,string)"));

    function supportsInterface(bytes4 _interfaceID) 
        external  
        pure
        returns 
        (bool)
    {
        return ((_interfaceID == InterfaceSignature_ERC165) || (_interfaceID == InterfaceSignature_ERC721));
    }

    function _owns(address _claimant, uint256 _tokenId) internal view returns (bool) {
        return spellbookIndexToOwner[_tokenId] == _claimant;
    }

    function _approvedFor(address _claimant, uint256 _tokenId) internal view returns (bool) {
        return spellbookIndexToApproved[_tokenId] == _claimant;
    }

    function _approve(uint256 _tokenId, address _approved) internal {
        spellbookIndexToApproved[_tokenId] = _approved;
    }

    function balanceOf(address _owner) public view returns (uint256 count) {
        return ownershipTokenCount[_owner];
    }

    function transfer(
        address _to,
        uint256 _tokenId
    )
        public
    {
        // Safety check to prevent against an unexpected 0x0 default.
        require(_to != address(0), "magic may not be destroyed!");
        require(_to != address(this), "we must not allow any magical paradoxes!");
        ownershipTokenCount[msg.sender]--;
        ownershipTokenCount[_to]++;
        spellbooks[_tokenId].ownerAddress = _to;
        spellbookIndexToApproved[_tokenId] = address(0);
        spellbookIndexToOwner[_tokenId] = msg.sender;
        emit Transfer(msg.sender, _to, _tokenId);
    }

    function approve(
        address _to,
        uint256 _tokenId
    )
        external
    {
        // Only an owner can grant transfer approval.
        require(_owns(msg.sender, _tokenId), "Thou shalt not steal!");

        // Register the approval (replacing any previous approval).
        spellbookIndexToApproved[_tokenId] = _to;
        // Emit approval event.
        emit Approval(msg.sender, _to, _tokenId);
    }

    // @public Initial claim on a token occurs when a mecanist discovers the Spell Words. 
    // This internal function will fire and approve the initial claim for any message sender 
    // with a valid Spell Words hash automatically. 
    function claimApprove(
        address _to,
        uint256 _tokenId
    )
        internal
    {
        // require the token be unclaimed
        require(spellbooks[_tokenId].claimed == false, "Thou shalt not steal!");
        spellbookIndexToApproved[_tokenId] = _to;
        emit Approval(address(this), _to, _tokenId);
    }
    
    function transferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    )
        external
    {
        require(_to != address(0), "magic may not be destroyed!");
        require(_to != address(this), "we must not allow any magical paradoxes!");
        require(_approvedFor(msg.sender, _tokenId), "thou shalt not covet!");
        require(_owns(_from, _tokenId), "thou shalt not steal!");
        spellbooks[_tokenId].ownerAddress = _to;
        spellbookIndexToOwner[_tokenId] = _to;
        spellbookIndexToApproved[_tokenId] = address(0);
        ownershipTokenCount[_from]--;
        ownershipTokenCount[_to]++;
        emit Transfer(_from, _to, _tokenId);
    }

    function totalSupply() public view returns (uint) {
        return spellbooks.length - 1;
    }

    function ownerOf(uint256 _tokenId)
        external
        view
        returns (address owner)
    {
        owner = spellbookIndexToOwner[_tokenId];

        require(owner != address(0), "can nothing own something? inconceivable!");
    }
    
    function tokensOfOwner(address _owner) external view returns(uint256[] ownerTokens) {
        uint256 tokenCount = balanceOf(_owner);

        if (tokenCount == 0) {
            // Return an empty array
            return new uint256[](0);
        } else {
            uint256[] memory result = new uint256[](tokenCount);
            uint256 totalSpellbooks = totalSupply();
            uint256 resultIndex = 0;

            uint256 _spellbookId;

            for (_spellbookId = 0; _spellbookId <= totalSpellbooks; _spellbookId++) {
                if (spellbookIndexToOwner[_spellbookId] == _owner) {
                    uint32 powers = spellbooks[_spellbookId].powers;
                    result[resultIndex] = powers;
                    resultIndex++;
                }
            }

            return result;
        }
    }
}