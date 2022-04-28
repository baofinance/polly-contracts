pragma solidity ^0.7.0;

import "ds-test/test.sol";
import { Constants } from "./constants.sol";
import "../Diamond/BasketFacet.sol";
import "../Diamond/CallFacet.sol";
import "../Diamond/DiamondCutFacet.sol";
import "../Diamond/DiamondLoupeFacet.sol";
import "../Diamond/ERC20Facet.sol";
import "../Diamond/OwnershipFacet.sol";
import "../BasketRegistry.sol";
import { Oven } from "../Oven.sol";
import { OvenFactoryContract } from "../OvenFactory.sol";
import "../LendingRegistry.sol";
import "../Diamond/Diamond.sol";
import "../BasketFactoryContract.sol";
import "../Interfaces/IDiamondCut.sol";
import { LendingLogicKashi } from "../Strategies/KashiLending/LendingLogicKashi.sol";
import { LendingLogicAaveV2 } from "../Strategies/LendingLogicAaveV2.sol";
import { LendingLogicCompound } from "../Strategies/LendingLogicCompound.sol";
import { StakingLogicSushi } from "../Strategies/StakingLogicSushi.sol";
import { LendingManager } from "../LendingManager.sol";
import { Recipe } from "../Recipes/Recipe.sol";
import { IUniswapV2Router01 } from "../Interfaces/IUniRouter.sol";

interface Cheats {
    function deal(address who, uint256 amount) external;
    function startPrank(address sender) external;
    function stopPrank() external;
}

pragma experimental ABIEncoderV2;

/**
 * Helper contract for this project's test suite
 */
