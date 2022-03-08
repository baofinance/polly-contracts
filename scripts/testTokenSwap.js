const { ethers } = require("hardhat");
const { Contract } = require("hardhat/internal/hardhat-network/stack-traces/model");


async function main() {

    let tokenHolderAddresses = ["0x06959153b974d0d5fdfd87d561db6d8d4fa0bb0b","0xba12222222228d8ba445958a75a0704d566bf2c8","0x1d2a0e5ec8e5bbdca5cb219e649b565d8e5c3360","0xb2a33ae0e07fd2ca8dbde9545f6ce0b3234dc4e8","0x21ec9431b5b55c5339eb1ae7582763087f98fac2"];
    let outTokens = ['0x172370d5Cd63279eFa6d502DAB29171933a610AF','0x9a71012B13CA4d3D0Cdc72A177DF3ef03b0E76A3','0xD6DF932A45C0f255f85145f286eA0b292B21C90B','0xb33EaAd8d922B1083446DC23f610c2567fB5180f','0x0b3F868E0BE5597D5DB7fEB59E1CADBb0fdDa50a'];
    let inTokens = ['0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619','0x53E0bca35eC356BD5ddDFebbD1Fc0fD03FaBad39','0x6f7C932e7684666C9fd1d44527765433e01fF61d','0x50B728D8D964fd00C2d0AAD81718b71311feF68a','0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270','0x3066818837c5e6eD6601bd5a91B0762877A6B731','0x95c300e7740D2A88a44124B424bFC1cB2F9c3b89','0x3AE490db48d74B1bC626400135d4616377D0109f','0xc81278a52AD0e1485B7C3cDF79079220Ddd68b7D','0x4257EA7637c355F81616050CbB6a9b709fd72683'];
    
    const nestAdmin = await ethers.getSigner("0x04C1279F1121713e0267fc698Dc9AF9d299C51CB");
    const nestAddress = "0xd3f07EA86DDf7BAebEfd49731D7Bbd207FedC53B";
    const nestSigner = await ethers.getSigner(nestAddress);
    let tokenHolders = await impersonateAccounts(tokenHolderAddresses,nestSigner,nestAdmin);
    await setEthBalances(tokenHolders,nestAddress);

    //Deploy contract
    var swapperFactory = await ethers.getContractFactory("swapper");
    var swapperContract = await swapperFactory.connect(nestAdmin).deploy(nestAddress);
    await swapperContract.deployTransaction.wait();

    //Unlend ETH
    const LendingManagerContract = await ethers.getContractAt("LendingManager","0x3f323a6E3Bddff52529fA9ac94CFCc6E755A0242");
    transaction = await LendingManagerContract.connect(nestAdmin).unlend("0x28424507fefb6f7f8E9D3860F56504E4e5f5f390", ethers.utils.parseEther("100000000000"));
    await transaction.wait();
    
    await transferTokensToSwapper(outTokens,tokenHolders,nestAddress);
    await approveTokenTransfers(inTokens,nestSigner,swapperContract);

    //Configure swapper
    var transaction = await swapperContract.setInToken(inTokens);
    await transaction.wait();
    //crv bal aave uni sushi
    transaction = await swapperContract.setOutToken(outTokens);
    await transaction.wait();

    //Pause trading
    const nestBasketContract = await ethers.getContractAt("BasketFacet",nestAddress);
    transaction = await nestBasketContract.connect(nestAdmin).setLock(0);
    await transaction.wait();

    //Send needed tokens to Nest
    const nestCallContract = await ethers.getContractAt("CallFacet",nestAddress);
    transaction = await nestCallContract.connect(nestAdmin).addCaller(swapperContract.address);
    await transaction.wait();
    //Make swap
    /*let ABI = [
        "function swapTokenForToken()"
    ];
    let iface = new ethers.utils.Interface(ABI);
    let calldata = iface.encodeFunctionData("swapTokenForToken",);*/
    transaction = await swapperContract.connect(nestAdmin).swapTokenForToken();
    await transaction.wait();

    //Log resulting balances
    await logAllTokenBalances(outTokens,inTokens,swapperContract,nestAddress,false);

    //unlock Nest
    transaction = await nestBasketContract.connect(nestAdmin).setLock(1);
    await transaction.wait();

    //Log resulting balances
    await logAllTokenBalances(outTokens,inTokens,swapperContract,nestAddress,true);

    //Remove tokens from nest
    await removeTokens(nestBasketContract,inTokens,nestAdmin);
    console.log("tokensRemoved");

    //Deploy Recipe
    var recipeFactory = await ethers.getContractFactory("V1CompatibleRecipe");
    var recipeContract = await recipeFactory.connect(nestAdmin).deploy("0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619",
        "0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506",
        "0xc94BC5C62C53E88d67C3874f5E8f91c6a99656ca",
        "0x51E2F57C346e189c5a41e785d1563f93CCb8FaA1",
        "0x0319000133d3AdA02600f0875d2cf03D442C3367",
        "0xb527c5295c4bc348cbb3a2e96b2494fd292075a7");
    await recipeContract.deployTransaction.wait();  

    //Mint Nest 
    const wethSigner = await ethers.getSigner("0x853ee4b2a13f8a742d64c8f088be7ba2131f670d");
    let wethContract = await ethers.getContractAt("contracts/Interfaces/IERC20.sol:IERC20","0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619");
    transaction = await wethContract.connect((await ethers.getSigners())[0]).approve(recipeContract.address, ethers.utils.parseEther("10000.0"));
    await transaction.wait();
    transaction = await wethContract.connect(wethSigner).transfer(((await ethers.getSigners())[0]).address, (await wethContract.balanceOf(wethSigner.address)));
    await transaction.wait();
    var encoder = new ethers.utils.AbiCoder;
    var byteData = encoder.encode(["uint"], [ethers.utils.parseEther("0.1")]);
    transaction = await recipeContract.connect((await ethers.getSigners())[0]).bake("0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619",
        nestAddress,
        ethers.utils.parseEther("100"),
        byteData);
    await transaction.wait();
    
    //Log resulting balances
    await logAllTokenBalances(outTokens,inTokens,swapperContract,nestAddress,true);
}

