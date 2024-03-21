SOLC = /usr/local/bin/solc

all:
	$(SOLC) --bin SwapPool.sol --evm-version istanbul | awk 'NR>3' > SwapPool.bin
	$(SOLC) --abi SwapPool.sol --evm-version istanbul | awk 'NR>3' > SwapPool.json
	$(SOLC) --metadata SwapPool.sol --evm-version istanbul | awk 'NR>3' > SwapPool.metadata.json
	truncate -s -1 SwapPool.bin
	$(SOLC) --bin DecimalQuote.sol --evm-version istanbul | awk 'NR>3' > DecimalQuote.bin
	$(SOLC) --abi DecimalQuote.sol --evm-version istanbul | awk 'NR>3' > DecimalQuote.json
	$(SOLC) --metadata DecimalQuote.sol --evm-version istanbul | awk 'NR>3' > DecimalQuote.metadata.json
	truncate -s -1 DecimalQuote.bin

install: all
	cp -v *.json ../python/erc20_pool/data/
	cp -v *.bin ../python/erc20_pool/data/

