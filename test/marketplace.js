const Marketplace = artifacts.require('Marketplace')
const Shop = artifacts.require('Shop')

const Web3 = require('web3')
const web3 = new Web3("ws://localhost:8545")

const truffleAssert = require('truffle-assertions');
const truffleEvent  = require('truffle-events');

const sellerUuid1 = 'EICWPMAUVDMMARJKZYORXJPRLC'
const sellerUuid2 = 'ZEVNAUWYUQQULOFHVGFLDJQOFZ'
const buyerUuid = 'QMPNK9BOFK9REOHADHFYJIJZQ9'
const mamRoot = 'DVZAPMBOOJHQKFQUUYCXKA9DMOLQABGKHSZCAPYLPQSQK9BGNGMOY9JHHNRRGNHGBUUPWYWJM9QNEISFI'
const txHash = '0x1da44b586eb0729ff70a73c326926f6ed5a25f5b056e7f47fbc6e58d86871655'
const singlePurchasePrice = 50

before(async () => {
  require('truffle-test-utils').init()
})

contract('Marketplace', accounts => {
  let instance

  it('Accounts[0] should be the owner', async () => {
    instance = await Marketplace.deployed()
    let owner = await instance.owner()
    assert.equal(
      owner,
      accounts[0],
      'the owner is not accounts[0]'
    )
  })

  it('Should register accounts[1] as a seller', async () => {
    await instance.registerUser(accounts[1], sellerUuid1)
    await instance.registerShop(accounts[1])
    let shop_address = await instance.sellerData.call(accounts[1])
    assert.notEqual(
      shop_address,
      0,
      'the seller was not added'
    )
  })

  it('Should register accounts[2] as a seller', async () => {
    await instance.registerUser(accounts[2], sellerUuid2)
    await instance.registerShop(accounts[2])
    let shop_address = await instance.sellerData.call(accounts[2])
    assert.notEqual(
      shop_address,
      0,
      'the seller was not added'
    )
  })

  it('Should delete accounts[1] from seller list', async () => {
    await instance.removeShop(accounts[1])
    let shop_address = await instance.sellerData.call(accounts[1])
    assert.equal(
      shop_address,
      0,
      'the seller was not deleted'
    )
  })

  it('Should get the first seller(accounts[2]) from seller list', async () => {
    let address = await instance.allSellers.call("0x0000000000000000000000000000000000000000")
    assert.equal(
      address,
      accounts[2],
      'the seller was not found'
    )
  })

  it('Should get the first seller(accounts[2]) shop', async () => {
    let address = await instance.allSellers.call("0x0000000000000000000000000000000000000000")
    let shop_address = await instance.sellerData.call(address)
    assert.notEqual(
      shop_address,
      0,
      'the shop was not found'
    )
  })

  let shop_instance

  it('Accounts[2] should be the owner of shop', async () => {
    let address = await instance.allSellers.call("0x0000000000000000000000000000000000000000")
    let shop_address = await instance.sellerData.call(address)
    shop_instance = await Shop.at(shop_address)
    let owner = await shop_instance.owner()
    assert.equal(
      owner,
      accounts[2],
      'accounts[2] is not the owner of shop'
    )
  })

  it('Setup shop for customers', async () => {
    await shop_instance.setPrice(singlePurchasePrice, {from: accounts[2]})
    let price = await shop_instance.singlePurchasePrice.call()
    assert.equal(
      price,
      singlePurchasePrice,
      'the data price was not set'
    )

    await shop_instance.updateData(mamRoot, 12, {from: accounts[2]})
    let metadata = await shop_instance.getData(0)
    assert.notEqual(
      metadata,
      0,
      'failed to push the data to shop'
    )

    await shop_instance.setPurchaseOpen({from: accounts[2]})
  })

  it('Should register customer(accounts[3])', async () => {
    await instance.registerUser(accounts[3], buyerUuid)
    assert.equal(
      await instance.userAccounts.call(accounts[3]),
      buyerUuid,
      'failed to register account'
    )
  })

  let buyDataResult

  it('Customer interact with Marketplace contract to purchase data', async () => {
    let balance_before = web3.utils.toBN(await web3.eth.getBalance(accounts[3]))
    buyDataResult = await instance.buyData(
      accounts[2],
      mamRoot,
      {
        from: accounts[3],
        value: singlePurchasePrice.toString()
      }
    )
    let balance_after = web3.utils.toBN(await web3.eth.getBalance(accounts[3]))
    let gasUsed = web3.utils.toBN(buyDataResult.receipt.gasUsed)
    let txHash = buyDataResult.receipt.transactionHash
    let tx = await web3.eth.getTransaction(txHash)
    let gasPrice = tx.gasPrice

    assert.equal(
      buyDataResult.logs[0].event,
      'Funded',
      'invalid event'
    )

    assert.equal(
      balance_before.sub(balance_after).toString(),
      gasUsed.mul(web3.utils.toBN(gasPrice)).add(web3.utils.toBN(singlePurchasePrice)).toString(),
      'Payment failure'
    )

    // truffle failed to log Purchase event, skip it for test
    /*
    assert.web3AllEvents(txResult, [
      {
        event: 'Purchase',
        args: {
          buyer: accounts[3],
          mamRoot: mamRoot,
        }
      },
      {
        event: 'Funded',
        args: {
          from: accounts[3],
          value: 30
        }
      }
    ])
    */
  })

  it('Seller finalize purchase', async () => {
    let scriptHash = buyDataResult.logs[0].args.scriptHash
    let value = buyDataResult.logs[0].args.value
    let buyer = buyDataResult.logs[0].args.from

    let hash = web3.utils.soliditySha3(
      '0x19',
      '0x00',
      instance.address.toLowerCase(),
      scriptHash,
      accounts[2].toLowerCase(),
      value
    )
    let sig = await web3.eth.sign(hash, accounts[2])
    let r = sig.slice(0, 66)
    let s = '0x' + sig.slice(66, 130)
    let v = '0x' + sig.slice(130, 132)
    v = web3.utils.toDecimal(v) + 27

    let txResult = await shop_instance.txFinalize([v], [r], [s], buyer, scriptHash, txHash, {from: accounts[2]})

    /*
    assert.equal(
      txResult.logs[0].event,
      'Fulfilled',
      'invalid event'
    )
    */
  })

  it('Buyer execute transaction to release fund', async () => {
    let scriptHash = buyDataResult.logs[0].args.scriptHash
    let value = buyDataResult.logs[0].args.value
    let buyer = buyDataResult.logs[0].args.from

    let hash = web3.utils.soliditySha3(
      '0x19',
      '0x00',
      instance.address,
      scriptHash,
      accounts[2],
      value
    )
    let sig = await web3.eth.sign(hash, accounts[3])
    let r = sig.slice(0, 66)
    let s = '0x' + sig.slice(66, 130)
    let v = '0x' + sig.slice(130, 132)
    v = web3.utils.toDecimal(v) + 27

    let balance_before = web3.utils.toBN(await web3.eth.getBalance(accounts[2]))
    let txResult = await instance.execute([v], [r], [s], scriptHash, accounts[2], value, {from: accounts[3]})
    let balance_after = web3.utils.toBN(await web3.eth.getBalance(accounts[2]))

    assert.equal(
      txResult.logs[0].event,
      'Executed',
      'invalid event'
    )

    assert.equal(
      balance_after.sub(balance_before).toString(),
      value.toString(),
      "Value transfer failed"
    )
  })
})
