const {
  DefenderRelaySigner,
  DefenderRelayProvider,
} = require("defender-relay-client/lib/ethers");
const ethers = require("ethers");
const axios = require("axios");
const REGISTRY_ABI = [
  {
    inputs: [{ internalType: "address", name: "_user", type: "address" }],
    name: "getStakingInfoForUser",
    outputs: [
      {
        components: [
          { internalType: "string", name: "name", type: "string" },
          { internalType: "string", name: "symbol", type: "string" },
          { internalType: "address", name: "stakingAddress", type: "address" },
          { internalType: "address", name: "rewardAddress", type: "address" },
        ],
        internalType: "struct IRareStakingRegistry.Info",
        name: "",
        type: "tuple",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
];
const RARITY_POOL_ABI = [
  {
    inputs: [
      { internalType: "address", name: "_donor", type: "address" },
      { internalType: "uint256", name: "_amount", type: "uint256" },
    ],
    name: "addRewards",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
];

let cmcApiKey = null;

exports.handler = async function (payload) {
  const { registryAddress } = payload.secrets;
  cmcApiKey = payload.secrets.cmcApiKey;
  const conditionRequest = payload.request.body;
  const matches = [];
  const events = conditionRequest.events;
  const provider = new DefenderRelayProvider(payload);
  const signer = new DefenderRelaySigner(payload, provider);
  for (const evt of events) {
    const sellerAndAmount = getSellerAndAmountFromMatchReasons(
      evt.matchReasons
    );
    if (!sellerAndAmount) throw new Error("Could not get seller and amount");
    const { seller, amount } = sellerAndAmount;
    const registry = new ethers.Contract(registryAddress, REGISTRY_ABI, signer);
    const res = await registry.getStakingInfoForUser(seller);
    if (!res.stakingAddress) throw new Error("Could not get staking address");
    const { stakingAddress } = res;
    if (stakingAddress === ethers.constants.AddressZero) {
      matches.push({
        hash: evt.hash,
        metadata: {
          id: `rarity-pool-${evt.hash}`,
          timestamp: new Date().getTime(),
          status: "skipped because no pool",
        },
      });
    }
    const pool = new ethers.Contract(stakingAddress, RARITY_POOL_ABI, signer);
    const signerAddress = await signer.getAddress();
    const amountBN = ethers.BigNumber.from(amount).div(100);
    const ethRarePrice = await getEthRarePrice();
    const amountRareToSend = amountBN.div(ethRarePrice);
    try {
      await pool.addRewards(signerAddress, amountRareToSend);
    } catch {
      throw new Error(`Could not add rewards to pool: ${
        JSON.stringify({
          signerAddress,
          amountRareToSend: amountRareToSend.toString(),
          stakingAddress,
          seller,
          amountBN: amountBN.toString(),
          rareEthPrice: rareEthPrice.toString(),
        }, null, 2)
      }`);
    }
    matches.push({
      hash: evt.hash,
      metadata: {
        id: `rarity-pool-${evt.hash}`,
        timestamp: new Date().getTime(),
        amountRareToSend,
        seller,
        status: "success",
      },
    });
  }
  return { matches, body: payload.request.body };
};

async function getEthRarePrice() {
  if (cmcApiKey === null) throw new Error("CMC API key not set");
  const ETH_CMC_ID = 1027;
  const RARE_CMC_ID = 11294;
  const uri = `https://pro-api.coinmarketcap.com/v2/cryptocurrency/quotes/latest?id=${RARE_CMC_ID}&convert_id=${ETH_CMC_ID}`;
  const res = await axios.get(uri, {
    headers: {
      "X-CMC_PRO_API_KEY": cmcApiKey,
    },
  });
  const ethPerRare =
    res.data.data[RARE_CMC_ID].quote[ETH_CMC_ID].price.toString();
  const parsedAndPadded = ethers.utils.parseUnits(ethPerRare, 25)
  const ethPerRareBN = parsedAndPadded.div(ethers.BigNumber.from(10).pow(7));
  return ethPerRareBN;
}

function getSellerAndAmountFromMatchReasons(mrs) {
  const sellerAndAmounts = mrs
    .map((mr) => {
      if (!mr.params._seller || !mr.params._amount) return null;
      const seller = mr.params._seller;
      const amount = mr.params._amount;
      return { amount, seller };
    })
    .filter((v) => !!v);
  if (sellerAndAmounts.length === 0) return null;
  return sellerAndAmounts[0];
}
