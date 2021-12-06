# NestContracts
Deployed Nest- (PieDao) contracts

# Contract Changes

1. 	Originaly the recipe always looks at Uniswap and SushiSwap to identify the best price. The new Recipe does not check the prices and only trades on SushiSwap.

2.  The contracts where ported as is from the PieDaos implementation on Main net with a few exceptions:
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
	**LendingManger.sol**

	Changing the LendingManager requires increased vigilants, as it has direct access to the Nests funds. 	
	This is the only change made to the LendingManager:

	BEFORE CHANGE	
	```
        ) = lendingRegistry.getLendTXData(_underlying, amount, _protocol);
	```	

	AFTER CHANGE	
	```
        ) = lendingRegistry.getLendTXData(_underlying, amount, address(basket),_protocol);
	```
	The `basket` constant is set on deployment and cannot be changed retroactively. 
	It is the address of the nest/index that the LendingManager is assigned to.
	
	**Recipe contracts**

	The "Recipe" contract is used to swap the users wETH for the index assets and lend them in a specific protocol when needed.
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
	The recipe will likely see several adjustments in the future as the ecosystem changes and we have to adjust how we swap/lend assets.

# Deployed Contract Addresses

PieFactory: 0x6A10bB7Ac83Fdd9ceCDb13A8CFC3FC0A017912E2

Diamond: 0x0589C472C35Fc7CaE089DBbAEFB050dD642Ce481

DiamondCutFacet: 0x828125Ec1dAa708677b844ABb05f339741C81d25

DiamondLoupFacet: 0xdC1C3eE57e8D7a898671aF2634E57B6cc7c81F57

OwnershipFacet: 0xe3fAA5d1feCbc4402Ff4a08684e3BcF70732C2e0

BasketFacet: 0xE4f21842E5D7faD1FB360B7623946376db94fEF3

ERC20Facet: 0x92f0049c548B9ff3fe28F2FBd576c6DAF20bEcf2

CallFacet: 0x1F3A8584691847edD43BC1eDCE83F9B1B7d7555B

LendingRegistry: 0xc94BC5C62C53E88d67C3874f5E8f91c6a99656ca

PieRegistry: 0x51E2F57C346e189c5a41e785d1563f93CCb8FaA1

Rebalancer: 0xC47D9A6725fFEE67727d3aE8fFa2630A47d649C4

AAVELendingPool: 0x8dFf5E27EA6b7AC08EbFdf9eB090F32ee9a30fcf

AAVELendingLogic:					0x9eda65278543E2497701Fd5964D86b880d2DCB98	<br />
Protocol: 						0x0000000000000000000000009eda65278543E2497701Fd5964D86b880d2DCB98 <br />

CREAMLendingLogic:					0x58aFFd9251e7147d46eb8614893dA2B37AdfcB28<br />
Protocol: 						0x0000000000000000000000001d7a03b6e011561074c9da9572a374bd15928d18<br />

KashiLendingLogic:					0x7F9d1B200cBA0D99e200e211E5fafFBE880DF41F<br />
Protocol: 						0x000000000000000000000000d3f07ea86ddf7baebefd49731d7bbd207fedc53b<br />

Recipe: 0x2E62EE5005c4069e82d37479f42D1a7Aa2C1B8ba <br />

RecipeV2: 0x0C9DF041582741b9Ae384F31209A6Dc7ea6B9Bcb <br />

PProxy/Nest: <br />    

0:    Polly nDefi Nest (nDEFI): 		0xd3f07EA86DDf7BAebEfd49731D7Bbd207FedC53B  <br />
		LendingManager:					 	0x3f323a6E3Bddff52529fA9ac94CFCc6E755A0242 <br />

1:    Polly nStable Nest (nSTBL): 	0x9Bf320bd1796a7495BB6187f9EB4Db2679b74eD3<br />
		LendingManager:						0x8924F050699a15D33a34dD90215EBEe0aD72e9C3 <br />


# Regarding LendingLogic:

There is one central LendingRegistry which dictates to which protocol underlying assets are to be lend.<br />
Each nest requires an individual LendingManger.<br />
This LendingManager is used to change lending strategies for individual tokens within a nest.<br />
There is only one AAVELendingLogic/CREAMLendingLogic/KashiLendingLogic contract required for all nests.<br />
For each lending strategy we have to generate a unique Protocol Hash that is saved in the LendingRegistry <br />

#KashiLending Notes: 

Before being able to use kashi lending the nest must be approved by the kashi master contract. <br />
To do this we need to send calldata to the bentoBox via the nests callFacet. <br />
To create the callData we can use the contract ./Utility/KashiLendingEncoder <br />
LendingEncoder: 0xa59AdAA7b04324e43e768E8E2C1aCEAb592fa79E <br />
MasterContract: 0xb527c5295c4bc348cbb3a2e96b2494fd292075a7 <br />

# Setting Up Facets

The PieFactory includes a method called "addFacet()". With this function we add the methods of the facets to the Diamond mappings so that it knows where to deligate certain function calls.<br />
Formating the addFacet() inputs can be quite time consuming. <br />

The following is a template where only the facet addresses have to be added:
```
["ERC20FacetAddress",0,["0xeedfca5f","0x06fdde03","0xc47f0027","0x95d89b41","0xb84c8246","0x313ce567","0x40c10f19","0x9dc29fac","0x095ea7b3","0xd73dd623","0x66188463","0xa9059cbb","0x23b872dd","0xdd62ed3e","0x70a08231","0x18160ddd"]]
["BasketFacetAddress",0,["0xd48bfca7","0x5fa7b584","0xeb770d0c","0xe586a4f0","0xe5a583a9","0xecb0116a","0xef512424","0xad293cf2","0x5a0a3d82","0xd908c3e5","0x8a8257dd","0x9d3f7dd4","0xfff3087c","0x366254e8","0x34e7a19f","0xbe1d24ad","0xec9c2b39","0x5d44c9cb","0x7e5852d9","0xaecb9356","0x560ad134","0xd3e15747","0x47786d37","0xe3d670d7","0xaa6ca808","0x554d578d","0x371babdc","0x23817b8e","0xddbcb5fa","0xf50ab0de","0x9baf58d2","0x3809283a","0x6ed93dd0","0xf47c84c5"]]	
["OwnerFacetAddress",0,["0xf2fde38b","0x8da5cb5b"]]
["CallFacetAddress",0,["0x747293fb","0xeef21cd2","0x30c9473c","0xbd509fd5","0x98a9884d","0xcb6e7a89","0xdd8d4c40","0xbf29b3a7"]]
["DiamondCutFacetAddress",0,["0x1f931c1c"]]
["DiamondLoupeFacetAddress",0,["0x7a0ed627","0xadfca15e","0x52ef6b2c","0xcdffacc6","0x01ffc9a7"]]```