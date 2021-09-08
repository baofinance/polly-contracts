# NestContracts
Deployed Polly-(PieDao) contracts.<br/>
All contracts are forked from the PieDao deployment on the Ethereum Mainnet, with some minor changes that to allow them to function on Pollygon.<br/>
These changes are detailed below.<br/>
<br/>
In order to understand the smart contract setup and query the nests correctly you will have to familiarize yourself with the *Diamond Standard* architecture, with which these contracts where build https://eips.ethereum.org/EIPS/eip-2535.

# Contract Changes
	The original contracts deployed by PieDao can be found here: <br />
	https://docs.piedao.org/technical/deployed-smart-contracts <br />
1.  The contracts where ported as is from the PieDaos implementation on Main net with a few exceptions:
	On the Polygon network the Aave protocol requires the sender to state the address where the amTokens or underlying tokens should be send when depositing or withdrawing.
	This required small changes in the following contracts:<br />
	**ILendingLogic.so**
	```
		function lend(address _underlying, uint256 _amount, address _tokenHolder) external view returns(address[] memory targets, bytes[] memory data);
	
		function unlend(address _wrapped, uint256 _amount, address _tokenHolder) external view returns(address[] memory targets, bytes[] memory data);
	```
	
	**LendingRegestry.sol**
	```
	function getLendTXData(address _underlying, uint256 _amount, address _tokenHolder, bytes32 _protocol) external view returns(address[] memory targets, bytes[] memory data) {
		ILendingLogic lendingLogic = ILendingLogic(protocolToLogic[_protocol]);
		require(address(lendingLogic) != address(0), "NO_LENDING_LOGIC_SET");

		return lendingLogic.lend(_underlying, _amount, _tokenHolder);
	}
	```
	**AaveLendingLogic.sol**
	```
	function lend(address _underlying,uint256 _amount, address _tokenHolder) external view override returns(address[] memory targets, bytes[] memory data) {
		IERC20 underlying = IERC20(_underlying);

		targets = new address[](3);
		data = new bytes[](3);

		// zero out approval to be sure
		targets[0] = _underlying;
		data[0] = abi.encodeWithSelector(underlying.approve.selector, address(lendingPool), 0);

		// Set approval
		targets[1] = _underlying;
		data[1] = abi.encodeWithSelector(underlying.approve.selector, address(lendingPool), _amount);

		// Deposit into Aave
		targets[2] = address(lendingPool);
		data[2] =  abi.encodeWithSelector(lendingPool.deposit.selector, _underlying, _amount, _tokenHolder, referralCode);

		return(targets, data);
	}

	function unlend(address _wrapped, uint256 _amount,address _tokenHolder) external view override returns(address[] memory targets, bytes[] memory data) {
		ATokenV2 wrapped = ATokenV2(_wrapped);

		targets = new address[](1);
		data = new bytes[](1);

		targets[0] = address(lendingPool);
		data[0] = abi.encodeWithSelector(
			lendingPool.withdraw.selector,
			wrapped.UNDERLYING_ASSET_ADDRESS(),
			_amount,
			_tokenHolder
		);

		return(targets, data);
	}
	```
	**CREAMLendingLogic.sol**
	```
	function lend(address _underlying, uint256 _amount, address _tokenHolder) external view override returns(address[] memory targets, bytes[] memory data) {
		IERC20 underlying = IERC20(_underlying);

		targets = new address[](3);
		data = new bytes[](3);


		address cToken = lendingRegistry.underlyingToProtocolWrapped(_underlying, protocolKey);

		// zero out approval to be sure
		targets[0] = _underlying;
		data[0] = abi.encodeWithSelector(underlying.approve.selector, cToken, 0);

		// Set approval
		targets[1] = _underlying;
		data[1] = abi.encodeWithSelector(underlying.approve.selector, cToken, _amount);

		// Deposit into Compound
		targets[2] = cToken;

		data[2] =  abi.encodeWithSelector(ICToken.mint.selector, _amount);

		return(targets, data);
	}

	function unlend(address _wrapped, uint256 _amount, address _tokenHolder) external view override returns(address[] memory targets, bytes[] memory data) {
		targets = new address[](1);
		data = new bytes[](1);

		targets[0] = _wrapped;
		data[0] = abi.encodeWithSelector(ICToken.redeem.selector, _amount);

		return(targets, data);
	}
	```
	The contracts listed above do not have any access to the funds that are held by the nest.
	At worst errors in these contracts would result in user minting a wrong amount of a nest or the user would fail to mint the nest.
	
	**LendingManger.sol**
		
	Changing the LendingManager requires increased vigilance, as it has direct access to the Nests funds. 	
	This is the only change made to the LendingManager:
	
	BEFORE CHANGE	
	```
        ) = lendingRegistry.getLendTXData(_underlying, amount, _protocol);
	```	
	
	AFTER CHANGE	
	```
        ) = lendingRegistry.getLendTXData(_underlying, amount, address(basket),_protocol);
	```
	The `basket` constant is set on deployment and cannot be changed retroactively. <br />
	```
	constructor(address _lendingRegistry, address _basket) public {
        require(_lendingRegistry != address(0), "INVALID_LENDING_REGISTRY");
        require(_basket != address(0), "INVALID_BASKET");
        lendingRegistry = LendingRegistry(_lendingRegistry);
        basket = IExperiPie(_basket);
    }
	```
	The basket address is the address of the nest that the LendingManager is assigned to.
	
	
	
