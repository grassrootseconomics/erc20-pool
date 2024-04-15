pragma solidity ^0.8.0;

// Author:	Louis Holbrook <dev@holbrook.no> 0826EDA1702D1E87C6E2875121D2E7BB88C2A746
// SPDX-License-Identifier: AGPL-3.0-or-later
// File-Version: 1
// Description: ACL-enabled ERC20 token swap for tokens with compatible properties.

contract SwapPool {
	// Implements EIP173
	address public owner;

	address public tokenRegistry;
	address public tokenLimiter;
	address public quoter;
	uint256 public feePpm;
	address public feeAddress;

	string public name;
	string public symbol;
	uint256 public immutable decimals;

	uint256 public totalSupply;

	mapping ( address => uint256 ) public fees;

	// Implements Seal
	uint256 public sealState;
	uint8 constant FEE_STATE = 1;
	uint8 constant FEEADDRESS_STATE = 2;
	uint8 constant QUOTER_STATE = 4;
	uint256 constant public maxSealState = 7;

	// Implements Seal
	event SealStateChange(bool indexed _final, uint256 _sealState);

	// EIP173
	event OwnershipTransferred(address indexed previousOwner, address indexed newOwner); // EIP173

	// Emitted after a successful swap
  	event Swap(
  		address indexed initiator,
  	  	address indexed tokenIn,
  	  	address tokenOut,
  	  	uint256 amountIn,
  	  	uint256 amountOut,
	  	uint256 fee
  	);

	// Emitted only after a liquidity donation
	event Deposit(
		address indexed initiator,
		address indexed tokenIn,
		uint256 amountIn
	);

	// Emitted when collecting fees to the set feeAddress
	event Collect(
		address indexed feeAddress,
		address tokenOut,
		uint256 amountOut
	);

	constructor(string memory _name, string memory _symbol, uint8 _decimals, address _tokenRegistry, address _tokenLimiter) {
		name = _name;
		symbol = _symbol;
		decimals = _decimals;
		tokenRegistry = _tokenRegistry;
		tokenLimiter = _tokenLimiter;
		owner = msg.sender;
	}

	function seal(uint256 _state) public returns(uint256) {
		require(_state <= maxSealState, 'ERR_INVALID_STATE');
		require(_state & sealState == 0, 'ERR_ALREADY_LOCKED');
		sealState |= _state;
		emit SealStateChange(sealState == maxSealState, sealState);
		return uint256(sealState);
	}

	function isSealed(uint256 _state) public view returns(bool) {
		require(_state < maxSealState);
		if (_state == 0) {
			return sealState == maxSealState;
		}
		return _state & sealState == _state;
	}

	// Change address for collecting fees
	function setFeeAddress(address _feeAddress) public {
		require(!isSealed(FEEADDRESS_STATE), "ERR_SEAL");
		require(msg.sender == owner, "ERR_AXX");
		feeAddress = _feeAddress;
	}

	// Change address for collecting fees
	function setFee(uint256 _fee) public {
		require(!isSealed(FEE_STATE), "ERR_SEAL");
		require(msg.sender == owner, "ERR_AXX");
		require(_fee < 1000000, "ERR_FEE_TOO_HIGH");
		feePpm = _fee;
	}

	// Change address for the quoter contract
	function setQuoter(address _quoter) public {
		require(!isSealed(QUOTER_STATE), "ERR_SEAL");
		require(msg.sender == owner, "ERR_AXX");
		quoter = _quoter;
	}

	// Implements EIP173
	function transferOwnership(address _newOwner) public returns (bool) {
		address oldOwner;

		require(msg.sender == owner);
		oldOwner = owner;
		owner = _newOwner;

		emit OwnershipTransferred(oldOwner, owner);
		return true;
	}

	function deposit(address _token, uint256 _value) public {
		_deposit(_token, _value);
		emit Deposit(msg.sender, _token, _value);
	}

	function _deposit(address _token, uint256 _value) private {
		bool r;
		bytes memory v;

		mustAllowedToken(_token, tokenRegistry);
		mustWithinLimit(_token, _value);

		(r, v) = _token.call(abi.encodeWithSignature('transferFrom(address,address,uint256)', msg.sender, this, _value));
		require(r, "ERR_TOKEN");
		r = abi.decode(v, (bool));
		require(r, "ERR_TRANSFER");

		totalSupply += _value;
	}

	function getFee(uint256 _value) private view returns (uint256) {
		uint256 fee;
		
		fee = _value * feePpm;
		fee /= 1000000;

		return fee;
	}

	function getQuote(address _outToken, address _inToken, uint256 _value) public returns (uint256) {
		bool r;
		bytes memory v;
		uint256 quote;

		if (quoter == address(0x0)) {
			return _value;
		}

		(r, v) = quoter.call(abi.encodeWithSignature('valueFor(address,address,uint256)', _outToken, _inToken, _value));
		require(r, "ERR_QUOTER");
		quote = abi.decode(v, (uint256));
		return quote;
	}

	function withdraw_less_fee(address _outToken, address _inToken, uint256 _value) public {
		bool r;
		bytes memory v;
		uint256 balance;
		uint256 fee;
		uint256 outValue;

		outValue = getQuote(_outToken, _inToken, _value);

		(r, v) = _outToken.call(abi.encodeWithSignature("balanceOf(address)", this));
		require(r, "ERR_TOKEN");
		balance = abi.decode(v, (uint256));

		// deduct the fees from the quoted outValue
		fee = getFee(outValue);
		outValue -= fee;
		
		// pool should have enough balance to cover the final outValue (fees already deducted)
		require(balance >= outValue, "ERR_BALANCE");

		_deposit(_inToken, _value);

		(r, v) = _outToken.call(abi.encodeWithSignature('transfer(address,uint256)', msg.sender, outValue));
		require(r, "ERR_TOKEN");
		r = abi.decode(v, (bool));
		require(r, "ERR_TRANSFER");
		
		if (feeAddress != address(0)) {
			fees[_outToken] += fee;
		}

		emit Swap(msg.sender, _inToken, _outToken, _value, outValue, fee);
	}

	function withdraw(address _outToken, address _inToken, uint256 _value) public {
		bool r;
		bytes memory v;
		uint256 netValue;
		uint256 outValue;
		uint256 balance;
		uint256 fee;

		fee = getFee(_value);
		netValue = _value - fee;
		netValue = getQuote(_outToken, _inToken, netValue);

		(r, v) = _outToken.call(abi.encodeWithSignature("balanceOf(address)", this));
		require(r, "ERR_TOKEN");
		balance = abi.decode(v, (uint256));
		outValue = netValue + fee;
		require(balance >= outValue, "ERR_BALANCE");

		deposit(_inToken, _value);

		(r, v) = _outToken.call(abi.encodeWithSignature('transfer(address,uint256)', msg.sender, netValue));
		require(r, "ERR_TOKEN");
		r = abi.decode(v, (bool));
		require(r, "ERR_TRANSFER");
		
		if (feeAddress != address(0)) {
			fees[_outToken] += fee;
		}

		emit Swap(msg.sender, _inToken, _outToken, _value, outValue, fee);
	}

	function withdraw(address _outToken, address _inToken, uint256 _value, bool _deduct_fee) public {
		if (_deduct_fee) {
			withdraw_less_fee(_outToken, _inToken, _value);
		} else {
			withdraw(_outToken, _inToken, _value);
		}
	}

	// Withdraw token to fee address
	function withdraw(address _outToken) public returns (uint256) {
		uint256 balance;

		balance = fees[_outToken];
		fees[_outToken] = 0;

		return withdraw(_outToken, balance);
	}

	function withdraw(address _outToken, uint256 _value) public returns (uint256) {
		bool r;
		bytes memory v;

		require(msg.sender == owner, "ERR_OWNER");
		require(feeAddress != address(0), "ERR_AXX");

		(r, v) = _outToken.call(abi.encodeWithSignature('transfer(address,uint256)', feeAddress, _value));
		require(r, "ERR_TOKEN");
		r = abi.decode(v, (bool));
		require(r, "ERR_TRANSFER");

		emit Collect(feeAddress, _outToken, _value);
		return _value;
	}

	function mustAllowedToken(address _token, address _tokenRegistry) private {
		bool r;
		bytes memory v;

		if (_tokenRegistry == address(0)) {
			return;
		}
		
		(r, v) = _tokenRegistry.call(abi.encodeWithSignature('have(address)', _token));
		require(r, "ERR_REGISTRY");
		r = abi.decode(v, (bool));
		require(r, "ERR_UNAUTH_TOKEN");
	}
	
	function mustWithinLimit(address _token, uint256 _valueDelta) private {
		bool r;
		bytes memory v;
		uint256 limit;
		uint256 balance;

		if (tokenLimiter == address(0)) {
			return;
		}


		(r, v) = tokenLimiter.call(abi.encodeWithSignature("limitOf(address,address)", _token, this));
		require(r, "ERR_LIMITER");
		limit = abi.decode(v, (uint256));

		(r, v) = _token.call(abi.encodeWithSignature("balanceOf(address)", this));
		require(r, "ERR_TOKEN");
		balance = abi.decode(v, (uint256));
		require(balance + _valueDelta <= limit, "ERR_LIMIT");
	}

	// Implements EIP165
	function supportsInterface(bytes4 _sum) public pure returns (bool) {
		if (_sum == 0x01ffc9a7) { // ERC165
			return true;
		}
		if (_sum == 0x9493f8b2) { // ERC173
			return true;
		}
		if (_sum == 0x0d7491f8) { // Seal
			return true;
		}
		return false;
	}
}

