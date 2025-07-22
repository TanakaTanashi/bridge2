// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./BridgeToken.sol";

contract Destination is AccessControl {
    /* roles */
    bytes32 public constant WARDEN_ROLE  = keccak256("BRIDGE_WARDEN_ROLE");
    bytes32 public constant CREATOR_ROLE = keccak256("CREATOR_ROLE");

    mapping(address => address) public wrapped_tokens;
    mapping(address => address) public underlying_tokens;
    address[] public tokens;

    /* events */
    event Creation(address indexed underlying_token, address indexed wrapped_token);
    event Wrap    (address indexed underlying_token,
                   address indexed wrapped_token,
                   address indexed to,
                   uint256          amount);
    event Unwrap  (address indexed underlying_token,
                   address indexed wrapped_token,
                   address          frm,
                   address indexed to,
                   uint256          amount);

    /* constructor */
    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(CREATOR_ROLE,        admin);
        _grantRole(WARDEN_ROLE,         admin);
    }

    function createToken(
        address _underlying,
        string  memory name,
        string  memory symbol
    )
        public
        onlyRole(CREATOR_ROLE)
        returns (address)
    {
        require(_underlying != address(0),          "Destination: underlying=0");
        require(wrapped_tokens[_underlying] == address(0),
                "Destination: already registered");

        BridgeToken wtoken = new BridgeToken(
            _underlying,
            name,
            symbol,
            address(this)          // Destination is admin/minter
        );

        address wAddr = address(wtoken);
        wrapped_tokens[_underlying] = wAddr;
        underlying_tokens[wAddr]    = _underlying;
        tokens.push(_underlying);

        emit Creation(_underlying, wAddr);
        return wAddr;
    }

    function wrap(
        address _underlying,
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
        emit Wrap(_underlying, wAddr, _recipient, _amount);
    }

    function unwrap(
        address _wrapped,
        address _recipient,
        uint256 _amount
    )
        public
    {
        address underlying = underlying_tokens[_wrapped];
        require(underlying != address(0), "Destination: unknown wrapped");
        require(_amount > 0,              "Destination: amount=0");

        BridgeToken(_wrapped).burnFrom(msg.sender, _amount);  // Destination (minter) calls burn
        emit Unwrap(underlying, _wrapped, msg.sender, _recipient, _amount);
    }
}
