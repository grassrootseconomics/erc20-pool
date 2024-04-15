# erc20-pool

A token pool implementation that allows _deposits_ in the form of _liquidity donations_, and _withdrawals_ in the form of _token swaps_.

It satisfies the [CIC TokenSwap](https://git.grassecon.net/cicnet/cic-contracts/#tokenswap) interface.


## Synopsis

| agent | action | agent change | pool change |
|---|---|---|---|
| alice | deposit(FOO, 1000000) | -1000000 FOO | +1000000 FOO |
| bob | withdraw(FOO, BAR, 1000) | -1000 BAR, +1000 FOO | +1000 BAR, -1000 FOO |
| alice | withdraw(BAR, FOO, 1000) | +1000 BAR, -1000 FOO | -1000 BAR, +1000 FOO |


## Publishing the contract

There are five constructor arguments.

The first three, `name`, `symbol` and `decimals` have matching getter methods, are analogous to the ERC20 methods of the same name.

The `tokenRegistry` parameter takes an address to a smart contract controlling which tokens are allowed in the pool. See "Token approval" below. A value of `address(0x0)` deactivates this control, and allows the pool to hold all tokens by default (although they may still be subject to value limits).

The `tokenLimiter` parameter takes an address to a smart contract controlling value limits of tokens in the pool. See "Token limits" below. A value of `address(0x0)` deactivates this control, and allows any value of (approved) tokens to be held by the pool.


### Token approval

By specifying a non-zero contract address for the `tokenRegistry` property that implements the [CIC ACL](https://git.grassecon.net/cicnet/cic-contracts/#acl) interface, that contract can be used to allow and disallow which tokens can be used as input tokens to `deposit()` and `withdraw()`.

Tokens that are disallowed while the pool still holds a balance can still be withdrawn in full.


### Token limits

By specifying a non-zero contract address for the `tokenRegistry` property that implements the [CIC TokenLimit](https://git.grassecon.net/cicnet/cic-contracts/#tokenlimit) interface, that contract can be used to control the value limit allowed for each token in the pool.

Tokens that are limited below the current balance held by the pool can still be withdrawn. Once the balance goes below the limit, additional tokens values may again be swapped, up to the limit.


#### Using limiter as registry

The [erc20-limiter](https://holbrook.no/src/erc20-limiter/log.html) repository contains the smart contract implementation `LimiterIndex.sol`. This uses the token limit state to satisfy the [CIC ACL](https://git.grassecon.net/cicnet/cic-contracts/#acl) interface. Specifically, any token limit higher than 0 will be defined as allowed.

This enables to publisher to use the same smart contract for both constructor arguments `tokenRegistry` and `tokenLimiter`. 


## Swapping tokens

The method used to execute token swaps is  `withdraw(outToken, inToken, value)`.

The `value` argument refers to the value of `inToken` that will be transferred to the pool contract, in exchange for some value of `outToken` (see below).

In order to successfully execute the swap, an ERC20 "approval" must exist for the pool contract to spend at least the value of `inToken` specified by the `value` argument.


### Handling values

The pool contract does no checking whatsoever regarding the sanity of allowing tokens in the pool.

It is therefore the responsibility of the maintainer of the list of allowed tokens to ensure that tokens in the pool are exchangeable in a sensible way.

Some obvious concerns are:

- Tokens are swapped denominated in their smallest unit (regardless of "decimals").
- The unit of account of the tokens may differ.
- The value of the tokens in relation to unit of account may differ.
- The tokens may be subject to different rates of change.


### Providing quotes

Using the `setQuoter()` method, a smart contract address can be defined that translates value between tokens when exchanging tokens in the pool.

The value returned from the "quoter" is the value of output tokens that will be received in return for the value of input tokens specified.

The "quoter" smart contract must satisfy the [CIC TokenQuote](https://git.grassecon.net/cicnet/cic-contracts/#tokenquote) interface.

An example quoter contract `DecimalQuote.sol` can be found in this repository. The contract translates values according to the decimal count reported by the respective ERC20 tokens.


## Fees

Using the `setFee` method, a fee may be specified, in parts-per-million, to be deducted from each token swap.

_From the moment the fee has changed_, the fee will be deducted from the input token _before_ the value is sent to the "quoter" (if defined).

Fee is defined in _parts-per-million_, i.e. `1000000` equals `100%`. Any value less than `1000000` is valid.


### Fee recipient

By default, all deducted fees are credited to the pool contract.

Using the `setFeeAddress` method, an external beneficiary for the fees may be defined. That beneficiary will be eligible to receive all fees pending external payment _from that moment on_.

**Important!** Note that this does also include any fees that were not already claimed by a previous beneficiary.


#### Withdrawing fees

Fees to be paid externally are accounted for internally in the contract, and may be withdrawn at any time using either the `withdraw(outToken)` or `withdraw(outToken, value)` method.

Note the difference between the fee withdrawal methods, and the method signature from the exchange method: `withdraw(outToken, inToken, value)`.


## Sealing contract properties

The contract implements the [CIC Seal](https://git.grassecon.net/cicnet/cic-contracts/#seal) interface for the following properties:

- Fee value
- Fee address
- Quoter contract address

Sealing allowed token lists and/or their respective value limits is the responsibility of the provider contracts themselves.
