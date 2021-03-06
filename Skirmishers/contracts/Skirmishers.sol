// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

//Contract imports
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

//Library imports
import "./libraries/Base64.sol";

//Helper function imports
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "hardhat/console.sol";

contract Skirmishers is ERC721 {
    struct SkirmisherAttributes{
        uint256 skirmisherType;
        string name;
        string imageURI;
        uint256 hp;
        uint256 maxHp;
        uint256 damage;
    }

    struct EnemyVariant {
        string name;
        string imageURI;
        uint256 hp;
        uint256 maxHp;
        uint256 damage;
    }

    //Instantiate counter for Skirmisher IDs
    using Counters for Counters.Counter;
    Counters.Counter private _tokenID;

    SkirmisherAttributes[] skirmisherTypes;
    EnemyVariant public boss;

    //Mapping to reference the attributes of an nft, given its ID
    mapping(uint256 => SkirmisherAttributes) public ID2Attributes;
    //Mapping to reference the nfts of a given holder
    mapping(address => uint256) public owner2Skirmisher;

    //Events to ensure our front end is aware of functions running to completion
    event SkirmisherNFTMinted(address sender, uint256 newSkirmisherID, uint256 SkirmisherType);
    event AttackCompleted(uint256 newPlayerHp, uint256 newEnemyHp);

    constructor(
        string[] memory _skirmisherNames,
        string[] memory _skirmisherImageURIs,
        uint[] memory _skirmisherHp,
        uint[] memory _skirmisherDmg,
        string memory _bossName,
        string memory  _bossImageURI,
        uint256 _bossHp,
        uint256 _bossDamage
    )
        ERC721("Skirmishers", "MISH")
    {
        //Initialise the boss
        boss = EnemyVariant({
            name: _bossName,
            imageURI: _bossImageURI,
            hp: _bossHp,
            maxHp: _bossHp,
            damage: _bossDamage
        });

        console.log("Created boss %s, with %s HP, the image is %s",boss.name, boss.hp, boss.imageURI);

        for(uint256 i = 0; i < _skirmisherNames.length; i++){
            skirmisherTypes.push(
                SkirmisherAttributes({
                    skirmisherType: i,
                    name: _skirmisherNames[i],
                    imageURI: _skirmisherImageURIs[i],
                    hp: _skirmisherHp[i],
                    maxHp: _skirmisherHp[i],
                    damage: _skirmisherDmg[i]
                })
            );

            SkirmisherAttributes memory skirmisher = skirmisherTypes[i];
            console.log(
                "Created skirmisher %s with health %s HP and img %s", 
                skirmisher.name, 
                skirmisher.hp, 
                skirmisher.imageURI
            );
        }

        //Incremented on instantiation to ensure that the first NFT has ID 1 not 0
        _tokenID.increment();
    }

    function checkPresenceNFT() public view returns(SkirmisherAttributes memory){
        uint256 playerSkirmisherID = owner2Skirmisher[msg.sender];
        
        if(playerSkirmisherID > 0){
            return ID2Attributes[playerSkirmisherID];
        }else{
            SkirmisherAttributes memory emptySkirmisher;
            return emptySkirmisher;
        }
    }

    function getBaseSkirmishers() public view returns(SkirmisherAttributes[] memory){
        return skirmisherTypes;
    }

    function createSkirmisher(uint256 _skirmisherType) external {
        //Get currentID
        uint256 newSkirmisherID = _tokenID.current();

        //Mint NFT
        _safeMint(msg.sender, newSkirmisherID);

        //Map new NFT to its default attributes
        ID2Attributes[newSkirmisherID] = SkirmisherAttributes({
            skirmisherType: _skirmisherType,
            name: skirmisherTypes[_skirmisherType].name,
            imageURI: skirmisherTypes[_skirmisherType].imageURI,
            hp: skirmisherTypes[_skirmisherType].hp,
            maxHp: skirmisherTypes[_skirmisherType].maxHp,
            damage: skirmisherTypes[_skirmisherType].damage
        });

        console.log("Minted NFT w/ tokenID %s and characterType %s", newSkirmisherID, _skirmisherType);

        owner2Skirmisher[msg.sender] = newSkirmisherID;

        _tokenID.increment();

        emit SkirmisherNFTMinted(msg.sender, newSkirmisherID, _skirmisherType);
    }

    function getBoss() public view returns(EnemyVariant memory){
        return boss;
    }

    function attackBoss() public {
        require(boss.hp > 0, "The boss has already been defeated");

        uint256 playerSkirmisherID = owner2Skirmisher[msg.sender];
        SkirmisherAttributes storage playerSkirmisher = ID2Attributes[playerSkirmisherID];

        require(playerSkirmisher.hp > 0, "Your skirmisher has been defeated :(");

        //Deal some damage
        if(boss.hp < playerSkirmisher.damage){
            boss.hp = 0;
        }else{
            boss.hp = boss.hp - playerSkirmisher.damage;
        }

        //Talk shit get hit
        if(playerSkirmisher.hp < boss.damage){
            playerSkirmisher.hp = 0;
        }else{
            playerSkirmisher.hp = playerSkirmisher.hp - boss.damage;
        }

        console.log(
            "\nPlayer w/ character: %s attacked! Current HP is now %s and dmg dealt was %s",
            playerSkirmisher.name,
            playerSkirmisher.hp,
            playerSkirmisher.damage
        );
        console.log(
            "Boss %s was attacked and now has %s HP and dealt %s damage",
            boss.name,
            boss.hp,
            boss.damage
        );

        emit AttackCompleted(playerSkirmisher.hp, boss.hp);
    }

    function tokenURI(uint256 _tokenId) public view override returns (string memory) {
        SkirmisherAttributes memory attributes = ID2Attributes[_tokenId];

        string memory strHp = Strings.toString(attributes.hp);
        string memory strMaxHp = Strings.toString(attributes.maxHp);
        string memory strAttackDamage = Strings.toString(attributes.damage);

        string memory json = Base64.encode(
            abi.encodePacked(
            '{"name": "',
            attributes.name,
            ' -- NFT #: ',
            Strings.toString(_tokenId),
            '", "description": "This is the first generation of skirmishers", "image": "',
            attributes.imageURI,
            '", "attributes": [ { "trait_type": "Health Points", "value": ',strHp,', "max_value":',strMaxHp,'}, { "trait_type": "Attack Damage", "value": ',
            strAttackDamage,'} ]}'
            )
        );

        string memory output = string(
            abi.encodePacked("data:application/json;base64,", json)
        );
        
        return output;
    }
}