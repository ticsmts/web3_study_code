import { BigInt, Bytes } from "@graphprotocol/graph-ts"
import {
    Listed as ListedEvent,
    Bought as BoughtEvent,
    PermitBought as PermitBoughtEvent
} from "../generated/ZZNFTMarketV3/ZZNFTMarketV3"
import { Listing, Sale } from "../generated/schema"

// Helper function to generate Listing ID
function getListingId(listingId: BigInt): string {
    return listingId.toString()
}

// Helper function to generate Sale ID (txHash-logIndex)
function getSaleId(txHash: Bytes, logIndex: BigInt): string {
    return txHash.toHexString() + "-" + logIndex.toString()
}

/**
 * Handle Listed event
 * Creates a new Listing entity with ACTIVE status
 */
export function handleListed(event: ListedEvent): void {
    let id = getListingId(event.params.listingId)
    let listing = new Listing(id)

    listing.listingId = event.params.listingId
    listing.seller = event.params.seller
    listing.nft = event.params.nft
    listing.tokenId = event.params.tokenId
    listing.payToken = event.params.payToken
    listing.price = event.params.price
    listing.status = "ACTIVE"

    // Metadata
    listing.createdAt = event.block.timestamp
    listing.createdBlock = event.block.number
    listing.createdTx = event.transaction.hash

    listing.save()
}

/**
 * Handle Bought event (normal purchase)
 * Creates a Sale entity and updates Listing status to SOLD
 */
export function handleBought(event: BoughtEvent): void {
    // 1. Create Sale entity
    let saleId = getSaleId(event.transaction.hash, event.logIndex)
    let sale = new Sale(saleId)

    // 2. Load associated Listing
    let listingId = getListingId(event.params.listingId)
    let listing = Listing.load(listingId)

    // If Listing doesn't exist (edge case), create a placeholder
    if (listing == null) {
        listing = new Listing(listingId)
        listing.listingId = event.params.listingId
        listing.seller = event.params.seller
        listing.nft = event.params.nft
        listing.tokenId = event.params.tokenId
        listing.payToken = event.params.payToken
        listing.price = event.params.price
        listing.status = "SOLD"
        listing.createdAt = event.block.timestamp
        listing.createdBlock = event.block.number
        listing.createdTx = event.transaction.hash
        listing.save()
    }

    // 3. Set Sale fields
    sale.listing = listingId
    sale.buyer = event.params.buyer
    sale.seller = event.params.seller
    sale.nft = event.params.nft
    sale.tokenId = event.params.tokenId
    sale.payToken = event.params.payToken
    sale.price = event.params.price
    sale.isPermitBuy = false

    sale.soldAt = event.block.timestamp
    sale.soldBlock = event.block.number
    sale.soldTx = event.transaction.hash

    sale.save()

    // 4. Update Listing status
    listing.status = "SOLD"
    listing.save()
}

/**
 * Handle PermitBought event (whitelist purchase)
 * Same logic as handleBought, but marks isPermitBuy = true
 */
export function handlePermitBought(event: PermitBoughtEvent): void {
    // 1. Create Sale entity
    let saleId = getSaleId(event.transaction.hash, event.logIndex)
    let sale = new Sale(saleId)

    // 2. Load associated Listing
    let listingId = getListingId(event.params.listingId)
    let listing = Listing.load(listingId)

    // If Listing doesn't exist (edge case), create a placeholder
    if (listing == null) {
        listing = new Listing(listingId)
        listing.listingId = event.params.listingId
        listing.seller = event.params.seller
        listing.nft = event.params.nft
        listing.tokenId = event.params.tokenId
        listing.payToken = event.params.payToken
        listing.price = event.params.price
        listing.status = "SOLD"
        listing.createdAt = event.block.timestamp
        listing.createdBlock = event.block.number
        listing.createdTx = event.transaction.hash
        listing.save()
    }

    // 3. Set Sale fields
    sale.listing = listingId
    sale.buyer = event.params.buyer
    sale.seller = event.params.seller
    sale.nft = event.params.nft
    sale.tokenId = event.params.tokenId
    sale.payToken = event.params.payToken
    sale.price = event.params.price
    sale.isPermitBuy = true

    sale.soldAt = event.block.timestamp
    sale.soldBlock = event.block.number
    sale.soldTx = event.transaction.hash

    sale.save()

    // 4. Update Listing status
    listing.status = "SOLD"
    listing.save()
}
