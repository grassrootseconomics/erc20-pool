# standard imports
import unittest
import logging
import os
from chainlib.eth.nonce import RPCNonceOracle
from chainlib.eth.tx import receipt
from chainlib.eth.block import block_latest
from hexathon import same as same_hex
from eth_erc20 import ERC20
from giftable_erc20_token import GiftableToken

# local imports
from erc20_pool.unittest import TestERC20Pool
from erc20_pool import Pool

logging.basicConfig(level=logging.DEBUG)
logg = logging.getLogger()

class TestPoolFee(TestERC20Pool):

    def test_swap_fee(self):
        nonce_oracle = RPCNonceOracle(self.accounts[0], conn=self.conn)
        c = Pool(self.chain_spec, signer=self.signer, nonce_oracle=nonce_oracle)
        (tx_hash, o) = c.set_fee_address(self.pool_address, self.accounts[0], self.accounts[9])
        self.rpc.do(o)
        o = receipt(tx_hash)
        r = self.conn.do(o)
        self.assertEqual(r['status'], 1)

        (tx_hash, o) = c.set_fee(self.pool_address, self.accounts[0], 10000)
        self.rpc.do(o)
        o = receipt(tx_hash)
        r = self.conn.do(o)
        self.assertEqual(r['status'], 1)

        nonce_oracle = RPCNonceOracle(self.accounts[0], conn=self.conn)
        c = ERC20(self.chain_spec, signer=self.signer, nonce_oracle=nonce_oracle)
        (tx_hash, o) = c.approve(self.foo_address, self.accounts[0], self.pool_address, 1000)
        self.rpc.do(o)
       
        c = Pool(self.chain_spec, signer=self.signer, nonce_oracle=nonce_oracle)
        (tx_hash, o) = c.deposit(self.pool_address, self.accounts[0], self.foo_address, 1000)
        self.rpc.do(o)
      
        nonce_oracle = RPCNonceOracle(self.accounts[1], conn=self.conn)
        c = ERC20(self.chain_spec, signer=self.signer, nonce_oracle=nonce_oracle)
        (tx_hash, o) = c.approve(self.bar_address, self.accounts[1], self.pool_address, 1000)
        self.rpc.do(o)
        
        c = Pool(self.chain_spec, signer=self.signer, nonce_oracle=nonce_oracle)
        (tx_hash, o) = c.swap(self.pool_address, self.accounts[1], self.foo_address, self.bar_address, 1000)
        self.rpc.do(o)

        c = ERC20(self.chain_spec, signer=self.signer, nonce_oracle=nonce_oracle)
        o = c.balance_of(self.foo_address, self.accounts[1], sender_address=self.accounts[0])
        r = self.rpc.do(o)
        self.assertEqual(int(r, 16), 990)

        c = Pool(self.chain_spec, signer=self.signer, nonce_oracle=nonce_oracle)
        (tx_hash, o) = c.withdraw(self.pool_address, self.accounts[1], self.foo_address)
        self.rpc.do(o)
        o = receipt(tx_hash)
        r = self.conn.do(o)
        self.assertEqual(r['status'], 0)

        nonce_oracle = RPCNonceOracle(self.accounts[0], conn=self.conn)
        c = Pool(self.chain_spec, signer=self.signer, nonce_oracle=nonce_oracle)
        (tx_hash, o) = c.withdraw(self.pool_address, self.accounts[0], self.foo_address)
        self.rpc.do(o)
        o = receipt(tx_hash)
        r = self.conn.do(o)
        self.assertEqual(r['status'], 1)

        c = ERC20(self.chain_spec, signer=self.signer, nonce_oracle=nonce_oracle)
        o = c.balance_of(self.foo_address, self.accounts[9], sender_address=self.accounts[0])
        r = self.rpc.do(o)
        self.assertEqual(int(r, 16), 10)


if __name__ == '__main__':
    unittest.main()
