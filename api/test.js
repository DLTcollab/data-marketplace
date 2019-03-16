(async () => {
  const marketplace = require('./api.js')
  const Web3 = require('web3')
  const web3 = new Web3('')

  /* only for testing purpose */
  let privateKeys = [
    '0x0e9e7762d62b2e5d2f60682ec5888901f5a6f13b105828da69dedf1d46123179',
    '0xec8c6a4eb87f7847529ad4b2dea138c72c838fcf36ce2b6e17313ba2ed1be3ad',
    '0x90a79596b10d8ffcce2ac5744ef58546a3e0a8f65b2acb721b31a1ab34406013',
    '0x66fa4bd1503deba170abbce70586b7ead2b1f7052841010fe40112ca26ae7b53',
  ]
  let address = [
    web3.eth.accounts.privateKeyToAccount(privateKeys[0]).address,
    web3.eth.accounts.privateKeyToAccount(privateKeys[1]).address,
    web3.eth.accounts.privateKeyToAccount(privateKeys[2]).address,
    web3.eth.accounts.privateKeyToAccount(privateKeys[3]).address,
  ]

  let provider = 'ws://localhost:8545'

  let cnt = 0
  let supervisor = new marketplace.Supervisor(provider, null, privateKeys[0])
  await supervisor.deploy()
  let instance = supervisor.marketplace.options.address

  await supervisor.registerUser(address[1], 'A'.repeat(26))
  await supervisor.registerUser(address[2], 'B'.repeat(26))
  await supervisor.registerShop(address[2], 'some infomation')

  let seller = new marketplace.Seller(provider, instance, privateKeys[2])
  await seller.init()
  let datalist = [
    {
      mamRoot: 'A'.repeat(81),
      metadata: 'some metadata'
    },
    {
      mamRoot: 'B'.repeat(81),
      metadata: 'some metadata'
    }
  ]
  await seller.updateData(datalist)
  await seller.setupShop('30')

  let customer = new marketplace.Customer(provider, instance, privateKeys[1])
  let providers = await customer.getAllProviders()
  let dataList = await customer.viewDataList(providers[0].instance)
  await customer.purchaseData(providers[0].seller, dataList[0].mamRoot, '30')
})()
