const { ethers } = require("hardhat");
const { Contract } = require("hardhat/internal/hardhat-network/stack-traces/model");

//Chainlink Price Feeds
const priceFeeds = new Map([
    ["0x28424507fefb6f7f8E9D3860F56504E4e5f5f390", "0x5f4ec3df9cbd43714fe2740f5e3616155c5b8419"], //ETH //USD
    ["0xDA537104D6A5edd53c6fBba9A898708E465260b6", "0xa027702dbb89fbd58938e4324ac03b58d812b0e1"], //YFI //USD 
    ["0x4257EA7637c355F81616050CbB6a9b709fd72683", "0xd962fc30a72a84ce50161031391756bf2876af5d"], //CVX // USD
    ["0x3AE490db48d74B1bC626400135d4616377D0109f", "0x89c7926c7c15fd5bfdb1edcff7e7fc8283b578f6"], //ALPHA // ETH
    ["0xb33EaAd8d922B1083446DC23f610c2567fB5180f", "0x553303d460ee0afb37edff9be42922d8ff63220e"], //UNI //USD
    ["0x0b3F868E0BE5597D5DB7fEB59E1CADBb0fdDa50a", "0xcc70f09a6cc17553b2e31954cd36e4a2d89501f7"], //SUSHI //USD
    ["0x172370d5Cd63279eFa6d502DAB29171933a610AF", "0xcd627aa160a6fa45eb793d19ef54f5062f20f33f"], //CRV //USD
    ["0x9a71012B13CA4d3D0Cdc72A177DF3ef03b0E76A3", "0xdf2917806e30300537aeb49a7663062f4d1f2b5f"], //BAL //USD
    ["0x8505b9d2254A7Ae468c0E9dd10Ccea3A837aef5c", "0xdbd020caef83efd542f4de03e3cf0c28a4428bd5"], //COMP //USD
    ["0x6f7C932e7684666C9fd1d44527765433e01fF61d", "0xec1d1b3b0443256cc3860e24a46f108e699484aa"], //MKR //USD
    ["0x95c300e7740D2A88a44124B424bFC1cB2F9c3b89", "0x194a9aaf2e0b67c35915cd01101585a33fe25caa"], //ALCX // ETH
    ["0x53E0bca35eC356BD5ddDFebbD1Fc0fD03FaBad39", "0x2c1d072e956affc0d435cb7ac38ef18d24d9127c"], //LINK //USD
    ["0x50B728D8D964fd00C2d0AAD81718b71311feF68a", "0xdc3ea94cd0ac27d9a86c180091e7f78c683d3699"], //SNX //USD
    ["0x3066818837c5e6eD6601bd5a91B0762877A6B731", "0xf817b69ea583caff291e287cae00ea329d22765c"], //UMA //ETH
    ["0xD6DF932A45C0f255f85145f286eA0b292B21C90B", "0x547a514d5e3769680ce22b2361c10ea13619e8a9"], //AAVE //USD
    ["0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270", "0x7bac85a8a13a4bcd8abb3eb7d6b4d632c5a57676"], //MATIC //USD
  ]);
//Chainlink Addresses
const ethAddress = "0x5f4ec3df9cbd43714fe2740f5e3616155c5b8419";
const yfiAddress = "0xa027702dbb89fbd58938e4324ac03b58d812b0e1";
const cvxAddress = "0xd962fc30a72a84ce50161031391756bf2876af5d";
const alphaAddress = "0x89c7926c7c15fd5bfdb1edcff7e7fc8283b578f6"; //ETH
const uniAddress = "0x553303d460ee0afb37edff9be42922d8ff63220e";
const sushiAddress = "0xcc70f09a6cc17553b2e31954cd36e4a2d89501f7";
const crvAddress = "0xcd627aa160a6fa45eb793d19ef54f5062f20f33f";
const balAddress = "0xdf2917806e30300537aeb49a7663062f4d1f2b5f";
const compAddress = "0xdbd020caef83efd542f4de03e3cf0c28a4428bd5";
const mkrAddress = "0xec1d1b3b0443256cc3860e24a46f108e699484aa";
const alcxAddress = "0x194a9aaf2e0b67c35915cd01101585a33fe25caa"; //ETH
const linkAddress = "0x2c1d072e956affc0d435cb7ac38ef18d24d9127c";
const snxAddress = "0xdc3ea94cd0ac27d9a86c180091e7f78c683d3699";
const umaAddress = "0xf817b69ea583caff291e287cae00ea329d22765c"; // ETH
const aaveAddress = "0x547a514d5e3769680ce22b2361c10ea13619e8a9";
const maticAddress = "0x7bac85a8a13a4bcd8abb3eb7d6b4d632c5a57676";
//const baoAddress = NA

