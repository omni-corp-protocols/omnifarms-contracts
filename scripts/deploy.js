
const hre = require("hardhat");
const jsonfile = require('jsonfile')

const outputFilePath = `./deployments/${hre.network.name}.json`;

async function main() {
  
  const FarmFactory = await hre.ethers.getContractFactory("FarmFactory");
  const factory = await FarmFactory.deploy();
  await factory.deployed();

  console.log("FarmFactory deployed to:", factory.address);
  saveAddress('FarmFactory', factory.address);

  const FarmGenerator01 = await hre.ethers.getContractFactory("FarmGenerator01");
  const farmGenerator = await FarmGenerator01.deploy(factory.address);
  await farmGenerator.deployed();

  console.log("FarmGenerator01 deployed to:", farmGenerator.address);
  saveAddress('FarmGenerator01', farmGenerator.address);

  // register farm generator
  const tx = await factory.adminAllowFarmGenerator(farmGenerator.address, true);
  console.log(`Farm genarator registered in txn: ${tx.hash}`)
  await tx.wait();
}

const saveAddress = (contractName, contractAddress) => {
  let newData = { ...jsonfile.readFileSync(outputFilePath) };

  newData[contractName] = contractAddress;
  jsonfile.writeFileSync(outputFilePath, newData, { spaces: 2 });
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
