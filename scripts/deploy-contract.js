const { ethers } = require('hardhat');

async function main() {
  const AssessmentToken = await ethers.getContractFactory('AssessmentToken');
  const token = await AssessmentToken.deploy(1000000);
  await token.waitForDeployment();

  console.log('AssessmentToken deployed to:', await token.getAddress());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
