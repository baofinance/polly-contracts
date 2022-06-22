const { ethers } = require("hardhat");

const weth = "0x7ceb23fd6bc0add59e62ac25578270cff1b9f619";
const lendingRegistry = "0xc94BC5C62C53E88d67C3874f5E8f91c6a99656ca";
const nestRegistry = "0x51E2F57C346e189c5a41e785d1563f93CCb8FaA1";
const bentoBox = "0x0319000133d3AdA02600f0875d2cf03D442C3367";
//Kashi Lending Master Contract
const masterContract = "0xB527C5295c4Bc348cBb3a2E96B2494fD292075a7";



async function main() {

    /*
    await hre.network.provider.request({
        method: "hardhat_impersonateAccount",
        params: [""],
    });

    const admin = await ethers.getSigner("");
    */
    //const recipeContract = await ethers.getContractAt("contracts/Recipes/RecipeV3.sol:RecipeV3","0x606dC2ab9672eF70704BC3B3A9654B2136796754");
    
   
    console.log("deploying....");
    //Deploy Recipe
    const recipeFactory = await ethers.getContractFactory("contracts/Recipes/RecipeV3.sol:RecipeV3");
    recipeContract = await recipeFactory.deploy(weth,lendingRegistry,nestRegistry,bentoBox,masterContract);
    await recipeContract.deployTransaction.wait();

    console.log("Recipe Deployed at: ", recipeContract.address);

    console.log("configuring....");
    //Configure Recipe
    //var transaction = await recipeContract.setBalancerPoolMapping("0x9a71012B13CA4d3D0Cdc72A177DF3ef03b0E76A3","0x0297e37f1873d2dab4487aa67cd56b58e2f27875000100000000000000000002");
    //await transaction.wait();
    transaction = await recipeContract.setBalancerPoolMapping("0x53E0bca35eC356BD5ddDFebbD1Fc0fD03FaBad39","0x36128d5436d2d70cab39c9af9cce146c38554ff0000100000000000000000008");
    await transaction.wait();
    transaction = await recipeContract.setBalancerPoolMapping("0xD6DF932A45C0f255f85145f286eA0b292B21C90B","0x36128d5436d2d70cab39c9af9cce146c38554ff0000100000000000000000008");
    await transaction.wait();
    transaction = await recipeContract.setBalancerPoolMapping("0x5fe2B58c013d7601147DcdD68C143A77499f5531","0x4e7f40cd37cee710f5e87ad72959d30ef8a01a5d00010000000000000000000b");
    await transaction.wait();
    transaction = await recipeContract.setBalancerPoolMapping("0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270","0x0297e37f1873d2dab4487aa67cd56b58e2f27875000100000000000000000002");
    await transaction.wait();
    transaction = await recipeContract.setBalancerPoolMapping("0xc2132D05D31c914a87C6611C10748AEb04B58e8F","0x0d34e5dd4d8f043557145598e4e2dc286b35fd4f000000000000000000000068");
    await transaction.wait();
    transaction = await recipeContract.setBalancerPoolMapping("0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063","0x0d34e5dd4d8f043557145598e4e2dc286b35fd4f000000000000000000000068");
    await transaction.wait();
    transaction = await recipeContract.setBalancerPoolMapping("0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174","0x0d34e5dd4d8f043557145598e4e2dc286b35fd4f000000000000000000000068");
    await transaction.wait();
    transaction = await recipeContract.setUniPoolMapping("0xb33EaAd8d922B1083446DC23f610c2567fB5180f",3000);
    await transaction.wait();
    transaction = await recipeContract.setUniPoolMapping("0x172370d5Cd63279eFa6d502DAB29171933a610AF",10000);
    await transaction.wait();
    transaction = await recipeContract.setUniPoolMapping("0x53E0bca35eC356BD5ddDFebbD1Fc0fD03FaBad39",3000);
    await transaction.wait();
    transaction = await recipeContract.setCustomHop("0x580A84C73811E1839F75d86d75d88cCa0c241fF4", "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270");
    await transaction.wait();
    transaction = await recipeContract.setCustomHop("0xFbdd194376de19a88118e84E279b977f165d01b8", "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174");
    await transaction.wait();
    transaction = await recipeContract.setCustomHop("0x4e78011Ce80ee02d2c3e649Fb657E45898257815", "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174");
    await transaction.wait();
    /*
    //console.log("baking....");
    //Weth approval
    const wethContract = await ethers.getContractAt("contracts/Interfaces/IERC20.sol:IERC20","0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619");
    transaction = await wethContract.connect(admin).approve(recipeContract.address, ethers.utils.parseEther("1.0"));
    await transaction.wait();

    //Test Recipe Bake 
    transaction = await recipeContract.connect(admin).bake("0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619","0x14bbe7D3826B5f257B7dde0852036BC94C323ccA","5000000000000000","1000000000000000000");
    await transaction.wait()*/
    //console.log("Getting nest price")
    //console.log((await recipeContract.callStatic.getPrice("0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619", "0x14bbe7D3826B5f257B7dde0852036BC94C323ccA", "100000000000000000000")).toString());
    
}

main()
.then(() => process.exit(0))
.catch((error) => {
    console.error(error);
    process.exit(1);
});
