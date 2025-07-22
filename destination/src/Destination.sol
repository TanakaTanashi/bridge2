// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./BridgeToken.sol";

contract Destination is AccessControl {
    bytes32 public constant WARDEN_ROLE = keccak256("BRIDGE_WARDEN_ROLE");
    bytes32 public constant CREATOR_ROLE = keccak256("CREATOR_ROLE");
    mapping(address => address) public wrapped_tokens;
    mapping(address => address) public underlying_tokens;
    address[] public tokens;

	event Creation( address indexed underlying_token, address indexed wrapped_token );
	event Wrap( address indexed underlying_token, address indexed wrapped_token, address indexed to, uint256 amount );
	event Unwrap( address indexed underlying_token, address indexed wrapped_token, address frm, address indexed to, uint256 amount );

    constructor( address admin ) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(CREATOR_ROLE, admin);
        _grantRole(WARDEN_ROLE, admin);
    }

    // This function deploys a new BridgeToken controlled by this contract
    function createToken(
        address _underlying_token,
        string  memory name,
        string  memory symbol
    )
        public
        onlyRole(CREATOR_ROLE)
        returns (address)
    {
        require(_underlying_token != address(0), "Destination: underlying=0");
        require(underlying_tokens[_underlying_token] == address(0),
                "Destination: already registered");

        // Deploy wrapped token
        BridgeToken wtoken = new BridgeToken(
            _underlying_token,
            name,
            symbol,
            address(this)
        );

        address wAddr = address(wtoken);
        wrapped_tokens[_underlying] = wAddr;
        underlying_tokens[wAddr]    = _underlying;
        tokens.push(_underlying);

        emit Creation(_underlying_token, wAddr);
        return wAddr;
    }

    // Mint wrapped tokens after a deposit is observed on the source chain
    function wrap(
        address _underlying_token,
        address _recipient,
        uint256 _amount
    )
        public
        onlyRole(WARDEN_ROLE)
    {
        address wAddr = wrapped_tokens[_underlying];
        require(wAddr != address(0), "Destination: token not registered");
        require(_recipient != address(0), "Destination: recipient=0");
        require(_amount > 0,              "Destination: amount=0");

        BridgeToken(wAddr).mint(_recipient, _amount);
        emit Wrap(_underlying_token, wAddr, _recipient, _amount);
    }

    // Burn wrapped tokens so the underlying token can be released on the source chain
    function unwrap(
        address _wrapped_token,
        address _recipient,
        uint256 _amount
    )
        public
    {
        address underlying = underlying_tokens[_wrapped];
        require(underlying != address(0), "Destination: unknown wrapped");
        require(_amount > 0,              "Destination: amount=0");

        // Destination contract holds MINTER_ROLE in every BridgeToken it creates
        BridgeToken(_wrapped_token).burnFrom(msg.sender, _amount);

        emit Unwrap(underlying, _wrapped_token, msg.sender, _recipient, _amount);
    }
}