contract BasketsTestSuite is DSTest {

    // Foundry Cheat Codes
    Cheats public cheats;

    //Mainnet Constants
    Constants public constants;

    // Facets
    BasketFacet public basketFacet;
    CallFacet public callFacet;
    DiamondCutFacet public cutFacet;
    DiamondLoupeFacet public loupeFacet;
    ERC20Facet public erc20Facet;
    OwnershipFacet public ownershipFacet;

    // Basket Registry
    BasketRegistry public basketRegistry;

    // Lending Registry
    LendingRegistry public lendingRegistry;

    // Diamond
    Diamond public diamond;

    // Factory
    BasketFactoryContract public basketFactory;

    // Lending Manager & Logic
    LendingManager public bSLendingManager;
    LendingManager public bDLendingManager;
    LendingLogicKashi public lendingLogicKashi;
    LendingLogicAaveV2 public lendingLogicAave;
    LendingLogicCompound public lendingLogicCompound;
    StakingLogicSushi public stakingLogicSushi;

    // Recipe
    Recipe public recipe;
     
    // OvenFactory
    OvenFactoryContract public ovenFactory;

    // Oven
    Oven public bDEFIOven;
    Oven public bSTBLOven;

    // Test Basket
    address public bDEFI;
    address public bSTBL;

    // Constants
    address[] public bDEFI_BASKET_TOKENS;
    address[] public bSTBL_BASKET_TOKENS;
    //Lending Option Config
    address public SUSHI_ROUTER = 0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F;
    address public BENTO_BOX = 0xF5BCE5077908a1b7370B9ae04AdC565EBd643966;
    address public KASHI_MEDIUM_RISK = 0x2cBA6Ab6574646Badc84F0544d05059e57a5dc42;
    bytes32 public XSUSHI_PROTOCOL = 0x0000000000000000000000000000000000000000000000000000000000000004;
    bytes32 public KASHI_PROTOCOL = 0x0000000000000000000000000000000000000000000000000000000000000003;
    bytes32 public AAVE_PROTOCOL = 0x0000000000000000000000000000000000000000000000000000000000000002;   
    bytes32 public COMP_PROTOCOL =  0x0000000000000000000000000000000000000000000000000000000000000001;

    constructor () {
        // Give our test suite some ETH
        cheats = Cheats(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        cheats.deal(address(this), 1000 ether);
        
	//Get Constants
        constants = new Constants();

        // Set the tokens that we'll put in our test baskets
        bDEFI_BASKET_TOKENS.push(constants.CVX());
        bDEFI_BASKET_TOKENS.push(constants.MKR());
        bDEFI_BASKET_TOKENS.push(constants.AAVE());
        bDEFI_BASKET_TOKENS.push(constants.COMP());
        bDEFI_BASKET_TOKENS.push(constants.LDO());
        bDEFI_BASKET_TOKENS.push(constants.YFI());
	bDEFI_BASKET_TOKENS.push(constants.BAL());
	bDEFI_BASKET_TOKENS.push(constants.LQTY());
        bDEFI_BASKET_TOKENS.push(constants.CRV());
        bDEFI_BASKET_TOKENS.push(constants.FXS());
        bDEFI_BASKET_TOKENS.push(constants.UNI());        
	bDEFI_BASKET_TOKENS.push(constants.SUSHI());

        bSTBL_BASKET_TOKENS.push(constants.DAI());
	bSTBL_BASKET_TOKENS.push(constants.FRAX());
	bSTBL_BASKET_TOKENS.push(constants.FEI());
	bSTBL_BASKET_TOKENS.push(constants.RAI());    
 
        deployProtocol();
    }

    // ---------------------------------
    // SET UP
    // ---------------------------------

    function deployProtocol() private {
        // Deploy Facets
        basketFacet = new BasketFacet();
        callFacet = new CallFacet();
        erc20Facet = new ERC20Facet();
        cutFacet = new DiamondCutFacet();
        loupeFacet = new DiamondLoupeFacet();
        ownershipFacet = new OwnershipFacet();

        // Deploy Basket Registry
        basketRegistry = new BasketRegistry();

        // Deploy Lending Registry
        lendingRegistry = new LendingRegistry();

        // Deploy Diamond
        diamond = new Diamond();

        // Deploy Factory & Set Facets
        basketFactory = new BasketFactoryContract();
        basketFactory.setDiamondImplementation(address(diamond));

        bytes4[] memory erc20FacetCutSelectors = new bytes4[](16);
        erc20FacetCutSelectors[0] = 0xeedfca5f;
        erc20FacetCutSelectors[1] = 0x06fdde03;
        erc20FacetCutSelectors[2] = 0xc47f0027;
        erc20FacetCutSelectors[3] = 0x95d89b41;
        erc20FacetCutSelectors[4] = 0xb84c8246;
        erc20FacetCutSelectors[5] = 0x313ce567;
        erc20FacetCutSelectors[6] = 0x40c10f19;
        erc20FacetCutSelectors[7] = 0x9dc29fac;
        erc20FacetCutSelectors[8] = 0x095ea7b3;
        erc20FacetCutSelectors[9] = 0xd73dd623;
        erc20FacetCutSelectors[10] = 0x66188463;
        erc20FacetCutSelectors[11] = 0xa9059cbb;
        erc20FacetCutSelectors[12] = 0x23b872dd;
        erc20FacetCutSelectors[13] = 0xdd62ed3e;
        erc20FacetCutSelectors[14] = 0x70a08231;
        erc20FacetCutSelectors[15] = 0x18160ddd;
        IDiamondCut.FacetCut memory erc20FacetCut = IDiamondCut.FacetCut(address(erc20Facet), IDiamondCut.FacetCutAction.Add, erc20FacetCutSelectors);
        basketFactory.addFacet(erc20FacetCut);

        bytes4[] memory basketFacetCutSelectors = new bytes4[](34);
        basketFacetCutSelectors[0] = 0xd48bfca7;
        basketFacetCutSelectors[1] = 0x5fa7b584;
        basketFacetCutSelectors[2] = 0xeb770d0c;
        basketFacetCutSelectors[3] = 0xe586a4f0;
        basketFacetCutSelectors[4] = 0xe5a583a9;
        basketFacetCutSelectors[5] = 0xecb0116a;
        basketFacetCutSelectors[6] = 0xef512424;
        basketFacetCutSelectors[7] = 0xad293cf2;
        basketFacetCutSelectors[8] = 0x5a0a3d82;
        basketFacetCutSelectors[9] = 0xd908c3e5;
        basketFacetCutSelectors[10] = 0x8a8257dd;
        basketFacetCutSelectors[11] = 0x9d3f7dd4;
        basketFacetCutSelectors[12] = 0xfff3087c;
        basketFacetCutSelectors[13] = 0x366254e8;
        basketFacetCutSelectors[14] = 0x34e7a19f;
        basketFacetCutSelectors[15] = 0xbe1d24ad;
        basketFacetCutSelectors[16] = 0xec9c2b39;
        basketFacetCutSelectors[17] = 0x5d44c9cb;
        basketFacetCutSelectors[18] = 0x7e5852d9;
        basketFacetCutSelectors[19] = 0xaecb9356;
        basketFacetCutSelectors[20] = 0x560ad134;
        basketFacetCutSelectors[21] = 0xd3e15747;
        basketFacetCutSelectors[22] = 0x47786d37;
        basketFacetCutSelectors[23] = 0xe3d670d7;
        basketFacetCutSelectors[24] = 0xaa6ca808;
        basketFacetCutSelectors[25] = 0x554d578d;
        basketFacetCutSelectors[26] = 0x371babdc;
        basketFacetCutSelectors[27] = 0x23817b8e;
        basketFacetCutSelectors[28] = 0xddbcb5fa;
        basketFacetCutSelectors[29] = 0xf50ab0de;
        basketFacetCutSelectors[30] = 0x9baf58d2;
        basketFacetCutSelectors[31] = 0x3809283a;
        basketFacetCutSelectors[32] = 0x6ed93dd0;
        basketFacetCutSelectors[33] = 0xf47c84c5;
        IDiamondCut.FacetCut memory basketFacetCut = IDiamondCut.FacetCut(address(basketFacet), IDiamondCut.FacetCutAction.Add, basketFacetCutSelectors);
        basketFactory.addFacet(basketFacetCut);

        bytes4[] memory ownershipFacetCutSelectors = new bytes4[](2);
        ownershipFacetCutSelectors[0] = 0xf2fde38b;
        ownershipFacetCutSelectors[1] = 0x8da5cb5b;
        IDiamondCut.FacetCut memory ownershipFacetCut = IDiamondCut.FacetCut(address(ownershipFacet), IDiamondCut.FacetCutAction.Add, ownershipFacetCutSelectors);
        basketFactory.addFacet(ownershipFacetCut);

        bytes4[] memory callFacetCutSelectors = new bytes4[](8);
        callFacetCutSelectors[0] = 0x747293fb;
        callFacetCutSelectors[1] = 0xeef21cd2;
        callFacetCutSelectors[2] = 0x30c9473c;
        callFacetCutSelectors[3] = 0xbd509fd5;
        callFacetCutSelectors[4] = 0x98a9884d;
        callFacetCutSelectors[5] = 0xcb6e7a89;
        callFacetCutSelectors[6] = 0xdd8d4c40;
        callFacetCutSelectors[7] = 0xbf29b3a7;
        IDiamondCut.FacetCut memory callFacetCut = IDiamondCut.FacetCut(address(callFacet), IDiamondCut.FacetCutAction.Add, callFacetCutSelectors);
        basketFactory.addFacet(callFacetCut);

        bytes4[] memory diamondCutFacetSelectors = new bytes4[](1);
        diamondCutFacetSelectors[0] = 0x1f931c1c;
        IDiamondCut.FacetCut memory diamondFacetCut = IDiamondCut.FacetCut(address(diamond), IDiamondCut.FacetCutAction.Add, diamondCutFacetSelectors);
        basketFactory.addFacet(diamondFacetCut);

        bytes4[] memory loupeFacetCutSelectors = new bytes4[](5);
        loupeFacetCutSelectors[0] = 0x7a0ed627;
        loupeFacetCutSelectors[1] = 0xadfca15e;
        loupeFacetCutSelectors[2] = 0x52ef6b2c;
        loupeFacetCutSelectors[3] = 0xcdffacc6;
        loupeFacetCutSelectors[4] = 0x01ffc9a7;
        IDiamondCut.FacetCut memory loupeFacetCut = IDiamondCut.FacetCut(address(loupeFacet), IDiamondCut.FacetCutAction.Add, loupeFacetCutSelectors);
        basketFactory.addFacet(loupeFacetCut);
        
        // Deploy Lending Strategies
        lendingLogicKashi = new LendingLogicKashi(address(lendingRegistry), KASHI_PROTOCOL, BENTO_BOX);
        lendingLogicAave = new LendingLogicAaveV2(0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9, 0);
        lendingLogicCompound = new LendingLogicCompound(address(lendingRegistry), COMP_PROTOCOL);
        stakingLogicSushi = new StakingLogicSushi(address(lendingRegistry), XSUSHI_PROTOCOL);
        
        // Create Test Basket
        uint256[] memory bDEFITokenAmounts = new uint256[](12);
        uint256[] memory bSTBLTokenAmounts = new uint256[](4);
	//bDEFI
        bDEFITokenAmounts[0] = 76e16;
        bDEFITokenAmounts[1] = 1e16;
        bDEFITokenAmounts[2] = 9e16;
        bDEFITokenAmounts[3] = 11e16;
        bDEFITokenAmounts[4] = 331e16;
        bDEFITokenAmounts[5] = 41e17;
        bDEFITokenAmounts[6] = 406e12;
        bDEFITokenAmounts[7] = 3959e14;
	bDEFITokenAmounts[8] = 341e16;
        bDEFITokenAmounts[9] = 246e16;
        bDEFITokenAmounts[10] = 1359e14;
        bDEFITokenAmounts[11] = 18e16;
        //bSTBL
        bSTBLTokenAmounts[0] = 25e16;
        bSTBLTokenAmounts[1] = 25e16;
        bSTBLTokenAmounts[2] = 25e16;
        bSTBLTokenAmounts[3] = 83333333333333333;

        uint256 initialDEFISupply = 10 ether;
        uint256 initialSTBLSupply = 1 ether;

        getTokensFromHolders(bDEFITokenAmounts,bDEFI_BASKET_TOKENS);
        approveTokens(address(basketFactory),bDEFI_BASKET_TOKENS);

        getTokensFromHolders(bSTBLTokenAmounts,bSTBL_BASKET_TOKENS);
        approveTokens(address(basketFactory),bSTBL_BASKET_TOKENS);

        basketFactory.bakeBasket(bDEFI_BASKET_TOKENS, bDEFITokenAmounts, initialDEFISupply, "bDEFI", "bDEFI Test Basket");
        bDEFI = basketFactory.baskets(0);
        basketFactory.bakeBasket(bSTBL_BASKET_TOKENS, bSTBLTokenAmounts, initialSTBLSupply, "bSTBL", "bSTBL Test Basket");
        bSTBL = basketFactory.baskets(1);
        
        // Deploy Lending Manager
        bDLendingManager = new LendingManager(address(lendingRegistry), bDEFI);
	bSLendingManager = new LendingManager(address(lendingRegistry), bSTBL);

        // Deploy Recipe
        recipe = new Recipe(constants.WETH(), address(lendingRegistry), address(basketRegistry), BENTO_BOX, KASHI_MEDIUM_RISK);

        // Deploy OvenFactory
        ovenFactory = new OvenFactoryContract();
        ovenFactory.setDefaultController(address(this));
        bDEFIOven = ovenFactory.CreateOven(address(bDEFI),address(recipe));
        bSTBLOven = ovenFactory.CreateOven(address(bSTBL),address(recipe));
  
        // Set privileges
        CallFacet bDBasketCF = CallFacet(bDEFI);
        bDBasketCF.addCaller(address(this));
        bDBasketCF.addCaller(address(bDLendingManager));
    
        CallFacet bSBasketCF = CallFacet(bSTBL);
        bSBasketCF.addCaller(address(this));
        bSBasketCF.addCaller(address(bSLendingManager));        

        // Approve Kashi Lending for Basket
        address[] memory a = new address[](1);
        a[0] = BENTO_BOX;
        bytes[] memory b = new bytes[](1);
        b[0] = abi.encodeWithSignature("setMasterContractApproval(address,address,bool,uint8,bytes32,bytes32)", bDEFI, KASHI_MEDIUM_RISK, true, 0, bytes32(0), bytes32(0));
        bDBasketCF.callNoValue(a, b);
	a[0] = BENTO_BOX;
	b[0] = abi.encodeWithSignature("setMasterContractApproval(address,address,bool,uint8,bytes32,bytes32)", bSTBL, KASHI_MEDIUM_RISK, true, 0, bytes32(0), bytes32(0));
        bSBasketCF.callNoValue(a, b);       
 
        // Configure Lending
        // USDC - KASHI
        lendingRegistry.setProtocolToLogic(KASHI_PROTOCOL, address(lendingLogicKashi));
        lendingRegistry.setWrappedToProtocol(0xB7b45754167d65347C93F3B28797887b4b6cd2F3, KASHI_PROTOCOL); // Kashi Medium Risk V1
        lendingRegistry.setWrappedToUnderlying(0xB7b45754167d65347C93F3B28797887b4b6cd2F3, constants.USDC()); // USDC
        lendingRegistry.setUnderlyingToProtocolWrapped(constants.USDC(), KASHI_PROTOCOL, 0xB7b45754167d65347C93F3B28797887b4b6cd2F3);
        // DAI - COMPOUND
        lendingRegistry.setProtocolToLogic(COMP_PROTOCOL, address(lendingLogicCompound));
        lendingRegistry.setWrappedToProtocol(constants.cDAI(), COMP_PROTOCOL);
        lendingRegistry.setWrappedToUnderlying(constants.cDAI(), constants.DAI());
        lendingRegistry.setUnderlyingToProtocolWrapped(constants.DAI(), COMP_PROTOCOL, constants.cDAI());
        // RAI - AAVE
	lendingRegistry.setProtocolToLogic(AAVE_PROTOCOL, address(lendingLogicAave));
        lendingRegistry.setWrappedToProtocol(constants.aRAI(), AAVE_PROTOCOL);
        lendingRegistry.setWrappedToUnderlying(constants.aRAI(), constants.RAI());
        lendingRegistry.setUnderlyingToProtocolWrapped(constants.RAI(), AAVE_PROTOCOL, constants.aRAI());
	// FRAX - AAVE
	lendingRegistry.setProtocolToLogic(AAVE_PROTOCOL, address(lendingLogicAave));
        lendingRegistry.setWrappedToProtocol(constants.aFRAX(), AAVE_PROTOCOL);
        lendingRegistry.setWrappedToUnderlying(constants.aFRAX(), constants.FRAX());
        lendingRegistry.setUnderlyingToProtocolWrapped(constants.FRAX(), AAVE_PROTOCOL, constants.aFRAX());
 	// FEI - AAVE 
 	lendingRegistry.setProtocolToLogic(AAVE_PROTOCOL, address(lendingLogicAave));
        lendingRegistry.setWrappedToProtocol(constants.aFEI(), AAVE_PROTOCOL);
        lendingRegistry.setWrappedToUnderlying(constants.aFEI(), constants.FEI());
        lendingRegistry.setUnderlyingToProtocolWrapped(constants.FEI(), AAVE_PROTOCOL, constants.aFEI());
        // SUSHI - xSUSHI
        lendingRegistry.setProtocolToLogic(XSUSHI_PROTOCOL, address(stakingLogicSushi));
        lendingRegistry.setWrappedToProtocol(constants.xSUSHI(), XSUSHI_PROTOCOL);
        lendingRegistry.setWrappedToUnderlying(constants.xSUSHI(), constants.SUSHI());
        lendingRegistry.setUnderlyingToProtocolWrapped(constants.SUSHI(), XSUSHI_PROTOCOL, constants.xSUSHI());
        
        // Add basket to basket registry
        basketRegistry.addBasket(bDEFI);
        basketRegistry.addBasket(bSTBL);
 
        //Lend USDC into KASHI Lending
        //lendingManager.lend(constants.USDC(), IERC20(constants.USDC()).balanceOf(bSTBL), KASHI_PROTOCOL);
        //Lend DAI into COMPOUND
        bSLendingManager.lend(constants.DAI(), IERC20(constants.DAI()).balanceOf(bSTBL), COMP_PROTOCOL);
        //Lend RAI into AAVE
        bSLendingManager.lend(constants.RAI(), IERC20(constants.RAI()).balanceOf(bSTBL), AAVE_PROTOCOL);
        //Lend FRAX into AAVE
        bSLendingManager.lend(constants.FRAX(), IERC20(constants.FRAX()).balanceOf(bSTBL), AAVE_PROTOCOL);
	//Lend FEI into AAVE
        bSLendingManager.lend(constants.FEI(), IERC20(constants.FEI()).balanceOf(bSTBL), AAVE_PROTOCOL);
	//Stake SUSHI into xSUSHI/Sushi Bar
        bDLendingManager.lend(constants.SUSHI(), IERC20(constants.SUSHI()).balanceOf(bDEFI), XSUSHI_PROTOCOL);
    }

    // ---------------------------------
    // HELPER FUNCTIONS
    // ---------------------------------

    function buyTokens(uint256[] memory _tokenAmounts, address[] memory _tokens) private {
        require(_tokenAmounts.length == _tokens.length, "Error: Incorrect length of token amounts array.");

        IUniswapV2Router01 router = IUniswapV2Router01(SUSHI_ROUTER);
        for (uint8 i; i < _tokens.length; i++) {
            address[] memory route = _getRoute(constants.WETH(), _tokens[i]);
            uint256 amountIn = router.getAmountsIn(_tokenAmounts[i], route)[0];

            router.swapExactETHForTokens{value: amountIn}(
                _tokenAmounts[i],
                route,
                address(this),
                block.timestamp
            );
        }
    }
    
    function getTokensFromHolders(uint[] memory _tokenAmounts, address[] memory _tokens) private {
        require(_tokenAmounts.length == _tokens.length, "Error: Incorrect length of token amounts array.");
        for (uint8 i; i < _tokens.length; i++) {
	    address holder = constants.tokenHolders(_tokens[i]);
            uint holderBalance = IERC20(_tokens[i]).balanceOf(holder);
            require(holderBalance >= _tokenAmounts[i], "Error getTokesFromHolders: Holder doesn't have enough token to provide for testing");
            cheats.startPrank(holder); 
            IERC20(_tokens[i]).transfer(address(this),_tokenAmounts[i]);
            cheats.stopPrank();
        }          
    }

    function approveTokens(address spender, address[] memory _tokens) private {
        for (uint8 i; i < _tokens.length; i++) {
            IERC20 token = IERC20(_tokens[i]);
            token.approve(spender, type(uint256).max);
        }
    }

    function _getRoute(address a, address b) private returns (address[] memory route) {
        route = new address[](2);
        route[0] = a;
        route[1] = b;
    }

    receive() external payable{}
}
