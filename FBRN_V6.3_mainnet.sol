// SPDX-License-Identifier: MIT

pragma solidity ^0.7.1;

interface IBEP20 {
    function totalSupply() external view returns (uint256);
    function decimals() external view returns (uint8);
    function symbol() external view returns (string memory);
    function name() external view returns (string memory);
    function getOwner() external view returns (address);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address _owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;
        return c;
    }
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }
    function div( uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold
        return c;
    }
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

interface IPinkAntiBot {
    function setTokenOwner(address owner) external;
    function onPreTransferCheck(address from, address to, uint256 amount) external;
}

contract Context {
    function _msgSender() internal view returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

contract Ownable is Context {
    address private _owner;
    IPinkAntiBot public pinkAntiBot;

    address constant DEAD = 0x000000000000000000000000000000000000dEaD;
    address constant ZERO = 0x0000000000000000000000000000000000000000;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    event OwnershipRenounced(address indexed previousOwner);

    constructor() {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(ZERO, msgSender);
        pinkAntiBot = IPinkAntiBot(0x8EFDb3b642eb2a20607ffe0A56CFefF6a95Df002);
        
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public onlyOwner {
        emit OwnershipRenounced(_owner);
        emit OwnershipTransferred(_owner, ZERO);
        _owner = ZERO;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal {
        require(
            newOwner != ZERO,
            "Ownable: new owner is the zero address"
        );
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
        pinkAntiBot.setTokenOwner(_owner);
    }
}

contract FBRN is Context, IBEP20, Ownable {
    using SafeMath for uint256;

    modifier validRecipient(address to) {
        require(to != DEAD);
        require(to != ZERO);
        _;
    }

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;
    uint8 private _decimals;
    string private _symbol;
    string private _name;

    uint256 public totalBurned = 0;
    uint256 public tax = 15;
    uint256 public feeDenominator = 100;


    mapping(address => bool) internal taxExepmt;
    mapping(address => bool) internal blacklist;

    constructor() {
        _name = "Final Burn";
        _symbol = "FBRN";
        _decimals = 18;
        _totalSupply = 1_000_000_000_000 * (10**_decimals);
        _balances[owner()] = _totalSupply;

        taxExepmt[owner()] = true;
        taxExepmt[address(this)] = true;
        taxExepmt[0x56c54092cE7294EC81b84De221B08063FdF51b05] = true; // FBRN Marketing wallet
        taxExepmt[0xE74A502705737F9DaFACd53e5f69bC7A5ECa277C] = true; // FBRN Team wallet
        taxExepmt[0x1D2f48Fb697f0f798a7828Ccb4c99b3752595B57] = true; // Reserves wallet
        taxExepmt[0xE74A502705737F9DaFACd53e5f69bC7A5ECa277C] = true; // Manual Burn wallet

        _transferOwnership(owner());

        emit Transfer(ZERO, owner(), _totalSupply);
    }

    function getOwner()
        external view override returns (address) {
        return owner();
    }

    function decimals()
        external view override returns (uint8) {
        return _decimals;
    }

    function symbol()
        external view override returns (string memory) {
        return _symbol;
    }

    function name()
        external view override returns (string memory) {
        return _name;
    }

    function totalSupply()
        external view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account)
        external view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount)
        external override returns (bool)
    {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender)
        external view override returns (uint256)
    {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount)
        external override validRecipient(spender) returns (bool)
    {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount)
        external override validRecipient(sender) returns (bool)
    {
        _transfer(sender, recipient, amount);
        _approve(
            sender,
            _msgSender(),
            _allowances[sender][_msgSender()].sub(
                amount,
                "BEP20: transfer amount exceeds allowance"
            )
        );
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue)
        public validRecipient(spender) returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender].add(addedValue)
        );
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue)
        public validRecipient(spender) returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender].sub(
                subtractedValue,
                "BEP20: decreased allowance below zero"
            )
        );
        return true;
    }

    function _transfer(address sender, address recipient, uint256 amount)
        internal validRecipient(sender) validRecipient(recipient)
    {
        require(amount > 0, 'Amount must be greater than 0');
        require(!blacklist[sender], "Sender Blacklisted");
        require(!blacklist[recipient], "Recipient Blacklisted");
        require(_balances[sender] >= amount, "Sender has insufficient balance");

        pinkAntiBot.onPreTransferCheck(sender, recipient, amount);

        bool shouldTax = shouldTakeTax(sender, recipient);

        uint256 netAmount = amount;
        
        if (shouldTax) {
            netAmount = netAmount.sub(calcTaxAndBurn(sender, amount), 'Burn amount exceeds amount to send');
        }

        _balances[sender] = _balances[sender].sub(
            netAmount,
            "BEP20: transfer amount exceeds balance"
        );
        _balances[recipient] = _balances[recipient].add(netAmount);
        emit Transfer(sender, recipient, netAmount);
    }

    function calcTaxAndBurn(address sender, uint256 amount)
        internal returns (uint256)
    {
        uint256 taxAmount = amount.mul(tax).div(feeDenominator);
        uint256 netAmount = amount - taxAmount;

        // Burn the tax
        totalBurned = totalBurned.add(taxAmount);
        _burn(sender, taxAmount);

        return netAmount;
    }

    function shouldTakeTax(address from, address to)
        internal view returns (bool)
    {
        return !taxExepmt[from] && !taxExepmt[to];
    }

    function _burn(address sender, uint256 amount)
        internal validRecipient(sender)
    {
        _balances[sender] = _balances[sender].sub(
            amount,
            "BEP20: burn amount exceeds balance"
        );
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(sender, DEAD, amount);
    }

    function _approve(address owner, address spender, uint256 amount)
        internal validRecipient(owner) validRecipient(spender)
    {
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function setTax(uint256 _tax) external onlyOwner returns (uint256) {
        require(_tax > 0, 'Tax must be greater than 0');
        tax = _tax;

        return tax;
    }

    function setTaxExepmt(address _addres, bool _flag)
        external onlyOwner returns (address)
    {
        taxExepmt[_addres] = _flag;

        return _addres;
    }

    function getTaxExepmt(address _addres)
        external view onlyOwner returns (bool)
    {
        return taxExepmt[_addres];
    }

    function setBlacklist(address _addres, bool _flag)
        external onlyOwner returns (address)
    {
        blacklist[_addres] = _flag;

        return _addres;
    }
}