// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

abstract contract ERC20 {

    string  public name;
    string  public symbol;
    string  public constant version = "1";
    uint256 public totalSupply;
    uint8   public constant decimals = 18;

    bytes32 public DOMAIN_SEPARATOR;
    bytes32 public constant PERMIT_TYPEHASH = keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    mapping(address => uint) public nonces;

    mapping (address => uint)                      public balanceOf;
    mapping (address => mapping (address => uint)) public allowance;

    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    constructor(string memory symbol_, string memory name_) {
        symbol = symbol_;
        name = name_;

        uint chainId;
        assembly {
            chainId := chainid()
        }
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'),
                keccak256(bytes(name)),
                keccak256(bytes(version)),
                chainId,
                address(this)
            )
        );
    }

    function transfer(address to, uint value) external returns (bool) {
        return transferFrom(msg.sender, to, value);
    }

    function transferFrom(address from, address to, uint value)
        public virtual returns (bool)
    {
        if (from != msg.sender) {
            allowance[from][msg.sender] -= value;
        }
        balanceOf[from] -= value;
        balanceOf[to] += value;
        emit Transfer(from, to, value);
        return true;
    }
    
    function approve(address usr, uint value) external returns (bool) {
        allowance[msg.sender][usr] = value;
        emit Approval(msg.sender, usr, value);
        return true;
    }

    // --- Approve by signature ---
    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external {
        require(deadline >= block.timestamp, 'cent/past-deadline');
        bytes32 digest = keccak256(
            abi.encodePacked(
                '\x19\x01',
                DOMAIN_SEPARATOR,
                keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonces[owner]++, deadline))
            )
        );
        address recoveredAddress = ecrecover(digest, v, r, s);
        require(recoveredAddress == owner, 'invalid-sig');
        allowance[owner][spender] = value;
        emit Approval(owner, spender, value);
    }
}