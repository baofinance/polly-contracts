pragma solidity ^0.7.0;

import "ds-test/test.sol";
import "../../Interfaces/IRecipe.sol";
import {Cheats} from "../BasketsTestSuite.sol";

contract RecipeConfigurator is DSTest {

    IRecipe public recipe;

    // Foundry Cheat Codes
    Cheats public cheats;

    constructor (address _recipe, address _recipeOwner) {
        recipe = IRecipe(_recipe);
        cheats = Cheats(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        cheats.startPrank(_recipeOwner);
        setUni();
        setBalancer();
        cheats.stopPrank();
    }

    function setUni() public {
    }

    function setBalancer() public {
        recipe.setBalancerPoolMapping(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, 0x96646936b91d6b9d7d0c47c496afbf3d6ec7b6f8000200000000000000000019);
    }
}
