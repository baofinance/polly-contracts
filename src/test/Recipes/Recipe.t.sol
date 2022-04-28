pragma solidity ^0.7.0;

import "ds-test/test.sol";
import "../../Recipes/Recipe.sol";
import "../BasketsTestSuite.sol";
import "./RecipeConfiguration.sol";

contract RecipeTest is DSTest {

    BasketsTestSuite public testSuite;
    RecipeConfigurator public recipeConfigurator;

    function setUp() public {
        testSuite = new BasketsTestSuite();
        recipeConfigurator = new RecipeConfigurator(address(testSuite.recipe()), address(testSuite));
    }

    function testMint() public {

	Recipe recipe = testSuite.recipe();
        IERC20 basket = IERC20(testSuite.bDEFI());

        basket.approve(address(recipe), type(uint256).max);
        uint[] memory mintAmounts = new uint[](2);

        mintAmounts[0] = 1e18;
        mintAmounts[1] = 10e18;

        for (uint256 i = 0; i < mintAmounts.length; i++) {
            uint256 initialBalance = address(this).balance;
            (uint256 mintPrice, uint16[] memory dexIndex) = recipe.getPricePie(address(basket), mintAmounts[i]);
            recipe.toPie{value : mintPrice}(
                address(basket),
                mintAmounts[i],
                dexIndex
            );
            uint256 basketBalance = basket.balanceOf(address(this));
            assertGe(basketBalance, mintAmounts[i]);
            assertEq(mintPrice, initialBalance - address(this).balance);
        }
    }

    function testRedeem() public {
        Recipe recipe = testSuite.recipe();
        IExperiPie basket = IExperiPie(testSuite.bDEFI());

        (uint256 mintPrice, uint16[] memory dexIndex) = recipe.getPricePie(address(basket), 1e18);

        recipe.toPie{value : mintPrice}(
            address(basket),
            1e18,
            dexIndex
        );

        (address[] memory _tokens, uint256[] memory _amounts) = basket.calcTokensForAmountExit(1e18);
        basket.exitPool(1e18);

        for (uint8 i; i < _tokens.length; i++) {
            assertGt(_amounts[i], 0);

            uint256 balance = IERC20(_tokens[i]).balanceOf(address(this));
            assertEq(balance, _amounts[i]);
        }
    }
    receive() external payable{}
}
