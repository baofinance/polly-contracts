const { expect } = require("chai");
const { ethers } = require("hardhat");
const fs = require('fs');

const weth = "0x7ceb23fd6bc0add59e62ac25578270cff1b9f619";
const wmatic = "0x0d500b1d8e8ef31e21c99d1db9a6444d3adf1270";
const sushiRouter = "0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506";
const kashiProtocol = "0x000000000000000000000000d3f07ea86ddf7baebefd49731d7bbd207fedc53b";
const USDC = "0x2791bca1f2de4661ed88a30c99a7a9449aa84174";
const kmUSDC = "0xd51b929792cfcde30f2619e50e91513dcec89b23";
const bentoBox = "0x0319000133d3AdA02600f0875d2cf03D442C3367";
const masterContract = "0xB527C5295c4Bc348cBb3a2E96B2494fD292075a7";

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


describe("Test Nest Functionality", function () { 
    //We have long loading times 
    this.timeout(100000);
   
    //Get deployed addresses and create contract objects
    fs.readFile('./DeployedContracts.txt', 'utf8' , async function (err, data) {
        if (err) {
            console.error(err)
            return
        }
        var addressArr = data.split(',');
        //We are addressing the unitroller
        nestRegistryContract = await ethers.getContractAt("SmartPoolRegistry",addressArr[1]);
        lendingRegistryContract = await ethers.getContractAt("contracts/LendingRegistry.sol:LendingRegistry",addressArr[1]);
        diamondContract = await ethers.getContractAt("Diamond",addressArr[2]);
        factoryContract = await ethers.getContractAt("PieFactoryContract",addressArr[3]);
        kashiLendingContract = await ethers.getContractAt("LendingLogicKashi",addressArr[4]);
        nestContract = await ethers.getContractAt("contracts/OpenZeppelin/ERC20.sol:ERC20",addressArr[5]);
        lendingManagerContract = await ethers.getContractAt("LendingManager",addressArr[6]);
        recipeContract = await ethers.getContractAt("V1CompatibleRecipe", addressArr[7]);     

        user1 = (await ethers.getSigners())[0];
        user2 = (await ethers.getSigners())[1];

        await setUserBalances();
    });

    it("Load Existing Contracts", async function () {
        await sleep(5000);
        function sleep(ms) {
            return new Promise(resolve => setTimeout(resolve, ms));
        }
    });    

    it("LendingManager Lends to Kashi", async function () {
        const usdcToken = await ethers.getContractAt("contracts/OpenZeppelin/ERC20.sol:ERC20",USDC);
        const kmToken = await ethers.getContractAt("contracts/OpenZeppelin/ERC20.sol:ERC20",kmUSDC);

        console.log("kmToken balance pre lend", (await kmToken.balanceOf(nestContract.address)).toString());

        var tranasction = await lendingManagerContract.lend(USDC, "100000000", kashiProtocol);
        tranasction.wait();

        console.log("kmToken balance post lend", (await kmToken.balanceOf(nestContract.address)).toString());

        //All USDC should be lend
        expect(await usdcToken.balanceOf(nestContract.address)).to.equal(0);

        //Kashi tokens should be deposited in nest
        expect((await kmToken.balanceOf(nestContract.address))).to.gt(0);
    });

    it("LendingManager Unlend to Kashi", async function () {
        const usdcToken = await ethers.getContractAt("contracts/OpenZeppelin/ERC20.sol:ERC20",USDC);
        const kmToken = await ethers.getContractAt("contracts/OpenZeppelin/ERC20.sol:ERC20",kmUSDC);

        //Mine some blocks
        await evmMine();
        await evmMine();
        await evmMine();
        await evmMine();

        //Unlend USDC 
        var tranasction = await lendingManagerContract.unlend(kmUSDC, ethers.utils.parseEther("100"));
        tranasction.wait();

        console.log("kmToken balance post unlend", (await kmToken.balanceOf(nestContract.address)).toString());

        //All USDC should be back in the Basket account
        expect("100000000").to.lt((await usdcToken.balanceOf(nestContract.address)));

        //Basket should have 0 kmTokens
        expect(0).to.equal((await kmToken.balanceOf(nestContract.address)));

        //Lend again so that we can test Recipe 
        var tranasction = await lendingManagerContract.lend(USDC, "1000000000", kashiProtocol);
        tranasction.wait();

        console.log("kmToken balance post 2nd lend", (await kmToken.balanceOf(nestContract.address)).toString());
    });

    it("Minting Tokens", async function () {

        const mintAmount = ethers.utils.parseEther("2");

        const encodedMintAmount = ethers.utils.defaultAbiCoder.encode(["uint"],[mintAmount]);
        
        const preMintBalance = await nestContract.balanceOf(user1.address);

        await buyWeth([weth],[ethers.utils.parseEther("1")]);

        //Approve Weth spending by recipe  
        await approveTokens(recipeContract.address, [weth], [ethers.utils.parseEther("1")]);
        
        //Join pool
        const mintingTx = await recipeContract.bake(weth,nestContract.address,ethers.utils.parseEther("1"),encodedMintAmount);
        mintingTx.wait();       

        //Check the the correct number of tokens where minted
        expect((await nestContract.balanceOf(user1.address))).to.equal(preMintBalance.add(mintAmount));
    });

    async function setUserBalances(){
        await network.provider.send("hardhat_setBalance", [
            user1.address,
            //30b Eth
            "0x9B18AB5DF7180B6B8000000",
        ]);

        await network.provider.send("hardhat_setBalance", [
            user2.address,
            ////30b Eth
            "0x9B18AB5DF7180B6B8000000",
        ]);
    }

    async function approveTokens(spender,tokens,tokenAmounts){
        for (let i = 0; i < tokens.length; i++) {
            const token = await ethers.getContractAt("contracts/OpenZeppelin/ERC20.sol:ERC20",tokens[i]);    
            var transaction = await token.approve(spender, tokenAmounts[i]);
            transaction.wait(); 
        }
    }

    async function buyWeth(tokensToBuy,tokenAmounts){
        for (let i = 0; i < tokensToBuy.length; i++) {
            const sushiRounterContract = await ethers.getContractAt("contracts/Interfaces/IUniRouter.sol:IUniswapV2Router01",sushiRouter);  
            var block = await ethers.provider.getBlockNumber();
            const timestamp = (await ethers.provider.getBlock(block)).timestamp + 10000;
            var transaction = await sushiRounterContract.swapETHForExactTokens(tokenAmounts[i], [wmatic,tokensToBuy[i]], (await ethers.getSigners())[0].address, timestamp,{value: ethers.utils.parseEther("10000.0").toString()});
            transaction.wait(); 
        }
    }

    const evmMine = async () => { return await hre.network.provider.send("evm_mine"); }
    
});