2.	The "Recipe" contract is used to swap the users wETH for the index assets and lend them in a specific protocol when needed.
	As the recipe does not have access to any funds deposited in the index, we felt like more liberties could be made adjusting the code.
	The following is a change that allows us to take an entry fee that is exchanged for polly and then burned:
	
	```
	if(remainingInputBalance > 0 && feeAmount != 0) {
		WETH.approve(address(sushiRouter), 0);
		WETH.approve(address(sushiRouter), type(uint256).max);
		address[] memory route = getRoute(address(WETH), baoAddress);
		uint256 estimatedAmount = sushiRouter.getAmountsOut(feeAmount, route)[1];
		sushiRouter.swapExactTokensForTokens(feeAmount, estimatedAmount, route, address(this), block.timestamp + 1);
		baoToken.burn(baoToken.balanceOf(address(this)));    
    }
	```
3. 	Originally the recipe always looks at Uniswap and SushiSwap to identify the best price. The new Recipe does not check the prices and only trades on SushiSwap.

```
	function getBestPriceSushiUni(address _inputToken, address _outputToken, uint256 _outputAmount) internal returns(uint256, DexChoice) {
		uint256 sushiAmount = getPriceUniLike(_inputToken, _outputToken, _outputAmount, sushiRouter);

		return (sushiAmount, DexChoice.Sushi);
	}
```

	
# Deployed Contract Addresses

PieFactory: 0x6A10bB7Ac83Fdd9ceCDb13A8CFC3FC0A017912E2

Diamond: 0x0589C472C35Fc7CaE089DBbAEFB050dD642Ce481

DiamondCutFacet: 0x828125Ec1dAa708677b844ABb05f339741C81d25

DiamondLoupFacet: 0xdC1C3eE57e8D7a898671aF2634E57B6cc7c81F57

OwnershipFacet: 0xe3fAA5d1feCbc4402Ff4a08684e3BcF70732C2e0

BasketFacet: 0xE4f21842E5D7faD1FB360B7623946376db94fEF3

ERC20Facet: 0x92f0049c548B9ff3fe28F2FBd576c6DAF20bEcf2

CallFacet: 0x1F3A8584691847edD43BC1eDCE83F9B1B7d7555B

LendingRegestry: 0xc94BC5C62C53E88d67C3874f5E8f91c6a99656ca

PieRegistry: 0x51E2F57C346e189c5a41e785d1563f93CCb8FaA1

Rebalancer: 0xC47D9A6725fFEE67727d3aE8fFa2630A47d649C4

AAVELendingLogic:					 	0x9eda65278543E2497701Fd5964D86b880d2DCB98	<br />
Protocol: 						0x0000000000000000000000009eda65278543E2497701Fd5964D86b880d2DCB98 <br />

CREAMLendingLogic:					0x58aFFd9251e7147d46eb8614893dA2B37AdfcB28<br />
Protocol: 						0x0000000000000000000000001d7a03b6e011561074c9da9572a374bd15928d18<br />

Recipe: 0x2E62EE5005c4069e82d37479f42D1a7Aa2C1B8ba<br />

PProxy/Nest: <br />    
			
0:    Polly nDefi Nest (nDEFI): 		0xd3f07EA86DDf7BAebEfd49731D7Bbd207FedC53B  <br />
		LendingManager:					 	0x3f323a6E3Bddff52529fA9ac94CFCc6E755A0242<br />
			
1:	  TBD:<br />
		LendingManager:<br />
		
2:	  TBD:<br />
LendingManager:<br />