//New nDEFi nest composition
const aaveShare = ethers.utils.parseEther("0.3655"); //36,55%
const balShare = ethers.utils.parseEther("0.1796");
const sushiShare = ethers.utils.parseEther("0.2810");
const crvShare = ethers.utils.parseEther("0.1214");
const uniShare = ethers.utils.parseEther("0.0524");

//Current Token values that we want to keep


const nestAddress = "0xd3f07EA86DDf7BAebEfd49731D7Bbd207FedC53B";

const linkABI = [
    {"inputs":[{"internalType":"address","name":"_aggregator","type":"address"},{"internalType":"address","name":"_accessController","type":"address"}],"stateMutability":"nonpayable","type":"constructor"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"int256","name":"current","type":"int256"},{"indexed":true,"internalType":"uint256","name":"roundId","type":"uint256"},{"indexed":false,"internalType":"uint256","name":"updatedAt","type":"uint256"}],"name":"AnswerUpdated","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"uint256","name":"roundId","type":"uint256"},{"indexed":true,"internalType":"address","name":"startedBy","type":"address"},{"indexed":false,"internalType":"uint256","name":"startedAt","type":"uint256"}],"name":"NewRound","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"from","type":"address"},{"indexed":true,"internalType":"address","name":"to","type":"address"}],"name":"OwnershipTransferRequested","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"from","type":"address"},{"indexed":true,"internalType":"address","name":"to","type":"address"}],"name":"OwnershipTransferred","type":"event"},{"inputs":[],"name":"acceptOwnership","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[],"name":"accessController","outputs":[{"internalType":"contract AccessControllerInterface","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"aggregator","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"_aggregator","type":"address"}],"name":"confirmAggregator","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[],"name":"decimals","outputs":[{"internalType":"uint8","name":"","type":"uint8"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"description","outputs":[{"internalType":"string","name":"","type":"string"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"uint256","name":"_roundId","type":"uint256"}],"name":"getAnswer","outputs":[{"internalType":"int256","name":"","type":"int256"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"uint80","name":"_roundId","type":"uint80"}],"name":"getRoundData","outputs":[{"internalType":"uint80","name":"roundId","type":"uint80"},{"internalType":"int256","name":"answer","type":"int256"},{"internalType":"uint256","name":"startedAt","type":"uint256"},{"internalType":"uint256","name":"updatedAt","type":"uint256"},{"internalType":"uint80","name":"answeredInRound","type":"uint80"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"uint256","name":"_roundId","type":"uint256"}],"name":"getTimestamp","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"latestAnswer","outputs":[{"internalType":"int256","name":"","type":"int256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"latestRound","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"latestRoundData","outputs":[{"internalType":"uint80","name":"roundId","type":"uint80"},{"internalType":"int256","name":"answer","type":"int256"},{"internalType":"uint256","name":"startedAt","type":"uint256"},{"internalType":"uint256","name":"updatedAt","type":"uint256"},{"internalType":"uint80","name":"answeredInRound","type":"uint80"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"latestTimestamp","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"owner","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"uint16","name":"","type":"uint16"}],"name":"phaseAggregators","outputs":[{"internalType":"contract AggregatorV2V3Interface","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"phaseId","outputs":[{"internalType":"uint16","name":"","type":"uint16"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"_aggregator","type":"address"}],"name":"proposeAggregator","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[],"name":"proposedAggregator","outputs":[{"internalType":"contract AggregatorV2V3Interface","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"uint80","name":"_roundId","type":"uint80"}],"name":"proposedGetRoundData","outputs":[{"internalType":"uint80","name":"roundId","type":"uint80"},{"internalType":"int256","name":"answer","type":"int256"},{"internalType":"uint256","name":"startedAt","type":"uint256"},{"internalType":"uint256","name":"updatedAt","type":"uint256"},{"internalType":"uint80","name":"answeredInRound","type":"uint80"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"proposedLatestRoundData","outputs":[{"internalType":"uint80","name":"roundId","type":"uint80"},{"internalType":"int256","name":"answer","type":"int256"},{"internalType":"uint256","name":"startedAt","type":"uint256"},{"internalType":"uint256","name":"updatedAt","type":"uint256"},{"internalType":"uint80","name":"answeredInRound","type":"uint80"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"_accessController","type":"address"}],"name":"setController","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"_to","type":"address"}],"name":"transferOwnership","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[],"name":"version","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"}
]

var mainnetProvider = ethers.getDefaultProvider(); 
//var pollyProvider = ethers.getDefaultProvider(137); 


async function main() {

    //Value of tokens we have to replace
    var sum = await getTokenOutValue();
    
    var newAaveValue = (sum.mul(aaveShare).div(ethers.utils.parseEther("1"))).sub(aaveValue);
    var newUniValue = (sum.mul(uniShare).div(ethers.utils.parseEther("1"))).sub(uniValue);
    var newSushiValue = (sum.mul(sushiShare).div(ethers.utils.parseEther("1"))).sub(sushiValue);
    var newBalValue = (sum.mul(balShare).div(ethers.utils.parseEther("1"))).sub(balValue);
    var newCrvValue = (sum.mul(crvShare).div(ethers.utils.parseEther("1"))).sub(crvValue);
    //Value of tokens inside   
    console.log("AAVE value: ",newAaveValue.toString());
    console.log("Bal value: ",newBalValue.toString());
    console.log("Sushi value: ",newSushiValue.toString());
    console.log("Uni value: ",newUniValue.toString());
    console.log("Crv value: ",newCrvValue.toString());
    console.log("Sum: ", (newAaveValue.add(newUniValue).add(newSushiValue).add(newBalValue).add(newCrvValue)).toString());
    //await usdToTokens();

}

async function getTokenOutValue(){
    const nestBasketContract = await ethers.getContractAt("BasketFacet",nestAddress);
    const nestTokens = await nestBasketContract.getTokens();
    var sum = ethers.BigNumber.from("0");
    var stayingSum = ethers.BigNumber.from("0");

    var linkaddress = priceFeeds.get("0x28424507fefb6f7f8E9D3860F56504E4e5f5f390");
    var linkFeedContract = new ethers.Contract(linkaddress, linkABI, mainnetProvider);
    var ethPrice = await linkFeedContract.latestAnswer();

    for (let i = 0; i < nestTokens.length; i++) {
        if("0xc81278a52AD0e1485B7C3cDF79079220Ddd68b7D" == nestTokens[i].toString()){
            //Do nothing
        }else{
            linkaddress = priceFeeds.get( nestTokens[i].toString());
            linkFeedContract = new ethers.Contract(linkaddress, linkABI, mainnetProvider);
            const tokenContract = await ethers.getContractAt("contracts/Interfaces/IERC20.sol:IERC20", nestTokens[i]);
            const tokenAmount = await tokenContract.balanceOf(nestAddress);
            var tokenPrice = await linkFeedContract.latestAnswer();
            //Certain tokens only have an ETH feed, which we need to transform to USD
            if(nestTokens[i].toString() == "0x3AE490db48d74B1bC626400135d4616377D0109f" || nestTokens[i].toString() == "0x95c300e7740D2A88a44124B424bFC1cB2F9c3b89" || nestTokens[i].toString() == "0x3066818837c5e6eD6601bd5a91B0762877A6B731"){
                tokenPrice = ethPrice.mul(tokenPrice).div(ethers.utils.parseEther("1.0"));
            }
            //Save tokens that will stay seperately
            if(nestTokens[i].toString() == "0xb33EaAd8d922B1083446DC23f610c2567fB5180f"){
                uniValue = tokenAmount.mul(tokenPrice).div(ethers.utils.parseEther("1.0"));
                stayingSum = stayingSum.add(tokenAmount.mul(tokenPrice).div(ethers.utils.parseEther("1.0")));
            }
            if(nestTokens[i].toString() == "0x0b3F868E0BE5597D5DB7fEB59E1CADBb0fdDa50a"){
                sushiValue = tokenAmount.mul(tokenPrice).div(ethers.utils.parseEther("1.0"));
                stayingSum = stayingSum.add(tokenAmount.mul(tokenPrice).div(ethers.utils.parseEther("1.0")));
            }
            if(nestTokens[i].toString() == "0x172370d5Cd63279eFa6d502DAB29171933a610AF"){
                crvValue = tokenAmount.mul(tokenPrice).div(ethers.utils.parseEther("1.0"));
                stayingSum = stayingSum.add(tokenAmount.mul(tokenPrice).div(ethers.utils.parseEther("1.0")));
            }
            if(nestTokens[i].toString() == "0x9a71012B13CA4d3D0Cdc72A177DF3ef03b0E76A3"){
                balValue = tokenAmount.mul(tokenPrice).div(ethers.utils.parseEther("1.0"));
                stayingSum = stayingSum.add(tokenAmount.mul(tokenPrice).div(ethers.utils.parseEther("1.0")));
            }
            if(nestTokens[i].toString() == "0xD6DF932A45C0f255f85145f286eA0b292B21C90B"){
                aaveValue = tokenAmount.mul(tokenPrice).div(ethers.utils.parseEther("1.0"));
                stayingSum = stayingSum.add(tokenAmount.mul(tokenPrice).div(ethers.utils.parseEther("1.0")));
            }   
            //console.log(tokenAmount.mul(tokenPrice).div(ethers.utils.parseEther("1.0")).toString());
            sum = sum.add(tokenAmount.mul(tokenPrice).div(ethers.utils.parseEther("1.0")));
        }
    }
    console.log("Nest Value: ",sum.toString());
    console.log("Staying Value: ",stayingSum.toString());
    console.log("Removing Value: ",sum.sub(stayingSum).toString());
    return(sum);
}

async function usdToTokens(){

}

  
main()
.then(() => process.exit(0))
.catch((error) => {
    console.error(error);
    process.exit(1);
});
