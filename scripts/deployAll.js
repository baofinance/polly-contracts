const { ethers } = require("hardhat");
const fs = require('fs');

const weth = "0x7ceb23fd6bc0add59e62ac25578270cff1b9f619";
const wmatic = "0x0d500b1d8e8ef31e21c99d1db9a6444d3adf1270";
const sushiRouter = "0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506";
const bentoBox = "0x0319000133d3AdA02600f0875d2cf03D442C3367";
//Kashi Lending Master Contract
const masterContract = "0xB527C5295c4Bc348cBb3a2E96B2494fD292075a7";
const kashiProtocol = "0x000000000000000000000000d3f07ea86ddf7baebefd49731d7bbd207fedc53b";

var nestContract;
var lendingManagerContract;
var nestRegistryContract;
var basketFacetContract;
var callFacetContract;
var diamondCutFacetContract;
var diamondLoupeFacetContract;
var ERC20FacetContract;
var ownershipFacetContract;
var lendingRegistryContract;
var diamondContract;
var factoryContract;
var kashiLendingContract;
var recipeContract;

async function main() {

    ////////////////////////////////////////
    //Contract Deployments
    ////////////////////////////////////////
    await deployFacets();
    await deployNestRegistry();
    await deployLendingRegistry();
    await deployDiamond();
    await deployFactory();
    await deployLendingStrategies();
    await createNest();
    await deployLendingManager();
    await deployRecipe();
    await setPrivilege();

    ////////////////////////////////////////
    //Configurations
    ////////////////////////////////////////
    await configureLending();
    await configureNestRegistry();

    async function deployFacets(){

        //BasketFacet
        var facetFactory = await ethers.getContractFactory("BasketFacet");
        basketFacetContract = await facetFactory.deploy();
        await basketFacetContract.deployTransaction.wait();

        //CallFacet
        var differntfacetFactory = await ethers.getContractFactory("CallFacet");
        callFacetContract = await differntfacetFactory.deploy();
        await callFacetContract.deployTransaction.wait();

        //DiamondCutFacet
        facetFactory = await ethers.getContractFactory("DiamondCutFacet");
        diamondCutFacetContract = await facetFactory.deploy();
        await diamondCutFacetContract.deployTransaction.wait();

        //DiamondLoupeFacet
        facetFactory = await ethers.getContractFactory("DiamondLoupeFacet");
        diamondLoupeFacetContract = await facetFactory.deploy();
        await diamondLoupeFacetContract.deployTransaction.wait();

        //ERC20Facet
        facetFactory = await ethers.getContractFactory("ERC20Facet");
        ERC20FacetContract = await facetFactory.deploy();
        await ERC20FacetContract.deployTransaction.wait();

        //OwnershipFacet
        facetFactory = await ethers.getContractFactory("OwnershipFacet");
        ownershipFacetContract = await facetFactory.deploy();
        await ownershipFacetContract.deployTransaction.wait();

        console.log("Facets Deployed");
        
    }

    async function deployNestRegistry(){
        //deploy nest registry
        var nestRegistryFactory = await ethers.getContractFactory("SmartPoolRegistry");
        nestRegistryContract = await nestRegistryFactory.deploy();
        await nestRegistryContract.deployTransaction.wait();

        console.log("Nest Registry Deployed");
    }

    async function deployLendingRegistry(){
        //deploy lending registry
        var lendingRegistryFactory = await ethers.getContractFactory("contracts/LendingRegistry.sol:LendingRegistry");
        lendingRegistryContract = await lendingRegistryFactory.deploy();
        await lendingRegistryContract.deployTransaction.wait();

        console.log("Lending Registry Deployed");
    }

    async function deployDiamond(){
        //deploy diamond
        var diamondFactory = await ethers.getContractFactory("Diamond");
        diamondContract = await diamondFactory.deploy();
        await diamondContract.deployTransaction.wait();

        console.log("Diamond Deployed");
    }

    async function deployFactory(){
        //deploy nest factory
        var factoryFactory = await ethers.getContractFactory("PieFactoryContract");
        factoryContract = await factoryFactory.deploy();
        await factoryContract.deployTransaction.wait();

        var transaction = await factoryContract.setDiamondImplementation(diamondContract.address);
        await transaction.wait();

        //Array of Facets used by the Diamond
        const facetArray = [
            [ERC20FacetContract.address,0,["0xeedfca5f","0x06fdde03","0xc47f0027","0x95d89b41","0xb84c8246","0x313ce567","0x40c10f19","0x9dc29fac","0x095ea7b3","0xd73dd623","0x66188463","0xa9059cbb","0x23b872dd","0xdd62ed3e","0x70a08231","0x18160ddd"]],
            [basketFacetContract.address,0,["0xd48bfca7","0x5fa7b584","0xeb770d0c","0xe586a4f0","0xe5a583a9","0xecb0116a","0xef512424","0xad293cf2","0x5a0a3d82","0xd908c3e5","0x8a8257dd","0x9d3f7dd4","0xfff3087c","0x366254e8","0x34e7a19f","0xbe1d24ad","0xec9c2b39","0x5d44c9cb","0x7e5852d9","0xaecb9356","0x560ad134","0xd3e15747","0x47786d37","0xe3d670d7","0xaa6ca808","0x554d578d","0x371babdc","0x23817b8e","0xddbcb5fa","0xf50ab0de","0x9baf58d2","0x3809283a","0x6ed93dd0","0xf47c84c5"]],
            [ownershipFacetContract.address,0,["0xf2fde38b","0x8da5cb5b"]],
            [callFacetContract.address,0,["0x747293fb","0xeef21cd2","0x30c9473c","0xbd509fd5","0x98a9884d","0xcb6e7a89","0xdd8d4c40","0xbf29b3a7"]],
            [diamondCutFacetContract.address,0,["0x1f931c1c"]],
            [diamondLoupeFacetContract.address,0,["0x7a0ed627","0xadfca15e","0x52ef6b2c","0xcdffacc6","0x01ffc9a7"]]]
        
        //Add Facet info to factory, used for future nest creations
        for (const facet of facetArray) {
            var tranasctionTx = await factoryContract.addFacet(facet);
            await tranasctionTx.wait();
            console.log("Facet Saved");
        }

        console.log("Factory Deployed");
    }

    async function deployLendingStrategies(){
        //Deploy  Kashi Lending
        const kashiLendingFactory = await ethers.getContractFactory("LendingLogicKashi");
        kashiLendingContract = await kashiLendingFactory.deploy(lendingRegistryContract.address, kashiProtocol, bentoBox);
        await kashiLendingContract.deployTransaction.wait();
        
        console.log("Lending Logic Deployed");
    } 

    async function createNest(){
        //Prep information needed for nest creation
        //Rai , Dai , USDT, USDC
        const nestsTokens = ["0x2791bca1f2de4661ed88a30c99a7a9449aa84174"];
        const nestsTokenAmounts = ["100000000"];
        const nestsInitialSupply = ethers.utils.parseEther("100");
        const nestSymbol = "tstNest";
        const nestName = "Test Nest";

        await buyTokens(nestsTokens,nestsTokenAmounts);

        await approveTokens(factoryContract.address,nestsTokens,nestsTokenAmounts);

        //Create new Nest
        var transaction = await factoryContract.bakePie(nestsTokens,nestsTokenAmounts,nestsInitialSupply,nestSymbol,nestName);
        await transaction.wait();

        //Save newly created nest contract address
        nestContract = (await factoryContract.pies(0));

        console.log("Nest Created");
    }

    async function deployLendingManager(){
        //Deploy Lending Manger for each nest
        const lendingManagerFactory = await ethers.getContractFactory("LendingManager");
        
        lendingManagerContract = await lendingManagerFactory.deploy(lendingRegistryContract.address, nestContract);
        await lendingManagerContract.deployTransaction.wait();

        console.log("Lending Manager Deployed");
    } 

    async function deployRecipe(){

        //Deploy Recipe
        const recipeFactory = await ethers.getContractFactory("V1CompatibleRecipe");
        recipeContract = await recipeFactory.deploy(weth,sushiRouter,lendingRegistryContract.address,nestRegistryContract.address,bentoBox,masterContract);
        await recipeContract.deployTransaction.wait();

        console.log("Recipe Deployed");
    }

    async function configureLending(){

        //Set Protocol To Lending
        var setPtLTx1 = await lendingRegistryContract.setProtocolToLogic("0x000000000000000000000000d3f07ea86ddf7baebefd49731d7bbd207fedc53b", kashiLendingContract.address);
        setPtLTx1.wait();

        //setWrappedToProtocol
        var setPtLTx2 = await lendingRegistryContract.setWrappedToProtocol("0xd51b929792cfcde30f2619e50e91513dcec89b23","0x000000000000000000000000d3f07ea86ddf7baebefd49731d7bbd207fedc53b");
        setPtLTx2.wait();

        //setWrappedToUnderlying
        var setPtLTx3 = await lendingRegistryContract.setWrappedToUnderlying("0xd51b929792cfcde30f2619e50e91513dcec89b23", "0x2791bca1f2de4661ed88a30c99a7a9449aa84174");
        setPtLTx3.wait();

        //setUnderlyingToProtocolWrapped
        var setPtLTx4 = await lendingRegistryContract.setUnderlyingToProtocolWrapped("0x2791bca1f2de4661ed88a30c99a7a9449aa84174","0x000000000000000000000000d3f07ea86ddf7baebefd49731d7bbd207fedc53b", "0xd51b929792cfcde30f2619e50e91513dcec89b23");
        setPtLTx4.wait();

    }

    async function configureNestRegistry(){
        const transasction = await nestRegistryContract.addSmartPool(nestContract);
        await transasction.wait();
    }

    async function setPrivilege(){
        const callFacetNest = await ethers.getContractAt("CallFacet",nestContract);

        //Approve user1 to make calls for nest
        var transction = await callFacetNest.addCaller((await ethers.getSigners())[0].address);
        await transction.wait();

        //Approve Lending Manager to make calls for nest
        transction = await callFacetNest.addCaller(lendingManagerContract.address);
        await transction.wait();

        console.log("Lending Manager added as caller");

        //Approve KashiLending for Nest
        let ABI = [
            "function setMasterContractApproval(address,address,bool,uint8,bytes32,bytes32)"
        ];
        let interface = new ethers.utils.Interface(ABI);

        var encodedData = await interface.encodeFunctionData("setMasterContractApproval",[nestContract, masterContract,true,0,"0x0000000000000000000000000000000000000000000000000000000000000000","0x0000000000000000000000000000000000000000000000000000000000000000"]);
        transction = await callFacetNest.callNoValue([bentoBox],[encodedData]);
        await transction.wait();

        console.log("Nest approved for Kashi Lending");
    }

      //Print all addresses
      console.log("----------------------------------------------------------------------------");
      console.log("Deployed Addresses:");
      console.log("----------------------------------------------------------------------------");
      console.log("nestRegistryContract             " + nestRegistryContract.address);
      console.log("lendingRegistryContract          " + lendingRegistryContract.address);
      console.log("diamondContract                  " + diamondContract.address);
      console.log("factoryContract                  " + factoryContract.address);
      console.log("kashiLendingContract             " + kashiLendingContract.address);
      console.log("nestContract                     " + nestContract);
      console.log("lendingManagerContract           " + lendingManagerContract.address);
      console.log("recipeContract                   " + recipeContract.address);
      console.log("----------------------------------------------------------------------------");
      console.log("----------------------------------------------------------------------------");

      //Save Addresses to txt File for tests
      const content = nestRegistryContract.address + "," + lendingRegistryContract.address + "," + diamondContract.address + "," + factoryContract.address + "," + kashiLendingContract.address + "," + nestContract + "," + lendingManagerContract.address + "," + recipeContract.address
      fs.writeFileSync('./deployedContracts.txt', content, err => {
          if (err) {
              console.error(err)
              return
          }
      });
  }

  async function buyTokens(tokensToBuy,tokenAmounts){
    for (let i = 0; i < tokensToBuy.length; i++) {
        const sushiRounterContract = await ethers.getContractAt("contracts/Interfaces/IUniRouter.sol:IUniswapV2Router01",sushiRouter);  
        var block = await ethers.provider.getBlockNumber();
        var transaction = await sushiRounterContract.swapETHForExactTokens(tokenAmounts[i], [wmatic,weth,tokensToBuy[i]], (await ethers.getSigners())[0].address, (await ethers.provider.getBlock(block)).timestamp + 5,{value: ethers.utils.parseEther("100.0").toString()});
        await transaction.wait(); 
    }
}

async function approveTokens(spender,tokens,tokenAmounts){
    for (let i = 0; i < tokens.length; i++) {
        const token = await ethers.getContractAt("contracts/OpenZeppelin/ERC20.sol:ERC20",tokens[i]);    
        var transaction = await token.approve(spender, tokenAmounts[i]);
        await transaction.wait(); 
    }
}
  
  main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
