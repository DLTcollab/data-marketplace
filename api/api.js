const Web3 = require('web3')
const fs = require('fs')
const compiledMarketplace = JSON.parse(fs.readFileSync('../build/contracts/Marketplace.json'), 'utf8')
const compiledShop = JSON.parse(fs.readFileSync('../build/contracts/Shop.json'), 'utf8')


const subscribeEvent = function(contract, event, _filter, eventHandler) {
  contract.events[event]({filter: _filter}, (err, res) => {
    eventHandler(res.returnValues);
  })
};

class Supervisor {
  constructor(provider, address, privateKey) {
    this.web3 = new Web3(provider)
    this.account = this.web3.eth.accounts.privateKeyToAccount(privateKey)
    this.address = this.account.address
    this.web3.eth.accounts.wallet.add(this.account)
    if (address) {
      this.marketplace = new this.web3.eth.Contract(compiledMarketplace.abi, address)
    }
  }

  async deploy() {
    if (this.marketplace) {
      throw new Error('Contract has been deployed')
    }
    let instance = new this.web3.eth.Contract(compiledMarketplace.abi)
    this.marketplace = await instance.deploy({
        data: compiledMarketplace.bytecode
      }).send({
        from: this.address,
        gas: 6000000
      })
  }

  async registerUser(user, uuid) {
    await this.marketplace.methods.registerUser(user, uuid).send({
      from: this.address,
      gas: 200000
    })
  }

  async registerShop(seller, info) {
    await this.marketplace.methods.registerShop(seller, info).send({
      from: this.address,
      gas: 2000000
    })
  }
}

class Customer {

  constructor(provider, contractAddress, privateKey) {
    this.web3        = new Web3(provider)
    this.account     = this.web3.eth.accounts.privateKeyToAccount(privateKey)
    this.address     = this.account.address
    this.marketplace = new this.web3.eth.Contract(compiledMarketplace.abi, contractAddress)

    this.web3.eth.accounts.wallet.add(this.account)
  }

  /* too slow ? */
  async getAllProviders() {
    let providers = []
    let zero = '0x0000000000000000000000000000000000000000'
    let next = await this.marketplace.methods.allSellers(zero).call()

    while (next !== zero) {
      let providerInfo = await this.marketplace.methods.sellerData(next).call()
      providers.push(providerInfo)
      next = await this.marketplace.methods.allSellers(next).call()
    }
    return providers
  }

  /* TODO: filter */
  async viewDataList(provider, filter = undefined) {
    let shop = new this.web3.eth.Contract(compiledShop.abi, provider)
    let size = await shop.methods.getDataListSize().call()
    let dataList = []
    for(let i = 0; i < size; ++i) {
      let data = await shop.methods.dataList(i).call()
      let valid = await shop.methods.getDataAvailability(data.mamRoot).call()
      if (valid)
        dataList.push({
          metadata: data.metadata,
          mamRoot: data.mamRoot
        })
    }
    return dataList
  }

  async purchaseData(provider, mamRoot, value) {
    if (typeof value !== 'string') {
      throw new Error('purchaseData(): value argument should be passed by string')
    }

    let scriptHash = await this.marketplace.methods
      .purchaseData(provider, mamRoot)
      .send({
        from: this.address,
        value: value,
        gas: 500000
      })

    subscribeEvent(
      this.marketplace,
      'Fulfilled',
      {
        scriptHash: scriptHash,
        to: this.address
      },
      (event) => {
        console.log(event.txHash)
      }
    )
  }

  async subscribeProvider(provider, time, value) {
    await this.marketplace.methods
      .subscribeShop(provider, time)
      .send({
        from: this.address,
        value: value,
        gas: 200000
      })
  }
}

class Seller {
  constructor(provider, address, privateKey) {
    this.web3    = new Web3(provider)
    this.account = this.web3.eth.accounts.privateKeyToAccount(privateKey)
    this.address = this.account.address

    this.web3.eth.accounts.wallet.add(this.account)
    this.marketplace = new this.web3.eth.Contract(compiledMarketplace.abi, address)
//    this.shop = new this.web3.eth.Contract(compiledShop.abi, contractAddress)
  }

  async init() {
    let shopInfo = await this.marketplace.methods.sellerData(this.address).call()
    this.shop = new this.web3.eth.Contract(compiledShop.abi, shopInfo.instance)
  }

  async setupShop(price) {
    await this.shop.methods.setPrice(price).send({
      from: this.address,
      gas: 200000
    })
    await this.shop.methods.setPurchaseOpen().send({
      from: this.address,
      gas: 200000
    })
  }

  async updateData(datalist) {
    for (const data of datalist) {
      await this.shop.methods.updateData(data.mamRoot, data.metadata).send({
        from: this.address,
        gas: 2000000
      })
    }
  }
}

module.exports = {
  Supervisor,
  Customer,
  Seller
}
