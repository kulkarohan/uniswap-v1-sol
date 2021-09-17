import chai, { expect } from 'chai'
import asPromised from 'chai-as-promised'
import { ethers } from 'hardhat'
import { Signer } from 'ethers'
import { Exchange, ExchangeFactory, Factory, Token } from '../typechain'

chai.use(asPromised)

const FIVE_ETH = ethers.utils.parseEther('5')
const FIVE_TOKENS = ethers.utils.parseUnits('5')

describe('Uniswap v1', () => {
    let deployer: Signer
    let seller: Signer
    let buyer: Signer

    let token: Token
    let factory: Factory
    let exchangeTemplate: Exchange
    let exchange: Exchange

    beforeEach(async () => {
        const signers = await ethers.getSigners()
        deployer = signers[0]
        seller = signers[1]
        buyer = signers[2]

        // Deploy $ROHAN ERC20 contract
        const Token = await ethers.getContractFactory('Token')
        token = (await Token.deploy()) as Token
        await token.deployed()

        // Mint 5 $ROHAN to seller
        await token.mint(await seller.getAddress(), FIVE_TOKENS)

        // Deploy Uniswap Exchange template
        const ExchangeTemplate = await ethers.getContractFactory('Exchange')
        exchangeTemplate = (await ExchangeTemplate.deploy()) as Exchange
        await exchangeTemplate.deployed()

        // Deploy Uniswap Exchange Factory
        const Factory = await ethers.getContractFactory('Factory')
        factory = (await Factory.deploy()) as Factory
        await factory.deployed()
    })

    describe('Factory', () => {
        it('should create a ETH-$ROHAN exchange', async () => {
            await factory.connect(seller).createExchange(token.address)

            const tokenCount = await factory.tokenCount()
            expect(tokenCount.toNumber()).to.eq(1)
        })
        it('should connect to the ETH-$ROHAN exchange', async () => {
            await factory.connect(seller).createExchange(token.address)

            const address = await factory.getExchange(token.address)
            // Connect to exchange proxy instance
            exchange = new ExchangeFactory(seller).attach(address)

            expect(exchange.address).to.eq(address)
        })
    })

    describe('Exchange', () => {
        beforeEach(async () => {
            await factory.connect(seller).createExchange(token.address)

            const exchangeAddress = await factory.getExchange(token.address)
            exchange = new ExchangeFactory(seller).attach(exchangeAddress)

            // Approve transfer of 5 $ROHAN to exchange
            await token.connect(seller).approve(exchange.address, FIVE_TOKENS)
        })

        it('should add liquidity of 5 $ROHAN', async () => {
            await exchange
                .connect(seller)
                .addLiquidity(0, FIVE_TOKENS, 1632752757, { value: FIVE_ETH })

            const supply = await exchange.totalSupply()
            expect(supply.toBigInt()).to.eq(FIVE_TOKENS.toBigInt())

            const balance = await token.balanceOf(exchange.address)
            expect(balance.toBigInt()).to.eq(FIVE_TOKENS.toBigInt())
        })

        it('should remove liquidity of 5 $ROHAN', async () => {
            await exchange
                .connect(seller)
                .addLiquidity(0, FIVE_TOKENS, 1632752757, { value: FIVE_ETH })
            const balanceAfterAdd = await token.balanceOf(exchange.address)
            expect(balanceAfterAdd.toBigInt()).to.eq(FIVE_TOKENS.toBigInt())

            await exchange
                .connect(seller)
                .removeLiquidity(FIVE_TOKENS, FIVE_TOKENS, FIVE_TOKENS, 1632752757)

            const balanceAfterRemove = await token.balanceOf(exchange.address)
            expect(balanceAfterRemove.toBigInt()).to.eq(BigInt(0))
        })
    })
})
