const web3 = require('web3')
const Marketplace = artifacts.require('Marketplace')
const Shop = artifacts.require('Shop')

contract('Marketplace', accounts => {
  it('accounts[0] should be the owner', async () => {
    let instance = await Marketplace.deployed()
    let owner = await instance.owner()
    assert.equal(
      owner,
      accounts[0],
      'the owner is not accounts[0]'
    )
  })

  it('should add accounts[1] as a seller', async () => {
    let instance = await Marketplace.deployed()
    await instance.addSeller(accounts[1])
    let shop_address = await instance.sellerData.call(accounts[1])
    assert.notEqual(
      shop_address,
      0,
      'the seller was not added'
    )
  })

  it('should add accounts[2] as a seller', async () => {
    let instance = await Marketplace.deployed()
    await instance.addSeller(accounts[2])
    let shop_address = await instance.sellerData.call(accounts[2])
    assert.notEqual(
      shop_address,
      0,
      'the seller was not added'
    )
  })

  it('should delete accounts[1] from seller list', async () => {
    let instance = await Marketplace.deployed()
    await instance.rmSeller(accounts[1])
    let shop_address = await instance.sellerData.call(accounts[1])
    assert.equal(
      shop_address,
      0,
      'the seller was not deleted'
    )
  })

  it('should get the first seller(accounts[2]) from seller list', async () => {
    let instance = await Marketplace.deployed()
    let address = await instance.allSellers.call("0x0000000000000000000000000000000000000000")
    assert.equal(
      address,
      accounts[2],
      'the seller was not found'
    )
  })

  it('should get the first seller(accounts[2]) shop', async () => {
    let instance = await Marketplace.deployed()
    let address = await instance.allSellers.call("0x0000000000000000000000000000000000000000")
    let shop_address = await instance.sellerData.call(address)
    assert.notEqual(
      shop_address,
      0,
      'the shop was not found'
    )
  })

  let shop_instance

  it('accounts[2] should be the owner of shop', async () => {
    let instance = await Marketplace.deployed()
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

  it('should set the data price to 30wei', async () => {
    await shop_instance.setPrice(30, {from: accounts[2]})
    let price = await shop_instance.singlePurchacePrice.call()
    assert.equal(
      price,
      30,
      'the data price was not set'
    )
  })

  it('should push MAM metadata onto datalist', async () => {
    let mamRoot = 'A'.repeat(81)
    await shop_instance.updateData(mamRoot, 12, {from: accounts[2]})
    let metadata = await shop_instance.getData(0)
    assert.notEqual(
      metadata,
      0,
      'failed to push the data to shop'
    )
  })

  it('should register customer(accounts[3]) to a uuid', async () => {
    let instance = await Marketplace.deployed()
    let uuid = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    await instance.register(accounts[3], uuid)
    assert.equal(
      await instance.userid.call(accounts[3]),
      uuid,
      'failed to register account'
    )
  })

  it('customer interact with Marketplace contract to buy data', async () => {
    let instance = await Marketplace.deployed()
    let address = await instance.allSellers.call("0x0000000000000000000000000000000000000000")
    let shop_address = await instance.sellerData.call(address)
    let mamRoot = 'A'.repeat(81)
    await instance.buyData(accounts[2], mamRoot, {from: accounts[3], value: web3.utils.toWei('30', 'wei')})
  })
})