async function logAllTokenBalances(outTokens,inTokens,swapperContract,nestAddress,user){
    if(user){
        const user = (await ethers.getSigners())[0];
        let tokenContract = await ethers.getContractAt("contracts/Interfaces/IERC20.sol:IERC20",nestAddress);
        console.log("User Balances: ",(await tokenContract.balanceOf(user.address)).toString());
        return;   
    }
    for (let i = 0; i < outTokens.length; i++) {
        let tokenContract = await ethers.getContractAt("contracts/Interfaces/IERC20.sol:IERC20",outTokens[i]);
        console.log("Should Be Number: ",(await tokenContract.balanceOf(nestAddress)).toString());
        console.log("Should Be 0: ",(await tokenContract.balanceOf(swapperContract.address)).toString());
    }
    for (let i = 0; i < inTokens.length; i++) {
        let tokenContract = await ethers.getContractAt("contracts/Interfaces/IERC20.sol:IERC20",inTokens[i]);
        console.log("Should Be Number: ",(await tokenContract.balanceOf(swapperContract.address)).toString());
        console.log("Should Be 0: ",(await tokenContract.balanceOf(nestAddress)).toString());
    }
}

async function removeTokens(nestBasketContract,inTokens,nestAdmin){
    for (let i = 0; i < inTokens.length; i++) {
        transaction = await nestBasketContract.connect(nestAdmin).removeToken(inTokens[i]);
        await transaction.wait();
    }
}

async function addTokens(nestBasketContract,outTokens){
    for (let i = 0; i < outTokens.length; i++) {
        transaction = await nestBasketContract.addToken(outTokens[i]);
        await transaction.wait();
    }
}

async function transferTokensToSwapper(tokens,holders,nestAddress){
    for (let i = 0; i < tokens.length; i++) {
        let tokenContract = await ethers.getContractAt("contracts/Interfaces/IERC20.sol:IERC20",tokens[i]);
        let transaction = await tokenContract.connect(holders[i]).transfer(nestAddress, (await tokenContract.balanceOf(holders[i].address)));
        await transaction.wait();
    }
}

async function setEthBalances(tokenHolders,nestAddress){
    for (let i = 0; i < tokenHolders.length; i++) {
        await network.provider.send("hardhat_setBalance", [
            tokenHolders[i].address,
            //30b Eth
            "0x9B18AB5DF7180B6B8000000",
        ]);
    }

    //Nest Contract
    await network.provider.send("hardhat_setBalance", [
        nestAddress,
        //30b Eth
        "0x9B18AB5DF7180B6B8000000",
    ]);

    //Admin
    await network.provider.send("hardhat_setBalance", [
        "0x04C1279F1121713e0267fc698Dc9AF9d299C51CB",
        //30b Eth
        "0x9B18AB5DF7180B6B8000000",
    ]);

    //Weth spender
    await network.provider.send("hardhat_setBalance", [
        "0x853ee4b2a13f8a742d64c8f088be7ba2131f670d",
        //30b Eth
        "0x9B18AB5DF7180B6B8000000",
    ]);
}

async function impersonateAccounts(tokenHolderAddresses,nestSigner,nestAdmin){
    var tokenHolders = [];
    for (let i = 0; i < tokenHolderAddresses.length; i++) {
        await hre.network.provider.request({
            method: "hardhat_impersonateAccount",
            params: [tokenHolderAddresses[i]],
        });
        tokenHolders.push((await ethers.getSigner(tokenHolderAddresses[i])));
    }
    await hre.network.provider.request({
        method: "hardhat_impersonateAccount",
        params: [nestAdmin.address],
    });
    await hre.network.provider.request({
        method: "hardhat_impersonateAccount",
        params: [nestSigner.address],
    });
    await hre.network.provider.request({
        method: "hardhat_impersonateAccount",
        params: ["0x853ee4b2a13f8a742d64c8f088be7ba2131f670d"],
    });
    return(tokenHolders);
}

async function approveTokenTransfers(tokens,nestSigner,swapperContract){
    for (let i = 0; i < tokens.length; i++) {
        let tokenContract = await ethers.getContractAt("contracts/Interfaces/IERC20.sol:IERC20",tokens[i]);
        let transaction = await tokenContract.connect(nestSigner).approve(swapperContract.address, (await tokenContract.balanceOf(nestSigner.address)));
        await transaction.wait();
    }
}
  
main()
.then(() => process.exit(0))
.catch((error) => {
    console.error(error);
    process.exit(1);
});
