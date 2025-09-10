/*
/// Module: crowdfunding
module crowdfunding::crowdfunding;
*/

// For Move coding conventions, see
// https://docs.sui.io/concepts/sui-move-concepts/conventions


module crowdfunding::crowdfunding {
    use sui::transfer;
    use sui::object::{Self, UID};
    use sui::tx_context::{TxContext};
    use sui::event;

    // Errors
    const ENotAdmin: u64 = 0;
    const ECampaignNotFound: u64 = 1;

    // Structs
    struct AdminCap has key {
        id: UID
    }

    struct Campaign has key, store {
        id: UID,
        creator: address,
        goal_amount: u64,
        raised_amount: u64,
        description: vector<u8>,
        is_active: bool
    }

    // Events
    struct CampaignCreated has copy, drop {
        campaign_id: ID,
        creator: address,
        goal_amount: u64
    }

    // Module initialization
    fun init(ctx: &mut TxContext) {
        transfer::transfer(
            AdminCap {
                id: object::new(ctx)
            },
            tx_context::sender(ctx)
        );
    }

    // Create a new campaign
    public entry fun create_campaign(
        admin_cap: &AdminCap,
        goal_amount: u64,
        description: vector<u8>,
        ctx: &mut TxContext
    ) {
        assert!(tx_context::sender(ctx) == object::uid_to_inner(&admin_cap.id), ENotAdmin);

        let campaign_id = object::new(ctx);
        let campaign = Campaign {
            id: campaign_id,
            creator: tx_context::sender(ctx),
            goal_amount,
            raised_amount: 0,
            description,
            is_active: true
        };

        // Emit event
        event::emit(CampaignCreated {
            campaign_id: object::uid_to_inner(&campaign_id),
            creator: tx_context::sender(ctx),
            goal_amount
        });

        // Transfer campaign to creator
        transfer::transfer(campaign, tx_context::sender(ctx));
    }

    // Get campaign creator
    public fun get_campaign_creator(campaign: &Campaign): address {
        campaign.creator
    }

    // Get campaign details
    public fun get_campaign_details(campaign: &Campaign): (address, u64, u64, vector<u8>, bool) {
        (
            campaign.creator,
            campaign.goal_amount,
            campaign.raised_amount,
            campaign.description,
            campaign.is_active
        )
    }
}